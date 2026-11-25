@tool
extends EditorExportPlugin

const BUILD_INFO_PATH := "res://build_info.cfg"
var _embedded_info: bool = false

func _get_name() -> String:
	return "BuildVersion"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var cfg: ConfigFile = build_info(ProjectSettings.globalize_path("res://"))
	_embedded_info = not str(cfg.get_value("build", "sha", "")).is_empty()
	if _embedded_info:
		add_file(BUILD_INFO_PATH, cfg.encode_to_text().to_utf8_buffer(), false)
	else:
		push_warning("No Git commit metadata found. This export will display an unknown installed commit.")

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	# The generated metadata takes precedence over an old file left by a CI build.
	if _embedded_info and path == BUILD_INFO_PATH:
		skip()

static func build_info(project_dir: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	var output: Array = []
	var code: int = OS.execute("git", PackedStringArray(["-C", project_dir, "rev-parse", "HEAD"]), output, false, false)
	var sha: String = str(output[0]).strip_edges().to_lower() if code == 0 and not output.is_empty() else ""
	if sha.length() != 40 or not sha.is_valid_hex_number(false):
		# CI already writes this file; source archives may carry an export-subst marker.
		cfg.load(project_dir.path_join("build_info.cfg"))
		sha = str(cfg.get_value("build", "sha", "")).strip_edges().to_lower()
		if sha.length() != 40 or not sha.is_valid_hex_number(false):
			var marker: String = project_dir.path_join("archive_commit.txt")
			sha = FileAccess.get_file_as_string(marker).strip_edges().to_lower() if FileAccess.file_exists(marker) else ""
		if sha.length() != 40 or not sha.is_valid_hex_number(false):
			return ConfigFile.new()
		cfg.set_value("build", "sha", sha)
		return cfg
	# This is generated directly into the PCK; no source file needs to be maintained.
	cfg.set_value("build", "sha", sha)
	cfg.set_value("build", "built_at", Time.get_datetime_string_from_system(true))
	return cfg
