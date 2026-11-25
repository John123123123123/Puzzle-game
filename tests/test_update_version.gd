extends SceneTree
## Run with --script res://tests/test_update_version.gd -- <expected Git SHA>.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the expected Git SHA after --.")
		quit(1)
		return
	var manager: Node = root.get_node("UpdateManager")
	var expected_mode: int = 2 if OS.has_feature("template") else 0
	if int(manager.get("install_mode")) != expected_mode or str(manager.get("local_sha")) != args[0]:
		push_error("Wrong installed version: mode=%s sha=%s expected mode=%s sha=%s" % [manager.get("install_mode"), manager.get("local_sha"), expected_mode, args[0]])
		quit(1)
		return
	if OS.has_feature("editor"):
		var exporter: Script = load("res://addons/build_version/export_plugin.gd")
		var cfg: ConfigFile = exporter.build_info(ProjectSettings.globalize_path("res://"))
		if str(cfg.get_value("build", "sha", "")) != args[0]:
			push_error("Local export metadata does not match Git HEAD.")
			quit(1)
			return
	print("PASS: installed version %s, mode %s" % [args[0], manager.get_install_mode_label()])
	quit()
