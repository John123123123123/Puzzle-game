extends Node
## Built-in GitHub `main` Branch Auto-Updater for Raiders of the Lost Temple.
## Supports:
##   1. Git Clones (`.git` + `git` CLI) via safe background `git fetch` & `git pull --ff-only origin main`
##   2. Downloaded Project Folders (no `.git` / no `git` installed) via GitHub `main.zip` + Godot `ZIPReader`
##   3. Standalone Exported Builds via live `ZIPPacker` resource-pack patching + GitHub link

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

const COMMITS_API_URL: String = "https://api.github.com/repos/%s/%s/commits/%s" % [REPO_OWNER, REPO_NAME, BRANCH]
const ZIP_ARCHIVE_URL: String = "https://codeload.github.com/%s/%s/zip/refs/heads/%s" % [REPO_OWNER, REPO_NAME, BRANCH]
const GITHUB_WEB_URL: String = "https://github.com/%s/%s" % [REPO_OWNER, REPO_NAME]

const VERSION_STAMP_PATH: String = "user://installed_update_version.cfg"
const TEMP_ZIP_PATH: String = "user://github_main_update.zip"
const LIVE_PATCH_ZIP_PATH: String = "user://live_patch_main.zip"
const FILE_MANIFEST_PATH: String = "user://installed_files_manifest.txt"

const GITHUB_HEADERS: PackedStringArray = [
	"User-Agent: RaidersOfTheLostTemple-GodotUpdater/1.0",
	"Accept: application/vnd.github+json",
]

var install_mode: InstallMode = InstallMode.ZIP_PROJECT
var local_sha: String = ""
var remote_sha: String = ""
var remote_message: String = ""
var remote_author: String = ""
var remote_date: String = ""

var is_busy: bool = false
var is_downloading_zip: bool = false
var progress_ratio: float = 0.0 # 0.0 .. 1.0 (-1.0 for indeterminate)
var update_available: bool = false
var is_ahead_of_remote: bool = false
var has_local_changes: bool = false
var needs_stash_confirmation: bool = false
var restart_recommended: bool = false
var status_text: String = "Ready to check main branch for updates."
var log_lines: Array[String] = []

var _api_http: HTTPRequest = null
var _zip_http: HTTPRequest = null
var _worker_thread: Thread = null
var _git_cli_checked: bool = false
var _git_cli_available: bool = false
var _last_auto_check_msec: int = -999999

