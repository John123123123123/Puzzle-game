extends Node
## Built-in GitHub `main` branch updater for Raiders of the Lost Temple.
##
## Every install mode updates the WHOLE game (scripts, scenes, shaders, project.godot,
## autoloads, Godot class/UID caches and - for exported builds - the engine binary itself):
##   1. GIT_REPO          `.git` + `git` CLI: fetch, branch/stash/rebase guards, fast-forward,
##                        then `--headless --import` so Godot's class & UID caches are rebuilt.
##   2. ZIP_PROJECT       Project folder without git: downloads the archive PINNED to the checked
##                        commit, validates every path, stages it, swaps files in atomically
##                        (with rollback), removes deleted files, then re-imports.
##   3. STANDALONE_EXPORT Exported build: downloads the full CI build published by the
##                        `build-main` GitHub Action (release `latest-main`), verifies its SHA-256,
##                        stages it next to the game and swaps the executable + .pck on restart.
##
## Private repositories are supported: git uses its own credentials; HTTP modes use (in order)
## a token saved in `user://updater_auth.cfg`, `GITHUB_TOKEN` / `GH_TOKEN`, or `gh auth token`.
## The token is only ever sent to api.github.com (never to redirect targets).

signal state_changed()
signal log_appended(line: String)

enum InstallMode {
	GIT_REPO,
	ZIP_PROJECT,
	STANDALONE_EXPORT,
}

const REPO_OWNER: String = "John123123123123"
const REPO_NAME: String = "Puzzle-game"
const BRANCH: String = "main"
const RELEASE_TAG: String = "latest-main"
const APP_BASENAME: String = "RaidersOfTheLostTemple"

const API_BASE: String = "https://api.github.com/repos/%s/%s" % [REPO_OWNER, REPO_NAME]
const COMMITS_API_URL: String = API_BASE + "/commits/" + BRANCH
const RELEASE_API_URL: String = API_BASE + "/releases/tags/" + RELEASE_TAG
const GITHUB_WEB_URL: String = "https://github.com/%s/%s" % [REPO_OWNER, REPO_NAME]

const MANIFEST_MARKER: String = "RAIDERS_MANIFEST:"
const ACCEPT_JSON: String = "application/vnd.github+json"
const ACCEPT_BINARY: String = "application/octet-stream"
const API_HOST: String = "api.github.com"
const MAX_REDIRECTS: int = 5

const VERSION_STAMP_PATH: String = "user://installed_update_version.cfg"
const TEMP_ZIP_PATH: String = "user://github_main_update.zip"
const LEGACY_LIVE_PATCH_ZIP_PATH: String = "user://live_patch_main.zip"
const FILE_MANIFEST_PATH: String = "user://installed_files_manifest.txt"
const AUTH_CFG_PATH: String = "user://updater_auth.cfg"
const SWAP_SCRIPT_BASENAME: String = "apply_standalone_update"
const BUILD_INFO_PATH: String = "res://build_info.cfg"

const STAGING_DIR_NAME: String = ".update_staging"
const BACKUP_DIR_NAME: String = ".update_backup"

var install_mode: InstallMode = InstallMode.ZIP_PROJECT
var local_sha: String = ""
var remote_sha: String = ""
var remote_message: String = ""
var remote_author: String = ""
var remote_date: String = ""
var current_git_branch: String = ""

var is_checking: bool = false
var is_installing: bool = false
var is_busy: bool:
	get:
		return is_checking or is_installing
var is_downloading_zip: bool = false
var progress_ratio: float = 0.0 # 0.0 .. 1.0
var update_available: bool = false
var update_building: bool = false # standalone: main is ahead of the newest published build
var is_ahead_of_remote: bool = false
var has_local_changes: bool = false
var needs_stash_confirmation: bool = false
var needs_branch_switch_confirmation: bool = false
var needs_rebase_confirmation: bool = false
var auth_required: bool = false
var restart_recommended: bool = false
var staged_standalone_ready: bool = false
var status_text: String = "Ready to check main branch for updates."
var log_lines: Array[String] = []

var _api_http: HTTPRequest = null
var _zip_http: HTTPRequest = null
var _worker_thread: Thread = null
var _git_cli_checked: bool = false
var _git_cli_available: bool = false
var _last_auto_check_msec: int = -999999

var _api_stage: String = ""
var _api_redirects: int = 0
var _zip_redirects: int = 0
var _zip_accept: String = ACCEPT_BINARY
var _active_token: String = ""
var _cli_token: String = ""
var _cli_token_checked: bool = false

var _release_asset_name: String = ""
var _release_asset_id: int = 0
var _release_browser_url: String = ""
var _release_sha256: String = ""

var _pending_stash: bool = false
var _pending_switch: bool = false
var _pending_rebase: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_api_http = HTTPRequest.new()
	_api_http.timeout = 15.0
	_api_http.max_redirects = 0 # redirects are followed manually so tokens never leak cross-host
	add_child(_api_http)
	_api_http.request_completed.connect(_on_api_request_completed)

	_zip_http = HTTPRequest.new()
	_zip_http.use_threads = true
	_zip_http.timeout = 900.0
	_zip_http.max_redirects = 0
	add_child(_zip_http)
	_zip_http.request_completed.connect(_on_zip_download_completed)

	_cleanup_legacy_files()
	_detect_initial_local_state()

func _exit_tree() -> void:
	_join_thread()

func _process(_delta: float) -> void:
	if is_downloading_zip and is_instance_valid(_zip_http):
		var dl_bytes: int = _zip_http.get_downloaded_bytes()
		var total_bytes: int = _zip_http.get_body_size()
		var mb_done: float = float(dl_bytes) / (1024.0 * 1024.0)
		if total_bytes > 0:
			progress_ratio = clampf(float(dl_bytes) / float(total_bytes), 0.05, 0.85)
			var mb_tot: float = float(total_bytes) / (1024.0 * 1024.0)
			status_text = "Downloading update... %.2f / %.2f MB" % [mb_done, mb_tot]
		else:
			progress_ratio = 0.45
			status_text = "Downloading update... %.2f MB" % mb_done
		state_changed.emit()

# ---------------------------------------------------------------------------
# Pure helpers (static so they can be unit-tested)
# ---------------------------------------------------------------------------