func _init() -> void:
	# If running an exported build and a live patch pack was previously downloaded, mount it early
	if OS.has_feature("standalone") and FileAccess.file_exists(LIVE_PATCH_ZIP_PATH):
		ProjectSettings.load_resource_pack(LIVE_PATCH_ZIP_PATH, true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_api_http = HTTPRequest.new()
	_api_http.timeout = 12.0
	add_child(_api_http)
	_api_http.request_completed.connect(_on_api_request_completed)

	_zip_http = HTTPRequest.new()
	_zip_http.use_threads = true
	_zip_http.timeout = 90.0
	add_child(_zip_http)
	_zip_http.request_completed.connect(_on_zip_download_completed)

	_detect_initial_local_state()

func _exit_tree() -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()
		_worker_thread = null

func _process(_delta: float) -> void:
	if is_downloading_zip and is_instance_valid(_zip_http):
		var dl_bytes := _zip_http.get_downloaded_bytes()
		var total_bytes := _zip_http.get_body_size()
		var mb_done := float(dl_bytes) / (1024.0 * 1024.0)
		if total_bytes > 0:
			progress_ratio = clampf(float(dl_bytes) / float(total_bytes), 0.05, 0.85)
			var mb_tot := float(total_bytes) / (1024.0 * 1024.0)
			status_text = "Downloading main archive... %.2f / %.2f MB" % [mb_done, mb_tot]
		else:
			progress_ratio = 0.45
			status_text = "Downloading main archive... %.2f MB" % mb_done
		state_changed.emit()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_install_mode_label() -> String:
	match install_mode:
		InstallMode.GIT_REPO:
			return "Git Repository (git pull)"
		InstallMode.ZIP_PROJECT:
			return "Project Folder (GitHub Archive)"
		InstallMode.STANDALONE_EXPORT:
			return "Standalone Build (Live Patch Pack)"
	return "Project Folder"

func short_sha(sha: String) -> String:
	if sha.is_empty():
		return "Unknown"
	return sha.left(7)

func get_base_version() -> String:
	var raw: String = ""
	if OS.has_feature("standalone") and FileAccess.file_exists(LIVE_PATCH_ZIP_PATH):
		var cfg := ConfigFile.new()
		if cfg.load(VERSION_STAMP_PATH) == OK:
			raw = str(cfg.get_value("version", "semver", "")).strip_edges()
	if raw.is_empty():
		raw = str(ProjectSettings.get_setting("application/config/version", "1.5.3")).strip_edges()
	if raw.is_empty():
		raw = "1.5.3"
	return raw if raw.begins_with("v") else ("v" + raw)

func get_display_version() -> String:
	var ver := get_base_version()
	if not local_sha.is_empty():
		return "%s (%s)" % [ver, local_sha.left(7)]
	return ver

func auto_check_on_menu() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_auto_check_msec < 120000:
		return
	_last_auto_check_msec = now
	check_for_updates(false)

func check_for_updates(force_log: bool = true) -> void:
	if is_busy:
		return
	_detect_initial_local_state()
	is_busy = true
	needs_stash_confirmation = false
	progress_ratio = 0.15
	status_text = "Checking GitHub (%s/%s @ %s)..." % [REPO_OWNER, REPO_NAME, BRANCH]
	if force_log:
		_append_log("Checking latest commit on %s/%s (%s)..." % [REPO_OWNER, REPO_NAME, BRANCH])
	state_changed.emit()

	var err := _api_http.request(COMMITS_API_URL, GITHUB_HEADERS, HTTPClient.Method.METHOD_GET)
	if err != OK:
		if _has_git_dir():
			_start_thread(_thread_git_fallback_check.bind(_get_project_dir()))
		else:
			is_busy = false
			progress_ratio = 0.0
			status_text = "Could not start network request (Error %d)." % err
			_append_log(status_text)
			state_changed.emit()

func start_update(stash_local_changes: bool = false) -> void:
	if is_busy:
		return
	_detect_initial_local_state()
	is_busy = true
	needs_stash_confirmation = false
	progress_ratio = 0.1

	if _has_git_dir() and _ensure_git_cli_available():
		install_mode = InstallMode.GIT_REPO
		status_text = "Updating from origin/main via Git..."
		_append_log("Starting git update from origin/%s..." % BRANCH)
		state_changed.emit()
		_start_thread(_thread_git_pull_update.bind(_get_project_dir(), stash_local_changes, OS.get_executable_path()))
	else:
		_start_zip_archive_download()

func open_github_page() -> void:
	OS.shell_open(GITHUB_WEB_URL)

func restart_game() -> void:
	var exe_path := OS.get_executable_path()
	if exe_path.is_empty():
		get_tree().reload_current_scene()
		return
	if OS.has_feature("standalone"):
		OS.create_process(exe_path, PackedStringArray())
	else:
		var proj_dir := _get_project_dir()
		OS.create_process(exe_path, PackedStringArray(["--path", proj_dir]))
	get_tree().quit()

# ---------------------------------------------------------------------------
# Local State & Pure-GDScript .git Reader (0 ms, no child process popup)
# ---------------------------------------------------------------------------

func _get_project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")

func _has_git_dir() -> bool:
	if OS.has_feature("standalone"):
		return false
	var git_path := _get_project_dir().path_join(".git")
	return DirAccess.dir_exists_absolute(git_path) or FileAccess.file_exists(git_path)

func _detect_initial_local_state() -> void:
	if OS.has_feature("standalone"):
		install_mode = InstallMode.STANDALONE_EXPORT
		local_sha = _load_saved_stamp_sha()
		return

	if _has_git_dir():
		install_mode = InstallMode.GIT_REPO if (not _git_cli_checked or _git_cli_available) else InstallMode.ZIP_PROJECT
		var git_sha := _read_git_head_sha(_get_project_dir())
		local_sha = git_sha if not git_sha.is_empty() else _load_saved_stamp_sha()
	else:
		install_mode = InstallMode.ZIP_PROJECT
		local_sha = _load_saved_stamp_sha()

func _read_git_head_sha(project_dir: String) -> String:
	var git_dir := project_dir.path_join(".git")
	# Support worktree gitfiles ("gitdir: ...")
	if FileAccess.file_exists(git_dir) and not DirAccess.dir_exists_absolute(git_dir):
		var ptr := FileAccess.get_file_as_string(git_dir).strip_edges()
		if ptr.begins_with("gitdir:"):
			var raw_target := ptr.substr(7).strip_edges()
			git_dir = raw_target if raw_target.is_absolute_path() else project_dir.path_join(raw_target)

	var head_path := git_dir.path_join("HEAD")
	if not FileAccess.file_exists(head_path):
		return ""
	var head_txt := FileAccess.get_file_as_string(head_path).strip_edges()
	if head_txt.begins_with("ref:"):
		var ref_rel := head_txt.substr(4).strip_edges()
		var ref_path := git_dir.path_join(ref_rel)
		if FileAccess.file_exists(ref_path):
			return FileAccess.get_file_as_string(ref_path).strip_edges()
		var packed_path := git_dir.path_join("packed-refs")
		if FileAccess.file_exists(packed_path):
			var lines := FileAccess.get_file_as_string(packed_path).split("\n")
			for line in lines:
				var clean := line.strip_edges()
				if clean.is_empty() or clean.begins_with("#") or clean.begins_with("^"):
					continue
				var parts := clean.split(" ", false)
				if parts.size() >= 2 and parts[1].strip_edges() == ref_rel:
					return parts[0].strip_edges()
		return ""
	return head_txt

func _load_saved_stamp_sha() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(VERSION_STAMP_PATH) == OK:
		return str(cfg.get_value("version", "sha", ""))
	return ""

func _save_stamp_sha(sha: String, semver: String = "") -> void:
	if sha.is_empty() and semver.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(VERSION_STAMP_PATH)
	if not sha.is_empty():
		cfg.set_value("version", "sha", sha)
	if not semver.is_empty():
		cfg.set_value("version", "semver", semver)
	cfg.set_value("version", "updated_at", Time.get_datetime_string_from_system())
	cfg.save(VERSION_STAMP_PATH)

func _ensure_git_cli_available() -> bool:
	if _git_cli_checked:
		return _git_cli_available
	_git_cli_checked = true
	var out: Array = []
	var code := OS.execute("git", PackedStringArray(["--version"]), out, true, false)
	_git_cli_available = (code == 0)
	return _git_cli_available

# ---------------------------------------------------------------------------
# GitHub REST API Response & Git Ancestry Verification
# ---------------------------------------------------------------------------

func _on_api_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if _has_git_dir():
			_append_log("GitHub API returned HTTP %d — checking via git ls-remote..." % response_code)
			_start_thread(_thread_git_fallback_check.bind(_get_project_dir()))
			return
		is_busy = false
		progress_ratio = 0.0
		status_text = "Could not reach GitHub (HTTP %d). You can still force-download main." % response_code
		_append_log(status_text)
		state_changed.emit()
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		is_busy = false
		progress_ratio = 0.0
		status_text = "Unexpected response format from GitHub."
		state_changed.emit()
		return

	var dict: Dictionary = parsed
	remote_sha = str(dict.get("sha", "")).strip_edges()
	var commit_dict: Dictionary = dict.get("commit", {}) if typeof(dict.get("commit")) == TYPE_DICTIONARY else {}
	var full_msg := str(commit_dict.get("message", "")).strip_edges()
	remote_message = full_msg.split("\n")[0].strip_edges() if not full_msg.is_empty() else "Latest commit on main"
	var author_dict: Dictionary = commit_dict.get("author", {}) if typeof(commit_dict.get("author")) == TYPE_DICTIONARY else {}
	remote_author = str(author_dict.get("name", ""))
	remote_date = str(author_dict.get("date", "")).left(16).replace("T", " ")

	# If we have a .git directory, run a fast background check for dirty status & whether remote_sha is already an ancestor
	if _has_git_dir():
		_start_thread(_thread_verify_git_status.bind(_get_project_dir(), remote_sha))
		return

	_finalize_version_comparison()

func _finalize_version_comparison() -> void:
	is_busy = false
	progress_ratio = 1.0
	is_ahead_of_remote = false

	if remote_sha.is_empty():
		update_available = false
		status_text = "Could not determine latest commit on main."
	elif not local_sha.is_empty() and local_sha == remote_sha:
		update_available = false
		status_text = "✓ Your game is up to date with main (%s)!" % short_sha(remote_sha)
		_append_log("Up to date at commit %s." % short_sha(remote_sha))
	elif local_sha.is_empty():
		update_available = true
		status_text = "Latest on main: %s — Click 'Update Now' to sync!" % short_sha(remote_sha)
		_append_log("Found main @ %s: \"%s\"" % [short_sha(remote_sha), remote_message])
	else:
		update_available = true
		status_text = "✨ New update available on main (%s → %s)!" % [short_sha(local_sha), short_sha(remote_sha)]
		_append_log("Update available: %s -> %s (\"%s\")" % [short_sha(local_sha), short_sha(remote_sha), remote_message])

	state_changed.emit()

# ---------------------------------------------------------------------------
# Background Worker Threads (Git Check & Git Pull)
# ---------------------------------------------------------------------------

func _start_thread(callable_task: Callable) -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()
	_worker_thread = Thread.new()
	_worker_thread.start(callable_task)

func _run_git(project_dir: String, args: Array) -> Dictionary:
	var full_args := PackedStringArray(["-C", project_dir])
	for a in args:
		full_args.append(str(a))
	var out: Array = []
	var code := OS.execute("git", full_args, out, true, false)
	var text := ""
	if not out.is_empty():
		text = str(out[0]).strip_edges()
	return {"code": code, "output": text}

func _thread_verify_git_status(project_dir: String, target_remote_sha: String) -> void:
	var ver_out: Array = []
	var has_git := (OS.execute("git", PackedStringArray(["--version"]), ver_out, true, false) == 0)
	if not has_git:
		call_deferred("_on_git_verify_done", {"has_git": false})
		return

	var status_res := _run_git(project_dir, ["status", "--porcelain"])
	var dirty: bool = (int(status_res["code"]) == 0 and not str(status_res["output"]).is_empty())

	var head_res := _run_git(project_dir, ["rev-parse", "HEAD"])
	var exact_head: String = str(head_res["output"]).strip_edges() if int(head_res["code"]) == 0 else ""

	var remote_is_ancestor: bool = false
	if not target_remote_sha.is_empty() and target_remote_sha != exact_head:
		var anc_res := _run_git(project_dir, ["merge-base", "--is-ancestor", target_remote_sha, "HEAD"])
		remote_is_ancestor = (int(anc_res["code"]) == 0)

	call_deferred("_on_git_verify_done", {
		"has_git": true,
		"dirty": dirty,
		"head_sha": exact_head,
		"remote_is_ancestor": remote_is_ancestor,
	})

func _on_git_verify_done(info: Dictionary) -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()

	_git_cli_checked = true
	_git_cli_available = bool(info.get("has_git", false))
	if not _git_cli_available:
		install_mode = InstallMode.ZIP_PROJECT
		_finalize_version_comparison()
		return

	install_mode = InstallMode.GIT_REPO
	has_local_changes = bool(info.get("dirty", false))
	var head_sha := str(info.get("head_sha", ""))
	if not head_sha.is_empty():
		local_sha = head_sha

	is_busy = false
	progress_ratio = 1.0

	if not remote_sha.is_empty() and local_sha == remote_sha:
		update_available = false
		is_ahead_of_remote = false
		status_text = "✓ Your game is up to date with origin/main (%s)!" % short_sha(remote_sha)
		_append_log("Repository is up to date (%s)." % short_sha(remote_sha))
	elif bool(info.get("remote_is_ancestor", false)):
		update_available = false
		is_ahead_of_remote = true
		status_text = "✓ Up to date — your local branch is ahead of origin/main (%s)." % short_sha(local_sha)
		_append_log("Local HEAD (%s) already contains origin/main (%s)." % [short_sha(local_sha), short_sha(remote_sha)])
	else:
		update_available = true
		is_ahead_of_remote = false
		status_text = "✨ New update available on main (%s → %s)!" % [short_sha(local_sha), short_sha(remote_sha)]
		_append_log("New commit on main: %s — \"%s\"" % [short_sha(remote_sha), remote_message])

	state_changed.emit()

func _thread_git_fallback_check(project_dir: String) -> void:
	var ver_out: Array = []
	if OS.execute("git", PackedStringArray(["--version"]), ver_out, true, false) != 0:
		call_deferred("_on_git_fallback_done", {"ok": false, "msg": "Could not reach GitHub and Git CLI is not installed."})
		return

	var ls_res := _run_git(project_dir, ["ls-remote", "origin", "refs/heads/" + BRANCH])
	if int(ls_res["code"]) != 0 or str(ls_res["output"]).is_empty():
		call_deferred("_on_git_fallback_done", {"ok": false, "msg": "Could not reach origin/%s." % BRANCH})
		return

	var fetched_sha: String = str(ls_res["output"]).split("\t")[0].split(" ")[0].strip_edges()
	var head_res := _run_git(project_dir, ["rev-parse", "HEAD"])
	var head_sha: String = str(head_res["output"]).strip_edges() if int(head_res["code"]) == 0 else ""
	var anc_res := _run_git(project_dir, ["merge-base", "--is-ancestor", fetched_sha, "HEAD"])
	call_deferred("_on_git_fallback_done", {
		"ok": true,
		"remote_sha": fetched_sha,
		"head_sha": head_sha,
		"remote_is_ancestor": (int(anc_res["code"]) == 0),
	})

func _on_git_fallback_done(res: Dictionary) -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()

	is_busy = false
	progress_ratio = 1.0
	if not bool(res.get("ok", false)):
		status_text = str(res.get("msg", "Update check failed."))
		_append_log(status_text)
		state_changed.emit()
		return

	_git_cli_checked = true
	_git_cli_available = true
	install_mode = InstallMode.GIT_REPO
	remote_sha = str(res.get("remote_sha", ""))
	if remote_message.is_empty():
		remote_message = "Latest commit on origin/" + BRANCH
	var h := str(res.get("head_sha", ""))
	if not h.is_empty():
		local_sha = h

	if local_sha == remote_sha or bool(res.get("remote_is_ancestor", false)):
		update_available = false
		status_text = "✓ Up to date with origin/main (%s)!" % short_sha(local_sha)
	else:
		update_available = true
		status_text = "✨ New update available on main (%s → %s)!" % [short_sha(local_sha), short_sha(remote_sha)]
	state_changed.emit()

func _thread_reimport_project(project_dir: String, exe_path: String, logs: Array[String]) -> void:
	if exe_path.is_empty():
		return
	logs.append("Rebuilding Godot class & UID cache (--headless --import)...")
	var out: Array = []
	var code: int = OS.execute(exe_path, PackedStringArray(["--headless", "--path", project_dir, "--import"]), out, true, false)
	if code == 0:
		logs.append("Godot class & UID cache refreshed.")
	else:
		logs.append("Cache refresh exited with code %d." % code)

func _collect_managed_files_recursive(base_dir: String, rel_dir: String, out_list: Array[String]) -> void:
	var abs_dir: String = base_dir.path_join(rel_dir)
	var da := DirAccess.open(abs_dir)
	if da == null:
		return
	da.list_dir_begin()
	var item: String = da.get_next()
	while not item.is_empty():
		if not item.begins_with("."):
			var child_rel: String = rel_dir.path_join(item).replace("\\", "/")
			if da.current_is_dir():
				_collect_managed_files_recursive(base_dir, child_rel, out_list)
			else:
				var ext: String = item.get_extension().to_lower()
				if ext in ["gd", "tscn", "tres", "gdshader", "uid"]:
					out_list.append(child_rel)
		item = da.get_next()
	da.list_dir_end()

func _thread_git_pull_update(project_dir: String, stash_first: bool, exe_path: String) -> void:
	var logs: Array[String] = []
	var status_res := _run_git(project_dir, ["status", "--porcelain"])
	var is_dirty: bool = (int(status_res["code"]) == 0 and not str(status_res["output"]).is_empty())

	if is_dirty and stash_first:
		logs.append("Stashing local uncommitted edits (git stash push -u)...")
		var stash_res := _run_git(project_dir, ["stash", "push", "-u", "-m", "Raiders Auto-Updater Backup"])
		if int(stash_res["code"]) != 0:
			call_deferred("_on_git_pull_done", {
				"ok": false,
				"logs": logs,
				"msg": "Could not stash local changes: " + str(stash_res["output"]),
			})
			return
		logs.append("Local changes safely saved to git stash.")
		is_dirty = false

	logs.append("Fetching latest commits from origin/%s..." % BRANCH)
	var fetch_res := _run_git(project_dir, ["fetch", "origin", BRANCH])
	if int(fetch_res["code"]) != 0:
		call_deferred("_on_git_pull_done", {
			"ok": false,
			"logs": logs,
			"msg": "git fetch failed: " + str(fetch_res["output"]),
		})
		return

	var behind_res := _run_git(project_dir, ["rev-list", "HEAD..origin/" + BRANCH, "--count"])
	var behind_count: int = int(str(behind_res["output"]).strip_edges()) if int(behind_res["code"]) == 0 else -1
	var new_head_check := _run_git(project_dir, ["rev-parse", "origin/" + BRANCH])
	var origin_sha: String = str(new_head_check["output"]).strip_edges() if int(new_head_check["code"]) == 0 else ""

	if behind_count == 0:
		var cur_head := _run_git(project_dir, ["rev-parse", "HEAD"])
		call_deferred("_on_git_pull_done", {
			"ok": true,
			"already_up_to_date": true,
			"new_sha": str(cur_head["output"]).strip_edges(),
			"origin_sha": origin_sha,
			"logs": logs,
			"msg": "✓ Already up to date with origin/%s!" % BRANCH,
		})
		return

	logs.append("Pulling %s new commit(s) from origin/%s..." % [str(behind_count) if behind_count > 0 else "latest", BRANCH])
	var pull_res := _run_git(project_dir, ["pull", "--ff-only", "origin", BRANCH])
	if int(pull_res["code"]) != 0:
		if is_dirty:
			call_deferred("_on_git_pull_done", {
				"ok": false,
				"needs_stash": true,
				"logs": logs,
				"msg": "Local modified files detected! Click 'Stash Local Changes & Update' to back them up and pull main safely.",
			})
			return

		# Clean tree with local commits: try clean rebase, abort safely if conflict
		logs.append("Fast-forward not possible; attempting clean rebase onto origin/%s..." % BRANCH)
		var rebase_res := _run_git(project_dir, ["pull", "--rebase", "origin", BRANCH])
		if int(rebase_res["code"]) != 0:
			_run_git(project_dir, ["rebase", "--abort"])
			call_deferred("_on_git_pull_done", {
				"ok": false,
				"logs": logs,
				"msg": "Automatic merge conflicted (aborted cleanly so nothing broke): " + str(rebase_res["output"]),
			})
			return

	_thread_reimport_project(project_dir, exe_path, logs)

	var updated_head := _run_git(project_dir, ["rev-parse", "HEAD"])
	var final_sha := str(updated_head["output"]).strip_edges()
	logs.append(str(pull_res["output"]))
	call_deferred("_on_git_pull_done", {
		"ok": true,
		"already_up_to_date": false,
		"new_sha": final_sha,
		"origin_sha": origin_sha,
		"logs": logs,
		"msg": "✓ Updated to %s! Restart the game to load all new content." % final_sha.left(7),
	})

func _on_git_pull_done(res: Dictionary) -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()

	for line in res.get("logs", []):
		if not str(line).strip_edges().is_empty():
			_append_log(str(line))

	is_busy = false
	var ok := bool(res.get("ok", false))
	needs_stash_confirmation = bool(res.get("needs_stash", false))
	status_text = str(res.get("msg", ""))
	_append_log(status_text)

	if ok:
		progress_ratio = 1.0
		var new_sha := str(res.get("new_sha", ""))
		if not new_sha.is_empty():
			local_sha = new_sha
			_save_stamp_sha(local_sha)
		var orig_sha := str(res.get("origin_sha", ""))
		if not orig_sha.is_empty():
			remote_sha = orig_sha
		update_available = false
		has_local_changes = false
		if not bool(res.get("already_up_to_date", false)):
			restart_recommended = true
	else:
		progress_ratio = 0.0

	state_changed.emit()

# ---------------------------------------------------------------------------
# GitHub Archive Download + Pure-Godot ZIPReader / ZIPPacker Installer
# ---------------------------------------------------------------------------

func _start_zip_archive_download() -> void:
	if FileAccess.file_exists(TEMP_ZIP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_ZIP_PATH))

	is_downloading_zip = true
	progress_ratio = 0.08
	status_text = "Connecting to GitHub to download main.zip..."
	_append_log("Downloading %s..." % ZIP_ARCHIVE_URL)
	state_changed.emit()

	_zip_http.download_file = TEMP_ZIP_PATH
	var err := _zip_http.request(ZIP_ARCHIVE_URL, PackedStringArray(["User-Agent: RaidersOfTheLostTemple-GodotUpdater/1.0"]), HTTPClient.Method.METHOD_GET)
	if err != OK:
		is_downloading_zip = false
		is_busy = false
		progress_ratio = 0.0
		status_text = "Failed to start archive download (Error %d)." % err
		_append_log(status_text)
		state_changed.emit()

func _on_zip_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading_zip = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		is_busy = false
		progress_ratio = 0.0
		status_text = "Download failed (HTTP %d). Check internet connection." % response_code
		_append_log(status_text)
		state_changed.emit()
		return

	progress_ratio = 0.9
	status_text = "Extracting updated temple files..."
	_append_log("Archive downloaded. Applying update files...")
	state_changed.emit()

	var is_standalone: bool = OS.has_feature("standalone")
	_start_thread(_thread_apply_zip_archive.bind(
		ProjectSettings.globalize_path(TEMP_ZIP_PATH),
		_get_project_dir(),
		is_standalone,
		ProjectSettings.globalize_path(LIVE_PATCH_ZIP_PATH),
		ProjectSettings.globalize_path(FILE_MANIFEST_PATH),
		OS.get_executable_path()
	))

func _thread_apply_zip_archive(zip_abs_path: String, project_dir: String, is_standalone: bool, patch_zip_abs: String, manifest_abs_path: String, exe_path: String) -> void:
	var logs: Array[String] = []
	var reader := ZIPReader.new()
	var err: int = reader.open(zip_abs_path)
	if err != OK:
		call_deferred("_on_zip_install_done", {
			"ok": false,
			"logs": logs,
			"msg": "Could not open downloaded ZIP archive (Error %d)." % err,
		})
		return

	var files := reader.get_files()
	var updated_count: int = 0
	var removed_count: int = 0
	var extracted_semver: String = ""
	var new_files: Dictionary = {}
	var packer: ZIPPacker = null

	if is_standalone:
		packer = ZIPPacker.new()
		var p_err: int = packer.open(patch_zip_abs, ZIPPacker.APPEND_CREATE)
		if p_err != OK:
			reader.close()
			call_deferred("_on_zip_install_done", {
				"ok": false,
				"logs": logs,
				"msg": "Could not create live patch pack (Error %d)." % p_err,
			})
			return

	for entry in files:
		if entry.ends_with("/"):
			continue
		var slash_idx: int = entry.find("/")
		var rel_path: String = (entry.substr(slash_idx + 1) if slash_idx >= 0 else entry).replace("\\", "/")
		if rel_path.is_empty() or rel_path.begins_with(".git/") or rel_path.begins_with(".godot/"):
			continue

		var file_bytes: PackedByteArray = reader.read_file(entry)
		if rel_path == "project.godot":
			var pg_txt: String = file_bytes.get_string_from_utf8()
			for line in pg_txt.split("\n"):
				var clean_line: String = line.strip_edges()
				if clean_line.begins_with("config/version="):
					extracted_semver = clean_line.substr(15).strip_edges().trim_prefix("\"").trim_suffix("\"")
					break

		new_files[rel_path] = true
		if is_standalone and packer != null:
			if packer.start_file(rel_path) == OK:
				packer.write_file(file_bytes)
				packer.close_file()
				updated_count += 1
		else:
			var dest_abs: String = project_dir.path_join(rel_path)
			var parent_dir: String = dest_abs.get_base_dir()
			if not DirAccess.dir_exists_absolute(parent_dir):
				DirAccess.make_dir_recursive_absolute(parent_dir)
			var fa := FileAccess.open(dest_abs, FileAccess.WRITE)
			if fa != null:
				fa.store_buffer(file_bytes)
				fa.close()
				updated_count += 1

	if packer != null:
		packer.close()
	reader.close()
	DirAccess.remove_absolute(zip_abs_path)

	if not is_standalone and updated_count > 0:
		var prev_files: Array[String] = []
		if FileAccess.file_exists(manifest_abs_path):
			var prev_txt: String = FileAccess.get_file_as_string(manifest_abs_path)
			for p_line in prev_txt.split("\n", false):
				var clean_p: String = p_line.strip_edges().replace("\\", "/")
				if not clean_p.is_empty():
					prev_files.append(clean_p)
		else:
			for sub in ["scenes", "scripts", "shaders"]:
				_collect_managed_files_recursive(project_dir, sub, prev_files)

		for old_rel in prev_files:
			if old_rel.begins_with(".git/") or old_rel.begins_with(".godot/"):
				continue
			if not new_files.has(old_rel):
				var full_old: String = project_dir.path_join(old_rel)
				if FileAccess.file_exists(full_old) and DirAccess.remove_absolute(full_old) == OK:
					removed_count += 1

		var sorted_keys: Array[String] = []
		for k in new_files.keys():
			sorted_keys.append(str(k))
		sorted_keys.sort()
		var mf := FileAccess.open(manifest_abs_path, FileAccess.WRITE)
		if mf != null:
			mf.store_string("\n".join(sorted_keys))
			mf.close()

		if removed_count > 0:
			logs.append("Removed %d deleted/renamed file(s) from previous version." % removed_count)

		_thread_reimport_project(project_dir, exe_path, logs)

	call_deferred("_on_zip_install_done", {
		"ok": updated_count > 0,
		"count": updated_count,
		"removed": removed_count,
		"semver": extracted_semver,
		"standalone": is_standalone,
		"logs": logs,
		"msg": "✓ Installed %d files from main! Restart the game to apply all changes." % updated_count if updated_count > 0 else "No files were extracted from archive.",
	})