## True only for plain relative paths that cannot escape their destination directory.
static func is_safe_rel_path(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	for seg in path.split("/"):
		if seg == ".." or seg.is_empty() or seg == ".":
			return false
	return true

static func url_host(url: String) -> String:
	var scheme_end: int = url.find("://")
	var rest: String = url.substr(scheme_end + 3) if scheme_end >= 0 else url
	var slash: int = rest.find("/")
	var host: String = rest.substr(0, slash) if slash >= 0 else rest
	if host.contains("@"):
		host = host.substr(host.rfind("@") + 1)
	return host.get_slice(":", 0).to_lower()

## Request headers for a URL. The bearer token is attached ONLY for api.github.com.
static func build_headers(url: String, token: String, accept: String = ACCEPT_JSON) -> PackedStringArray:
	var headers := PackedStringArray([
		"User-Agent: RaidersOfTheLostTemple-GodotUpdater/2.0",
		"Accept: " + accept,
	])
	if not token.is_empty() and url_host(url) == API_HOST:
		headers.append("Authorization: Bearer " + token)
	return headers

static func header_value(headers: PackedStringArray, header_name: String) -> String:
	var prefix: String = header_name.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(prefix):
			return h.substr(prefix.length()).strip_edges()
	return ""

static func sha256_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while not f.eof_reached():
		ctx.update(f.get_buffer(65536))
	f.close()
	return ctx.finish().hex_encode()

## Extracts the commit SHA embedded in a GitHub archive's root folder (`repo-<sha>`).
static func sha_from_archive_root(root_name: String, expected_sha: String) -> String:
	var token: String = root_name.get_slice("-", root_name.count("-"))
	if token.length() < 7 or not token.is_valid_hex_number(false):
		return ""
	token = token.to_lower()
	if not expected_sha.is_empty() and expected_sha.to_lower().begins_with(token):
		return expected_sha.to_lower()
	return token if token.length() == 40 else ""

static func remove_dir_recursive(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	var dirs: Array[String] = []
	var files: Array[String] = []
	d.list_dir_begin()
	var item: String = d.get_next()
	while not item.is_empty():
		if item != "." and item != "..":
			if d.current_is_dir():
				dirs.append(item)
			else:
				files.append(item)
		item = d.get_next()
	d.list_dir_end()
	for f in files:
		DirAccess.remove_absolute(path.path_join(f))
	for sub in dirs:
		remove_dir_recursive(path.path_join(sub))
	DirAccess.remove_absolute(path)

static func move_file(src: String, dst: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	return DirAccess.rename_absolute(src, dst) == OK

static func ps_quote(s: String) -> String:
	return "'" + s.replace("'", "''") + "'"

static func sh_quote(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_install_mode_label() -> String:
	match install_mode:
		InstallMode.GIT_REPO:
			return "Git Repository (git fetch + fast-forward)"
		InstallMode.ZIP_PROJECT:
			return "Project Folder (pinned GitHub archive)"
		InstallMode.STANDALONE_EXPORT:
			return "Standalone Build (full CI build + restart swap)"
	return "Project Folder"

func short_sha(sha: String) -> String:
	if sha.is_empty():
		return "Unknown"
	return sha.left(7)

func get_base_version() -> String:
	var raw: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	if raw.is_empty():
		raw = "1.0.0"
	return raw if raw.begins_with("v") else ("v" + raw)

func get_display_version() -> String:
	var ver: String = get_base_version()
	if not local_sha.is_empty():
		return "%s (%s)" % [ver, local_sha.left(7)]
	return ver

func auto_check_on_menu() -> void:
	if is_busy or restart_recommended:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_auto_check_msec < 120000:
		return
	_last_auto_check_msec = now
	check_for_updates(false)

func has_saved_github_token() -> bool:
	return not _load_saved_token().is_empty()

func save_github_token(token: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("github", "token", token.strip_edges())
	cfg.save(AUTH_CFG_PATH)
	_append_log("GitHub token saved locally (user://updater_auth.cfg).")

func clear_github_token() -> void:
	if FileAccess.file_exists(AUTH_CFG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CFG_PATH))
	_active_token = ""
	_append_log("Saved GitHub token removed.")
	state_changed.emit()

func check_for_updates(force_log: bool = true) -> void:
	if is_busy:
		return
	_detect_initial_local_state()
	is_checking = true
	_reset_prompts()
	auth_required = false
	update_building = false
	progress_ratio = 0.15
	status_text = "Checking GitHub (%s/%s @ %s)..." % [REPO_OWNER, REPO_NAME, BRANCH]
	if force_log:
		_append_log("Checking latest version on %s/%s (%s)..." % [REPO_OWNER, REPO_NAME, BRANCH])
	state_changed.emit()

	if install_mode == InstallMode.GIT_REPO:
		_start_thread(_thread_git_check.bind(_get_project_dir()))
	else:
		_begin_http_step("check")

func start_update(stash_local_changes: bool = false, switch_to_main: bool = false, allow_rebase: bool = false) -> void:
	if is_busy:
		return
	_detect_initial_local_state()
	_disconnect_online_session()

	_pending_stash = stash_local_changes
	_pending_switch = switch_to_main
	_pending_rebase = allow_rebase
	is_installing = true
	_reset_prompts()
	restart_recommended = false
	progress_ratio = 0.1

	if install_mode == InstallMode.GIT_REPO and _ensure_git_cli_available():
		status_text = "Updating from origin/%s via Git..." % BRANCH
		_append_log("Starting git update from origin/%s..." % BRANCH)
		state_changed.emit()
		_start_thread(_thread_git_update.bind(_get_project_dir(), stash_local_changes, switch_to_main, allow_rebase, OS.get_executable_path()))
		return

	if install_mode == InstallMode.GIT_REPO:
		install_mode = InstallMode.ZIP_PROJECT
	status_text = "Preparing download..."
	state_changed.emit()
	_begin_http_step("install")

func open_github_page() -> void:
	OS.shell_open(GITHUB_WEB_URL)

func restart_game() -> void:
	_disconnect_online_session()
	var exe_path: String = OS.get_executable_path()
	if exe_path.is_empty():
		get_tree().reload_current_scene()
		return

	if install_mode == InstallMode.STANDALONE_EXPORT and staged_standalone_ready:
		if not _launch_standalone_swap(exe_path):
			status_text = "Could not start the update helper. The staged update is kept; please restart manually."
			_append_log(status_text)
			state_changed.emit()
			return
		get_tree().quit()
		return

	if OS.has_feature("standalone"):
		OS.create_process(exe_path, PackedStringArray())
	else:
		OS.create_process(exe_path, PackedStringArray(["--path", _get_project_dir()]))
	get_tree().quit()

# ---------------------------------------------------------------------------
# Local state
# ---------------------------------------------------------------------------

## Ends any online co-op session (looked up dynamically: this autoload loads before NetworkManager).
func _disconnect_online_session() -> void:
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and bool(net.get("is_online")):
		net.call("disconnect_session")
		_append_log("Disconnected the online session before updating.")

func _reset_prompts() -> void:
	needs_stash_confirmation = false
	needs_branch_switch_confirmation = false
	needs_rebase_confirmation = false

func _cleanup_legacy_files() -> void:
	# Older versions mounted a live resource-pack patch. It can never be consistent with the
	# engine binary, so it is removed instead of being mounted.
	for p in [LEGACY_LIVE_PATCH_ZIP_PATH, TEMP_ZIP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _get_project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")

func _has_git_dir() -> bool:
	if OS.has_feature("standalone"):
		return false
	var git_path: String = _get_project_dir().path_join(".git")
	return DirAccess.dir_exists_absolute(git_path) or FileAccess.file_exists(git_path)

func _detect_initial_local_state() -> void:
	current_git_branch = ""
	if OS.has_feature("standalone"):
		install_mode = InstallMode.STANDALONE_EXPORT
		local_sha = _read_build_info_sha()
		return

	if _has_git_dir():
		install_mode = InstallMode.GIT_REPO if (not _git_cli_checked or _git_cli_available) else InstallMode.ZIP_PROJECT
		var git_sha: String = _read_git_head_sha(_get_project_dir())
		local_sha = git_sha if not git_sha.is_empty() else _load_saved_stamp_sha()
		current_git_branch = _read_git_branch(_get_project_dir())
	else:
		install_mode = InstallMode.ZIP_PROJECT
		var archive_sha := FileAccess.get_file_as_string("res://archive_commit.txt").strip_edges() if FileAccess.file_exists("res://archive_commit.txt") else ""
		local_sha = archive_sha if archive_sha.length() == 40 and archive_sha.is_valid_hex_number(false) else _load_saved_stamp_sha()

func _read_build_info_sha() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(BUILD_INFO_PATH) == OK:
		return str(cfg.get_value("build", "sha", "")).strip_edges()
	return ""

func _resolve_git_dir(project_dir: String) -> String:
	var git_dir: String = project_dir.path_join(".git")
	if FileAccess.file_exists(git_dir) and not DirAccess.dir_exists_absolute(git_dir):
		var ptr: String = FileAccess.get_file_as_string(git_dir).strip_edges()
		if ptr.begins_with("gitdir:"):
			var raw_target: String = ptr.substr(7).strip_edges()
			git_dir = raw_target if raw_target.is_absolute_path() else project_dir.path_join(raw_target)
	return git_dir

func _read_git_branch(project_dir: String) -> String:
	var head_path: String = _resolve_git_dir(project_dir).path_join("HEAD")
	if not FileAccess.file_exists(head_path):
		return ""
	var head_txt: String = FileAccess.get_file_as_string(head_path).strip_edges()
	if head_txt.begins_with("ref: refs/heads/"):
		return head_txt.substr(16).strip_edges()
	return ""

func _read_git_head_sha(project_dir: String) -> String:
	var git_dir: String = _resolve_git_dir(project_dir)
	var head_path: String = git_dir.path_join("HEAD")
	if not FileAccess.file_exists(head_path):
		return ""
	var head_txt: String = FileAccess.get_file_as_string(head_path).strip_edges()
	if head_txt.begins_with("ref:"):
		var ref_rel: String = head_txt.substr(4).strip_edges()
		var ref_path: String = git_dir.path_join(ref_rel)
		if FileAccess.file_exists(ref_path):
			return FileAccess.get_file_as_string(ref_path).strip_edges()
		var packed_path: String = git_dir.path_join("packed-refs")
		if FileAccess.file_exists(packed_path):
			for line in FileAccess.get_file_as_string(packed_path).split("\n"):
				var clean: String = line.strip_edges()
				if clean.is_empty() or clean.begins_with("#") or clean.begins_with("^"):
					continue
				var parts: PackedStringArray = clean.split(" ", false)
				if parts.size() >= 2 and parts[1].strip_edges() == ref_rel:
					return parts[0].strip_edges()
		return ""
	return head_txt

func _load_saved_stamp_sha() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(VERSION_STAMP_PATH) == OK and cfg.get_value("version", "project_dir", "") == _get_project_dir():
		return str(cfg.get_value("version", "sha", ""))
	return ""

func _save_stamp_sha(sha: String) -> void:
	if sha.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("version", "sha", sha)
	cfg.set_value("version", "project_dir", _get_project_dir())
	cfg.set_value("version", "updated_at", Time.get_datetime_string_from_system())
	cfg.save(VERSION_STAMP_PATH)

func _load_saved_token() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(AUTH_CFG_PATH) == OK:
		return str(cfg.get_value("github", "token", "")).strip_edges()
	return ""

func _ensure_git_cli_available() -> bool:
	if _git_cli_checked:
		return _git_cli_available
	_git_cli_checked = true
	var out: Array = []
	var code: int = OS.execute("git", PackedStringArray(["--version"]), out, true, false)
	_git_cli_available = (code == 0)
	return _git_cli_available

func _platform_key() -> String:
	match OS.get_name():
		"Windows":
			return "windows"
		"macOS":
			return "macos"
	return "linux"

## Where the running standalone build lives and what must be (re)launched after a swap.
func get_standalone_target() -> Dictionary:
	var exe: String = OS.get_executable_path().replace("\\", "/")
	if OS.get_name() == "macOS":
		var idx: int = exe.find(".app/Contents/MacOS")
		if idx >= 0:
			var bundle: String = exe.substr(0, idx + 4)
			return {"install_dir": bundle.get_base_dir(), "launch": bundle, "bundle_name": bundle.get_file()}
	return {"install_dir": exe.get_base_dir(), "launch": exe, "bundle_name": ""}

func _dir_is_writable(dir_path: String) -> bool:
	var probe: String = dir_path.path_join(".update_write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("ok")
	f.close()
	DirAccess.remove_absolute(probe)
	return true

# ---------------------------------------------------------------------------
# Threads
# ---------------------------------------------------------------------------

func _join_thread() -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()

func _start_thread(callable_task: Callable) -> void:
	_join_thread()
	_worker_thread = Thread.new()
	_worker_thread.start(callable_task)

func _run_git(project_dir: String, args: Array) -> Dictionary:
	var full_args := PackedStringArray(["-C", project_dir])
	for a in args:
		full_args.append(str(a))
	var out: Array = []
	var code: int = OS.execute("git", full_args, out, true, false)
	var text: String = ""
	if not out.is_empty():
		text = str(out[0]).strip_edges()
	return {"code": code, "output": text}

func _git_fetch_error(output: String) -> String:
	var message := output.to_lower()
	for marker in ["authentication failed", "permission denied", "could not read username", "invalid username", "repository not found", "returned error: 403", "returned error: 401"]:
		if message.contains(marker):
			return "Git could not access origin. Check the remote URL and sign in with a Git account or SSH key that can read this repository."
	return "Git fetch failed: " + output

func _git_ok(project_dir: String, args: Array) -> bool:
	return int(_run_git(project_dir, args)["code"]) == 0

# ---------------------------------------------------------------------------
# Token resolution (private repository support) -> then HTTP check / install
# ---------------------------------------------------------------------------

func _begin_http_step(next_step: String) -> void:
	var env_tok: String = OS.get_environment("GITHUB_TOKEN").strip_edges()
	if env_tok.is_empty():
		env_tok = OS.get_environment("GH_TOKEN").strip_edges()
	_start_thread(_thread_resolve_token.bind(_load_saved_token(), env_tok, _cli_token_checked, _cli_token, next_step))

func _thread_resolve_token(saved: String, env_tok: String, cli_done: bool, cli_tok: String, next_step: String) -> void:
	var cli_token: String = cli_tok
	var token: String = saved
	if token.is_empty():
		token = env_tok
	if token.is_empty():
		if not cli_done:
			var out: Array = []
			var code: int = OS.execute("gh", PackedStringArray(["auth", "token"]), out, true, false)
			cli_token = str(out[0]).strip_edges() if (code == 0 and not out.is_empty()) else ""
		token = cli_token
	call_deferred("_on_token_resolved", token, cli_token, next_step)

func _on_token_resolved(token: String, cli_token: String, next_step: String) -> void:
	_join_thread()
	_active_token = token
	_cli_token = cli_token
	_cli_token_checked = true
	if next_step == "install":
		_http_install_start()
	else:
		_http_check_start()

# ---------------------------------------------------------------------------
# Update check: git
# ---------------------------------------------------------------------------

func _thread_git_check(project_dir: String) -> void:
	var out: Array = []
	if OS.execute("git", PackedStringArray(["--version"]), out, true, false) != 0:
		call_deferred("_on_git_check_done", {"has_git": false})
		return

	var fetch_res: Dictionary = _run_git(project_dir, ["fetch", "origin", BRANCH])
	if int(fetch_res["code"]) != 0:
		call_deferred("_on_git_check_done", {"has_git": true, "ok": false, "msg": _git_fetch_error(str(fetch_res["output"]))})
		return

	var head_res: Dictionary = _run_git(project_dir, ["rev-parse", "HEAD"])
	var branch_res: Dictionary = _run_git(project_dir, ["symbolic-ref", "--quiet", "--short", "HEAD"])
	var status_res: Dictionary = _run_git(project_dir, ["status", "--porcelain", "--untracked-files=no"])
	var log_res: Dictionary = _run_git(project_dir, ["log", "-1", "--format=%H%n%s%n%an%n%cI", "origin/" + BRANCH])
	if int(log_res["code"]) != 0:
		call_deferred("_on_git_check_done", {"has_git": true, "ok": false, "msg": "Could not read origin/%s after fetching." % BRANCH})
		return
	var log_lines_arr: PackedStringArray = str(log_res["output"]).split("\n")
	var remote_in_head: bool = _git_ok(project_dir, ["merge-base", "--is-ancestor", "origin/" + BRANCH, "HEAD"])

	call_deferred("_on_git_check_done", {
		"has_git": true,
		"ok": true,
		"head_sha": str(head_res["output"]).strip_edges() if int(head_res["code"]) == 0 else "",
		"branch": str(branch_res["output"]).strip_edges() if int(branch_res["code"]) == 0 else "",
		"dirty": int(status_res["code"]) == 0 and not str(status_res["output"]).is_empty(),
		"remote_sha": log_lines_arr[0].strip_edges() if log_lines_arr.size() > 0 else "",
		"message": log_lines_arr[1].strip_edges() if log_lines_arr.size() > 1 else "",
		"author": log_lines_arr[2].strip_edges() if log_lines_arr.size() > 2 else "",
		"date": log_lines_arr[3].strip_edges().left(16).replace("T", " ") if log_lines_arr.size() > 3 else "",
		"remote_in_head": remote_in_head,
	})

func _on_git_check_done(res: Dictionary) -> void:
	_join_thread()
	if not bool(res.get("has_git", false)):
		_git_cli_checked = true
		_git_cli_available = false
		install_mode = InstallMode.ZIP_PROJECT
		_append_log("Git CLI not found - checking through the GitHub API instead.")
		_begin_http_step("check")
		return

	_git_cli_checked = true
	_git_cli_available = true
	install_mode = InstallMode.GIT_REPO
	if not bool(res.get("ok", false)):
		_fail_check(str(res.get("msg", "Update check failed.")))
		return

	remote_sha = str(res.get("remote_sha", ""))
	remote_message = str(res.get("message", ""))
	remote_author = str(res.get("author", ""))
	remote_date = str(res.get("date", ""))
	var head_sha: String = str(res.get("head_sha", ""))
	if not head_sha.is_empty():
		local_sha = head_sha
	current_git_branch = str(res.get("branch", ""))
	has_local_changes = bool(res.get("dirty", false))
	var remote_in_head: bool = bool(res.get("remote_in_head", false))

	is_checking = false
	progress_ratio = 1.0
	var branch_note: String = ""
	if current_git_branch != BRANCH:
		branch_note = " (on branch '%s')" % (current_git_branch if not current_git_branch.is_empty() else "detached HEAD")
	if remote_in_head:
		update_available = false
		is_ahead_of_remote = (local_sha != remote_sha)
		if is_ahead_of_remote:
			status_text = "✓ Up to date - your branch already contains origin/main (%s)%s." % [short_sha(remote_sha), branch_note]
		else:
			status_text = "✓ Your game is up to date with origin/main (%s)!" % short_sha(remote_sha)
		_append_log("Up to date at %s%s." % [short_sha(remote_sha), branch_note])
	else:
		update_available = true
		is_ahead_of_remote = false
		status_text = "✨ New update available on main (%s → %s)%s!" % [short_sha(local_sha), short_sha(remote_sha), branch_note]
		_append_log("New commit on main: %s - \"%s\"" % [short_sha(remote_sha), remote_message])
	state_changed.emit()

# ---------------------------------------------------------------------------
# Update check: HTTP (ZIP project / standalone)
# ---------------------------------------------------------------------------

func _http_check_start() -> void:
	if install_mode == InstallMode.STANDALONE_EXPORT:
		_api_stage = "release"
		_api_get(RELEASE_API_URL)
	else:
		_api_stage = "commit"
		_api_get(COMMITS_API_URL)

func _api_get(url: String) -> void:
	_api_redirects = 0
	var err: int = _api_http.request(url, build_headers(url, _active_token), HTTPClient.METHOD_GET)
	if err != OK:
		_fail_check("Could not start network request (Error %d)." % err)

func _fail_check(msg: String) -> void:
	is_checking = false
	progress_ratio = 0.0
	status_text = msg
	_append_log(msg)
	state_changed.emit()

func _github_error(code: int, headers: PackedStringArray) -> String:
	auth_required = false
	if code == 429 or (code == 403 and (header_value(headers, "x-ratelimit-remaining") == "0" or not header_value(headers, "retry-after").is_empty())):
		return "GitHub rate limit reached (HTTP %d). Wait before retrying." % code
	if code in [401, 403, 404]:
		auth_required = true
		var action := "Paste a token below and select Save & Check. It needs Contents read access to %s/%s." % [REPO_OWNER, REPO_NAME]
		if code == 401:
			return ("GitHub sign-in required (HTTP 401). " if _active_token.is_empty() else "GitHub rejected the token (HTTP 401). It may have expired or been revoked. ") + action
		if code == 403:
			return "GitHub denied access (HTTP 403). " + action
		return "GitHub could not find the requested item (HTTP 404). It may be missing or private. For a private repository, check your access. " + action
	if code == 0:
		return "No response from GitHub. Check your connection and retry."
	return "GitHub returned HTTP %d." % code

func _on_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code in [301, 302, 303, 307, 308]:
		var loc: String = header_value(headers, "location")
		if not loc.is_empty() and _api_redirects < MAX_REDIRECTS:
			_api_redirects += 1
			if _api_http.request(loc, build_headers(loc, _active_token), HTTPClient.METHOD_GET) == OK:
				return
		_fail_check("GitHub redirected the request too many times.")
		return

	if response_code in [401, 403, 404, 429] and (_api_stage != "building" or response_code != 404):
		_fail_check(_github_error(response_code, headers))
		return
	match _api_stage:
		"commit":
			_handle_commit_response(result, response_code, body)
		"release":
			_handle_release_response(result, response_code, body)
		"building":
			_handle_building_response(result, response_code, body)

func _parse_json_dict(body: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func _handle_commit_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail_check(_github_error(code, PackedStringArray()))
		return
	var dict: Dictionary = _parse_json_dict(body)
	if dict.is_empty():
		_fail_check("Unexpected response format from GitHub.")
		return
	remote_sha = str(dict.get("sha", "")).strip_edges()
	var commit_dict: Dictionary = dict.get("commit", {}) if typeof(dict.get("commit")) == TYPE_DICTIONARY else {}
	var full_msg: String = str(commit_dict.get("message", "")).strip_edges()
	remote_message = full_msg.split("\n")[0].strip_edges() if not full_msg.is_empty() else "Latest commit on main"
	var author_dict: Dictionary = commit_dict.get("author", {}) if typeof(commit_dict.get("author")) == TYPE_DICTIONARY else {}
	remote_author = str(author_dict.get("name", ""))
	remote_date = str(author_dict.get("date", "")).left(16).replace("T", " ")
	_finalize_http_comparison()

func _handle_release_response(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail_check(_github_error(code, PackedStringArray()))
		return
	var dict: Dictionary = _parse_json_dict(body)
	var body_txt: String = str(dict.get("body", ""))
	var marker_idx: int = body_txt.find(MANIFEST_MARKER)
	var manifest: Dictionary = {}
	if marker_idx >= 0:
		var start: int = marker_idx + MANIFEST_MARKER.length()
		var end: int = body_txt.find("-->", start)
		if end > start:
			var parsed: Variant = JSON.parse_string(body_txt.substr(start, end - start).strip_edges())
			if typeof(parsed) == TYPE_DICTIONARY:
				manifest = parsed
	if manifest.is_empty() or str(manifest.get("sha", "")).is_empty():
		_fail_check("The latest-main release has no valid build manifest. Wait for the build to finish.")
		return

	var assets_info: Dictionary = manifest.get("assets", {}) if typeof(manifest.get("assets")) == TYPE_DICTIONARY else {}
	var platform: String = _platform_key()
	if not assets_info.has(platform) or typeof(assets_info[platform]) != TYPE_DICTIONARY:
		_fail_check("The latest build does not include a %s package." % platform)
		return
	var asset_info: Dictionary = assets_info[platform]
	var wanted_name: String = str(asset_info.get("name", ""))
	var wanted_sha256: String = str(asset_info.get("sha256", "")).strip_edges().to_lower()

	_release_asset_name = ""
	_release_asset_id = 0
	_release_browser_url = ""
	var release_assets: Array = dict.get("assets", []) if typeof(dict.get("assets")) == TYPE_ARRAY else []
	for a in release_assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var ad: Dictionary = a
		if str(ad.get("name", "")) == wanted_name:
			_release_asset_name = wanted_name
			_release_asset_id = int(ad.get("id", 0))
			_release_browser_url = str(ad.get("browser_download_url", ""))
			break
	if _release_asset_name.is_empty() or wanted_sha256.is_empty():
		_fail_check("The latest build is incomplete (missing %s or its checksum)." % wanted_name)
		return
	_release_sha256 = wanted_sha256

	remote_sha = str(manifest.get("sha", "")).strip_edges()
	remote_message = str(manifest.get("message", "Latest build of main"))
	remote_author = str(manifest.get("author", ""))
	remote_date = str(manifest.get("date", "")).left(16).replace("T", " ")

	# Is main already ahead of the newest published build? (informational)
	_api_stage = "building"
	_api_get(COMMITS_API_URL)

func _handle_building_response(result: int, code: int, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var dict: Dictionary = _parse_json_dict(body)
		var main_sha: String = str(dict.get("sha", "")).strip_edges()
		update_building = (not main_sha.is_empty() and main_sha != remote_sha)
	_finalize_http_comparison()

func _finalize_http_comparison() -> void:
	is_checking = false
	progress_ratio = 1.0
	is_ahead_of_remote = false
	var building_note: String = " A newer commit is still being built." if update_building else ""

	if remote_sha.is_empty():
		update_available = false
		status_text = "Could not determine the latest version on main."
	elif not local_sha.is_empty() and local_sha == remote_sha:
		update_available = false
		status_text = "✓ Your game is up to date with main (%s)!%s" % [short_sha(remote_sha), building_note]
		_append_log("Up to date at %s." % short_sha(remote_sha))
	elif local_sha.is_empty():
		update_available = false
		status_text = "Installed commit unknown. You can re-sync with main (%s).%s" % [short_sha(remote_sha), building_note]
		_append_log(status_text)
	else:
		update_available = true
		status_text = "✨ New update available on main (%s → %s)!%s" % [short_sha(local_sha), short_sha(remote_sha), building_note]
		_append_log("Update available: %s -> %s (\"%s\")" % [short_sha(local_sha), short_sha(remote_sha), remote_message])
	state_changed.emit()

# ---------------------------------------------------------------------------
# Install: common
# ---------------------------------------------------------------------------

func _fail_install(msg: String) -> void:
	is_installing = false
	is_downloading_zip = false
	progress_ratio = 0.0
	status_text = msg
	_append_log(msg)
	state_changed.emit()

func _prompt_result(logs: Array[String], msg: String, stash: bool, switch_branch: bool, rebase: bool) -> Dictionary:
	return {
		"ok": false,
		"logs": logs,
		"msg": msg,
		"needs_stash": stash,
		"needs_switch": switch_branch,
		"needs_rebase": rebase,
	}

func _on_install_done(res: Dictionary) -> void:
	_join_thread()
	for line in res.get("logs", []):
		if not str(line).strip_edges().is_empty():
			_append_log(str(line))

	is_installing = false
	is_downloading_zip = false
	var ok: bool = bool(res.get("ok", false))
	needs_stash_confirmation = bool(res.get("needs_stash", false))
	needs_branch_switch_confirmation = bool(res.get("needs_switch", false))
	needs_rebase_confirmation = bool(res.get("needs_rebase", false))
	status_text = str(res.get("msg", ""))
	_append_log(status_text)

	if bool(res.get("files_updated", false)):
		var new_sha: String = str(res.get("new_sha", ""))
		if not new_sha.is_empty():
			local_sha = new_sha
			_save_stamp_sha(local_sha)
		var origin_sha: String = str(res.get("origin_sha", ""))
		if not origin_sha.is_empty():
			remote_sha = origin_sha
		update_available = false
		has_local_changes = false

	if ok:
		progress_ratio = 1.0
		if bool(res.get("files_updated", false)):
			restart_recommended = true
		if bool(res.get("staged", false)):
			staged_standalone_ready = true
			restart_recommended = true
			update_available = false
	else:
		progress_ratio = 0.0
	state_changed.emit()

## Rebuilds Godot's class/UID caches. Without it a restart can fail on new `class_name` scripts.
func _reimport_project(project_dir: String, exe_path: String, logs: Array[String]) -> bool:
	if exe_path.is_empty():
		logs.append("Skipping cache refresh (no engine executable known).")
		return true
	logs.append("Rebuilding Godot class & UID cache (--headless --import)...")
	var out: Array = []
	var code: int = OS.execute(exe_path, PackedStringArray(["--headless", "--path", project_dir, "--import"]), out, true, false)
	if code != 0:
		logs.append("Cache refresh exited with code %d." % code)
		return false
	if not FileAccess.file_exists(project_dir.path_join(".godot/global_script_class_cache.cfg")):
		logs.append("Cache refresh finished but the class cache is missing.")
		return false
	logs.append("Godot class & UID cache refreshed.")
	return true

# ---------------------------------------------------------------------------
# Install: git
# ---------------------------------------------------------------------------

func _thread_git_update(project_dir: String, stash_first: bool, switch_to_main: bool, allow_rebase: bool, exe_path: String) -> void:
	call_deferred("_on_install_done", _do_git_update(project_dir, stash_first, switch_to_main, allow_rebase, exe_path))

func _restore_stash(project_dir: String, stashed: bool, logs: Array[String]) -> void:
	if not stashed:
		return
	if _git_ok(project_dir, ["stash", "pop"]):
		logs.append("Update failed - your local edits were restored from the stash.")
	else:
		logs.append("Update failed - your edits remain in 'git stash' (run: git stash pop).")

func _do_git_update(project_dir: String, stash_first: bool, switch_to_main: bool, allow_rebase: bool, exe_path: String) -> Dictionary:
	var logs: Array[String] = []
	var st: Dictionary = _run_git(project_dir, ["status", "--porcelain", "--untracked-files=no"])
	var is_dirty: bool = int(st["code"]) == 0 and not str(st["output"]).is_empty()
	var br: Dictionary = _run_git(project_dir, ["symbolic-ref", "--quiet", "--short", "HEAD"])
	var branch: String = str(br["output"]).strip_edges() if int(br["code"]) == 0 else ""
	var on_main: bool = (branch == BRANCH)

	if not on_main and not switch_to_main:
		var where: String = "'%s'" % branch if not branch.is_empty() else "a detached HEAD"
		return _prompt_result(logs, "You are on %s, not main. Updating would change your current work. Choose 'Switch to main & Update' to continue." % where, is_dirty, true, false)
	if not on_main and is_dirty and not stash_first:
		return _prompt_result(logs, "Local edits must be stashed before switching to main.", true, true, false)

	logs.append("Fetching latest commits from origin/%s..." % BRANCH)
	var fetch_res: Dictionary = _run_git(project_dir, ["fetch", "origin", BRANCH])
	if int(fetch_res["code"]) != 0:
		return {"ok": false, "logs": logs, "msg": _git_fetch_error(str(fetch_res["output"]))}
	var origin_res: Dictionary = _run_git(project_dir, ["rev-parse", "origin/" + BRANCH])
	var origin_sha: String = str(origin_res["output"]).strip_edges() if int(origin_res["code"]) == 0 else ""

	# Inspect history BEFORE touching anything.
	var target_ref: String = "HEAD" if on_main else "refs/heads/" + BRANCH
	var has_target: bool = on_main or _git_ok(project_dir, ["rev-parse", "--verify", "--quiet", target_ref])
	var contains: bool = false
	var can_ff: bool = true
	if has_target:
		contains = _git_ok(project_dir, ["merge-base", "--is-ancestor", "origin/" + BRANCH, target_ref])
		can_ff = _git_ok(project_dir, ["merge-base", "--is-ancestor", target_ref, "origin/" + BRANCH])
	var diverged: bool = has_target and not contains and not can_ff

	if diverged and not allow_rebase:
		return _prompt_result(logs, "Your local main has commits that are not on origin/main. Choose 'Rebase local commits & Update' to replay them on top (aborts cleanly on conflict).", is_dirty, false, true)
	if diverged and is_dirty and not stash_first:
		return _prompt_result(logs, "Local edits must be stashed before rebasing.", true, false, true)

	var stashed: bool = false
	if is_dirty and stash_first:
		logs.append("Stashing local uncommitted edits (git stash push -u)...")
		var stash_res: Dictionary = _run_git(project_dir, ["stash", "push", "-u", "-m", "Raiders Auto-Updater Backup"])
		if int(stash_res["code"]) != 0:
			return {"ok": false, "logs": logs, "msg": "Could not stash local changes: " + str(stash_res["output"])}
		stashed = true
		is_dirty = false
		logs.append("Local changes saved to git stash.")

	if not on_main:
		logs.append("Switching to %s..." % BRANCH)
		var co: Dictionary = _run_git(project_dir, ["checkout", BRANCH])
		if int(co["code"]) != 0:
			co = _run_git(project_dir, ["checkout", "-B", BRANCH, "--track", "origin/" + BRANCH])
		if int(co["code"]) != 0:
			_restore_stash(project_dir, stashed, logs)
			return {"ok": false, "logs": logs, "msg": "Could not switch to main: " + str(co["output"])}

	var already_current: bool = contains
	if not already_current:
		if diverged:
			logs.append("Rebasing local commits onto origin/%s..." % BRANCH)
			var rb: Dictionary = _run_git(project_dir, ["rebase", "origin/" + BRANCH])
			if int(rb["code"]) != 0:
				_run_git(project_dir, ["rebase", "--abort"])
				_restore_stash(project_dir, stashed, logs)
				return {"ok": false, "logs": logs, "msg": "Rebase conflicted and was aborted cleanly (nothing changed): " + str(rb["output"])}
		else:
			logs.append("Fast-forwarding to origin/%s..." % BRANCH)
			var mg: Dictionary = _run_git(project_dir, ["merge", "--ff-only", "origin/" + BRANCH])
			if int(mg["code"]) != 0:
				if is_dirty:
					return _prompt_result(logs, "Local modified files are in the way. Click 'Stash Local Edits & Update' to back them up and update safely.", true, false, false)
				_restore_stash(project_dir, stashed, logs)
				return {"ok": false, "logs": logs, "msg": "git merge failed: " + str(mg["output"])}

	var head_res: Dictionary = _run_git(project_dir, ["rev-parse", "HEAD"])
	var final_sha: String = str(head_res["output"]).strip_edges()
	if stashed:
		logs.append("Your local edits are saved in 'git stash' (run: git stash pop to restore).")

	if already_current and not stashed and on_main:
		return {"ok": true, "files_updated": false, "new_sha": final_sha, "origin_sha": origin_sha, "logs": logs, "msg": "✓ Already up to date with origin/%s!" % BRANCH}

	var imported: bool = _reimport_project(project_dir, exe_path, logs)
	if not imported:
		return {"ok": false, "files_updated": true, "new_sha": final_sha, "origin_sha": origin_sha, "logs": logs,
			"msg": "Files updated, but Godot's cache refresh failed. Open the project once in the Godot editor, then restart."}
	return {"ok": true, "files_updated": true, "new_sha": final_sha, "origin_sha": origin_sha, "logs": logs,
		"msg": "✓ Updated to %s! Restart the game to load all new content." % final_sha.left(7)}

# ---------------------------------------------------------------------------
# Install: HTTP download (ZIP project / standalone)
# ---------------------------------------------------------------------------

func _http_install_start() -> void:
	var url: String = ""
	var accept: String = ACCEPT_BINARY
	if install_mode == InstallMode.STANDALONE_EXPORT:
		if _release_asset_name.is_empty() or _release_sha256.is_empty():
			_fail_install("Press 'Check for Updates' first so the latest build can be located.")
			return
		var target: Dictionary = get_standalone_target()
		if not _dir_is_writable(str(target["install_dir"])):
			_fail_install("The install folder is not writable: %s. Move the game to a writable folder (or run it with the needed permissions) and retry." % str(target["install_dir"]))
			return
		url = _release_browser_url if _active_token.is_empty() else "%s/releases/assets/%d" % [API_BASE, _release_asset_id]
	else:
		if remote_sha.is_empty():
			_fail_install("Press 'Check for Updates' first so the update can be pinned to an exact commit.")
			return
		if _active_token.is_empty():
			url = "https://codeload.github.com/%s/%s/zip/%s" % [REPO_OWNER, REPO_NAME, remote_sha]
		else:
			url = "%s/zipball/%s" % [API_BASE, remote_sha]
			accept = ACCEPT_JSON

	if FileAccess.file_exists(TEMP_ZIP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_ZIP_PATH))
	is_downloading_zip = true
	_zip_redirects = 0
	_zip_accept = accept
	progress_ratio = 0.08
	status_text = "Connecting to GitHub..."
	_append_log("Downloading update...")
	state_changed.emit()

	_zip_http.download_file = TEMP_ZIP_PATH
	var err: int = _zip_http.request(url, build_headers(url, _active_token, accept), HTTPClient.METHOD_GET)
	if err != OK:
		_fail_install("Failed to start the download (Error %d)." % err)

func _on_zip_download_completed(result: int, response_code: int, headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code in [301, 302, 303, 307, 308]:
		var loc: String = header_value(headers, "location")
		if not loc.is_empty() and _zip_redirects < MAX_REDIRECTS:
			_zip_redirects += 1
			# Token is stripped automatically for non-api.github.com hosts.
			var accept := _zip_accept if url_host(loc) == API_HOST else ACCEPT_BINARY
			if _zip_http.request(loc, build_headers(loc, _active_token, accept), HTTPClient.METHOD_GET) == OK:
				return
		_fail_install("Download failed: too many redirects.")
		return

	is_downloading_zip = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail_install("Download failed. " + _github_error(response_code, headers))
		return

	progress_ratio = 0.9
	status_text = "Verifying and installing update..."
	_append_log("Archive downloaded. Verifying and applying...")
	state_changed.emit()

	var zip_abs: String = ProjectSettings.globalize_path(TEMP_ZIP_PATH)
	if install_mode == InstallMode.STANDALONE_EXPORT:
		var target: Dictionary = get_standalone_target()
		_start_thread(_thread_stage_standalone.bind(zip_abs, str(target["install_dir"]), _release_sha256, OS.get_executable_path(), _platform_key(), str(target["bundle_name"])))
	else:
		_start_thread(_thread_apply_zip_project.bind(zip_abs, _get_project_dir(), ProjectSettings.globalize_path(FILE_MANIFEST_PATH), OS.get_executable_path(), remote_sha))

## Validates and extracts an archive into `dest_dir`. Returns {ok, msg, files, root}.
func _extract_archive(reader: ZIPReader, dest_dir: String, strip_root: bool, skip_prefixes: Array[String]) -> Dictionary:
	var files: Array[String] = []
	var root_name: String = ""
	for entry in reader.get_files():
		if entry.ends_with("/"):
			continue
		var rel: String = entry.replace("\\", "/")
		if strip_root:
			var slash: int = rel.find("/")
			if slash < 0:
				continue
			if root_name.is_empty():
				root_name = rel.substr(0, slash)
			rel = rel.substr(slash + 1)
		if rel.is_empty():
			continue
		if not is_safe_rel_path(rel):
			return {"ok": false, "msg": "The archive contains an unsafe path (%s). Update aborted; nothing was changed." % entry}
		var skipped: bool = false
		for pre in skip_prefixes:
			if rel == pre.trim_suffix("/") or rel.begins_with(pre):
				skipped = true
				break
		if skipped:
			continue

		var bytes: PackedByteArray = reader.read_file(entry)
		var dest: String = dest_dir.path_join(rel)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var fa := FileAccess.open(dest, FileAccess.WRITE)
		if fa == null:
			return {"ok": false, "msg": "Could not write %s. Update aborted; nothing was changed." % rel}
		fa.store_buffer(bytes)
		fa.close()
		var check := FileAccess.open(dest, FileAccess.READ)
		var written: int = check.get_length() if check != null else -1
		if check != null:
			check.close()
		if written != bytes.size():
			return {"ok": false, "msg": "Short write for %s. Update aborted; nothing was changed." % rel}
		files.append(rel)
	return {"ok": true, "files": files, "root": root_name}

func _collect_managed_files_recursive(base_dir: String, rel_dir: String, out_list: Array[String]) -> void:
	var da := DirAccess.open(base_dir.path_join(rel_dir))
	if da == null:
		return
	da.list_dir_begin()
	var item: String = da.get_next()
	while not item.is_empty():
		if not item.begins_with("."):
			var child_rel: String = rel_dir.path_join(item).replace("\\", "/")
			if da.current_is_dir():
				_collect_managed_files_recursive(base_dir, child_rel, out_list)
			elif item.get_extension().to_lower() in ["gd", "tscn", "tres", "gdshader", "uid"]:
				out_list.append(child_rel)
		item = da.get_next()
	da.list_dir_end()

func _thread_apply_zip_project(zip_abs: String, project_dir: String, manifest_abs: String, exe_path: String, expected_sha: String) -> void:
	call_deferred("_on_install_done", _do_apply_zip_project(zip_abs, project_dir, manifest_abs, exe_path, expected_sha))

func _do_apply_zip_project(zip_abs: String, project_dir: String, manifest_abs: String, exe_path: String, expected_sha: String) -> Dictionary:
	var logs: Array[String] = []
	var reader := ZIPReader.new()
	var err: int = reader.open(zip_abs)
	if err != OK:
		return {"ok": false, "logs": logs, "msg": "Could not open the downloaded archive (Error %d)." % err}

	var staging: String = project_dir.path_join(STAGING_DIR_NAME)
	var backup: String = project_dir.path_join(BACKUP_DIR_NAME)
	remove_dir_recursive(staging)
	remove_dir_recursive(backup)
	DirAccess.make_dir_recursive_absolute(staging)

	var skip: Array[String] = [".git/", ".godot/", STAGING_DIR_NAME + "/", BACKUP_DIR_NAME + "/"]
	var extracted: Dictionary = _extract_archive(reader, staging, true, skip)
	reader.close()
	if not bool(extracted["ok"]):
		remove_dir_recursive(staging)
		return {"ok": false, "logs": logs, "msg": str(extracted["msg"])}
	var new_list: Array[String] = []
	new_list.assign(extracted["files"])
	if new_list.is_empty():
		remove_dir_recursive(staging)
		return {"ok": false, "logs": logs, "msg": "No files were found in the archive."}

	var installed_sha: String = sha_from_archive_root(str(extracted["root"]), expected_sha)
	if installed_sha.is_empty():
		installed_sha = expected_sha

	var new_set: Dictionary = {}
	for rel in new_list:
		new_set[rel] = true

	# Files from the previous install that no longer exist upstream.
	var prev_files: Array[String] = []
	if FileAccess.file_exists(manifest_abs):
		for p_line in FileAccess.get_file_as_string(manifest_abs).split("\n", false):
			var clean_p: String = p_line.strip_edges().replace("\\", "/")
			if is_safe_rel_path(clean_p):
				prev_files.append(clean_p)
	else:
		for sub in ["scenes", "scripts", "shaders"]:
			_collect_managed_files_recursive(project_dir, sub, prev_files)
	var to_delete: Array[String] = []
	for old_rel in prev_files:
		if new_set.has(old_rel) or old_rel.begins_with(".git/") or old_rel.begins_with(".godot/"):
			continue
		if old_rel.ends_with(".uid") and new_set.has(old_rel.trim_suffix(".uid")):
			continue # Godot regenerates uid files for scripts that still exist
		to_delete.append(old_rel)

	# Atomic swap: back up everything that is replaced/removed, move new files in, roll back on any failure.
	var backed_up: Array[String] = []
	var placed: Array[String] = []
	var failed_rel: String = ""
	for rel in new_list:
		var dest: String = project_dir.path_join(rel)
		if FileAccess.file_exists(dest):
			if not move_file(dest, backup.path_join(rel)):
				failed_rel = rel
				break
			backed_up.append(rel)
		if not move_file(staging.path_join(rel), dest):
			failed_rel = rel
			break
		placed.append(rel)
	if failed_rel.is_empty():
		for rel in to_delete:
			var old_abs: String = project_dir.path_join(rel)
			if FileAccess.file_exists(old_abs):
				if not move_file(old_abs, backup.path_join(rel)):
					failed_rel = rel
					break
				backed_up.append(rel)

	if not failed_rel.is_empty():
		for rel in placed:
			DirAccess.remove_absolute(project_dir.path_join(rel))
		for rel in backed_up:
			move_file(backup.path_join(rel), project_dir.path_join(rel))
		remove_dir_recursive(staging)
		remove_dir_recursive(backup)
		return {"ok": false, "logs": logs, "msg": "Could not replace %s (file locked?). Everything was rolled back - the game is unchanged." % failed_rel}

	remove_dir_recursive(staging)
	remove_dir_recursive(backup)
	DirAccess.remove_absolute(zip_abs)

	var sorted_rels: Array[String] = new_list.duplicate()
	sorted_rels.sort()
	var mf := FileAccess.open(manifest_abs, FileAccess.WRITE)
	if mf != null:
		mf.store_string("\n".join(sorted_rels))
		mf.close()
	if not to_delete.is_empty():
		logs.append("Removed %d deleted/renamed file(s) from the previous version." % to_delete.size())
	logs.append("Installed %d files." % new_list.size())

	var imported: bool = _reimport_project(project_dir, exe_path, logs)
	if not imported:
		return {"ok": false, "files_updated": true, "new_sha": installed_sha, "logs": logs,
			"msg": "Files updated, but Godot's cache refresh failed. Open the project once in the Godot editor, then restart."}
	return {"ok": true, "files_updated": true, "new_sha": installed_sha, "logs": logs,
		"msg": "✓ Installed %d files from main! Restart the game to apply all changes." % new_list.size()}

# ---------------------------------------------------------------------------
# Install: standalone build (verify -> stage -> swap on restart)
# ---------------------------------------------------------------------------

func _thread_stage_standalone(zip_abs: String, install_dir: String, expected_sha256: String, exe_path: String, platform_key: String, bundle_name: String) -> void:
	call_deferred("_on_install_done", _do_stage_standalone(zip_abs, install_dir, expected_sha256, exe_path, platform_key, bundle_name))

func _do_stage_standalone(zip_abs: String, install_dir: String, expected_sha256: String, exe_path: String, platform_key: String, bundle_name: String) -> Dictionary:
	var logs: Array[String] = []
	if expected_sha256.is_empty():
		DirAccess.remove_absolute(zip_abs)
		return {"ok": false, "logs": logs, "msg": "The release has no checksum - refusing to install an unverified build."}
	var actual: String = sha256_file(zip_abs)
	if actual.to_lower() != expected_sha256.to_lower():
		DirAccess.remove_absolute(zip_abs)
		return {"ok": false, "logs": logs, "msg": "Checksum mismatch - the download is corrupt or was tampered with. Nothing was installed."}
	logs.append("SHA-256 verified.")

	var reader := ZIPReader.new()
	var err: int = reader.open(zip_abs)
	if err != OK:
		return {"ok": false, "logs": logs, "msg": "Could not open the downloaded build (Error %d)." % err}
	var staging: String = install_dir.path_join(STAGING_DIR_NAME)
	remove_dir_recursive(staging)
	remove_dir_recursive(install_dir.path_join(BACKUP_DIR_NAME))
	DirAccess.make_dir_recursive_absolute(staging)
	var no_skip: Array[String] = []
	var extracted: Dictionary = _extract_archive(reader, staging, false, no_skip)
	reader.close()
	DirAccess.remove_absolute(zip_abs)
	if not bool(extracted["ok"]):
		remove_dir_recursive(staging)
		return {"ok": false, "logs": logs, "msg": str(extracted["msg"])}

	# Rename the shipped files so they match the (possibly renamed) running game.
	var stem: String = exe_path.get_file().get_basename()
	var d := DirAccess.open(staging)
	var top_entries: Array[String] = []
	if d != null:
		d.list_dir_begin()
		var item: String = d.get_next()
		while not item.is_empty():
			top_entries.append(item)
			item = d.get_next()
		d.list_dir_end()
	for entry in top_entries:
		var new_name: String = entry
		if platform_key == "macos":
			if entry.ends_with(".app") and not bundle_name.is_empty():
				new_name = bundle_name
		elif entry.begins_with(APP_BASENAME + "."):
			var suffix: String = entry.substr(APP_BASENAME.length())
			if suffix == ".x86_64" and exe_path.get_extension().is_empty():
				suffix = ""
			new_name = stem + suffix
		if new_name != entry:
			if DirAccess.rename_absolute(staging.path_join(entry), staging.path_join(new_name)) != OK:
				remove_dir_recursive(staging)
				return {"ok": false, "logs": logs, "msg": "Could not prepare the staged build (rename %s)." % entry}

	var expected_main: String = bundle_name if platform_key == "macos" else exe_path.get_file()
	if expected_main.is_empty() or not (DirAccess.dir_exists_absolute(staging.path_join(expected_main)) or FileAccess.file_exists(staging.path_join(expected_main))):
		remove_dir_recursive(staging)
		return {"ok": false, "logs": logs, "msg": "The downloaded build does not contain the expected game executable."}

	logs.append("Build staged. It will be swapped in when you restart.")
	return {"ok": true, "staged": true, "logs": logs, "msg": "✓ New build downloaded and verified! Click 'Restart Game Now' to switch to it."}

func _launch_standalone_swap(exe_path: String) -> bool:
	var target: Dictionary = get_standalone_target()
	var install_dir: String = str(target["install_dir"])
	var launch: String = str(target["launch"])
	var pid: int = OS.get_process_id()
	var is_windows: bool = OS.get_name() == "Windows"
	var is_mac: bool = OS.get_name() == "macOS"
	var script_path: String = ProjectSettings.globalize_path("user://" + SWAP_SCRIPT_BASENAME + (".ps1" if is_windows else ".sh"))

	if not DirAccess.dir_exists_absolute(install_dir.path_join(STAGING_DIR_NAME)):
		return false

	var fa := FileAccess.open(script_path, FileAccess.WRITE)
	if fa == null:
		return false
	if is_windows:
		var inst: String = install_dir.replace("/", "\\")
		var lines: PackedStringArray = PackedStringArray([
			"$ErrorActionPreference = 'Stop'",
			"$install = " + ps_quote(inst),
			"$launch = " + ps_quote(launch.replace("/", "\\")),
			"$staging = Join-Path $install '%s'" % STAGING_DIR_NAME,
			"$backup = Join-Path $install '%s'" % BACKUP_DIR_NAME,
			"try { Wait-Process -Id %d -Timeout 90 -ErrorAction SilentlyContinue } catch {}" % pid,
			"Start-Sleep -Milliseconds 800",
			"if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }",
			"New-Item -ItemType Directory -Path $backup | Out-Null",
			"$moved = @(); $placed = @(); $failed = $false",
			"try {",
			"  foreach ($item in Get-ChildItem -LiteralPath $staging -Force) {",
			"    $dest = Join-Path $install $item.Name",
			"    if (Test-Path -LiteralPath $dest) {",
			"      $tries = 0",
			"      while ($true) {",
			"        try { Move-Item -LiteralPath $dest -Destination (Join-Path $backup $item.Name) -Force -ErrorAction Stop; break }",
			"        catch { $tries++; if ($tries -ge 30) { throw }; Start-Sleep -Milliseconds 500 }",
			"      }",
			"      $moved += $item.Name",
			"    }",
			"    Move-Item -LiteralPath $item.FullName -Destination $dest -Force -ErrorAction Stop",
			"    $placed += $item.Name",
			"  }",
			"} catch { $failed = $true }",
			"if ($failed) {",
			"  foreach ($n in $placed) { $d = Join-Path $install $n; if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue } }",
			"  foreach ($n in $moved) { $b = Join-Path $backup $n; if (Test-Path -LiteralPath $b) { Move-Item -LiteralPath $b -Destination (Join-Path $install $n) -Force -ErrorAction SilentlyContinue } }",
			"} else {",
			"  Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue",
			"  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue",
			"}",
			"Start-Process -FilePath $launch -WorkingDirectory $install",
			"Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue",
		])
		fa.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF])) # BOM so PowerShell reads UTF-8 paths correctly
		fa.store_buffer("\r\n".join(lines).to_utf8_buffer())
	else:
		var launch_cmd: String = ("open " + sh_quote(launch)) if is_mac else ("nohup " + sh_quote(launch) + " >/dev/null 2>&1 &")
		var chmod_cmd: String = ("chmod -R +x " + sh_quote(launch + "/Contents/MacOS")) if is_mac else ("chmod +x " + sh_quote(launch))
		var sh_lines: PackedStringArray = PackedStringArray([
			"#!/bin/sh",
			"INSTALL=" + sh_quote(install_dir),
			"STAGING=\"$INSTALL/%s\"" % STAGING_DIR_NAME,
			"BACKUP=\"$INSTALL/%s\"" % BACKUP_DIR_NAME,
			"i=0",
			"while kill -0 %d 2>/dev/null && [ $i -lt 180 ]; do sleep 0.5; i=$((i+1)); done" % pid,
			"rm -rf \"$BACKUP\"; mkdir -p \"$BACKUP\"",
			"MOVED=\"\"; PLACED=\"\"; FAIL=0",
			"for src in \"$STAGING\"/* \"$STAGING\"/.[!.]*; do",
			"  [ -e \"$src\" ] || continue",
			"  name=$(basename \"$src\")",
			"  dest=\"$INSTALL/$name\"",
			"  if [ -e \"$dest\" ]; then",
			"    mv \"$dest\" \"$BACKUP/$name\" || { FAIL=1; break; }",
			"    MOVED=\"$MOVED$name\n\"",
			"  fi",
			"  mv \"$src\" \"$dest\" || { FAIL=1; break; }",
			"  PLACED=\"$PLACED$name\n\"",
			"done",
			"if [ $FAIL -ne 0 ]; then",
			"  printf '%s' \"$PLACED\" | while IFS= read -r n; do [ -n \"$n\" ] && rm -rf \"$INSTALL/$n\"; done",
			"  printf '%s' \"$MOVED\" | while IFS= read -r n; do [ -n \"$n\" ] && [ -e \"$BACKUP/$n\" ] && mv \"$BACKUP/$n\" \"$INSTALL/$n\"; done",
			"else",
			"  rm -rf \"$BACKUP\" \"$STAGING\"",
			"fi",
			chmod_cmd + " 2>/dev/null",
			launch_cmd,
			"rm -f \"$0\"",
		])
		fa.store_string("\n".join(sh_lines) + "\n")
	fa.close()

	if is_windows:
		return OS.create_process("powershell.exe", PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", script_path])) > 0
	return OS.create_process("/bin/sh", PackedStringArray([script_path])) > 0

# ---------------------------------------------------------------------------
# Log
# ---------------------------------------------------------------------------

func _append_log(line: String) -> void:
	var stamp: String = Time.get_time_string_from_system()
	var entry: String = "[%s] %s" % [stamp, line]
	log_lines.append(entry)
	if log_lines.size() > 60:
		log_lines.pop_front()
	log_appended.emit(entry)