func _on_zip_install_done(res: Dictionary) -> void:
	if _worker_thread != null and _worker_thread.is_started():
		_worker_thread.wait_to_finish()

	for line in res.get("logs", []):
		if not str(line).strip_edges().is_empty():
			_append_log(str(line))

	is_busy = false
	var ok: bool = bool(res.get("ok", false))
	status_text = str(res.get("msg", ""))
	_append_log(status_text)

	if ok:
		progress_ratio = 1.0
		if bool(res.get("standalone", false)) and FileAccess.file_exists(LIVE_PATCH_ZIP_PATH):
			ProjectSettings.load_resource_pack(LIVE_PATCH_ZIP_PATH, true)
		var semver: String = str(res.get("semver", ""))
		if not remote_sha.is_empty():
			local_sha = remote_sha
			_save_stamp_sha(local_sha, semver)
		elif not semver.is_empty():
			_save_stamp_sha("", semver)
		update_available = false
		restart_recommended = true
	else:
		progress_ratio = 0.0

	state_changed.emit()

func _append_log(line: String) -> void:
	var stamp := Time.get_time_string_from_system()
	var entry := "[%s] %s" % [stamp, line]
	log_lines.append(entry)
	if log_lines.size() > 60:
		log_lines.pop_front()
	log_appended.emit(entry)
