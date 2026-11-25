extends Node
## Export templates run this scene to verify the metadata inside the actual PCK.

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var manager: Node = get_node("/root/UpdateManager")
	if args.size() != 1 or not OS.has_feature("template") or int(manager.get("install_mode")) != 2 or str(manager.get("local_sha")) != args[0]:
		push_error("Export version check failed: mode=%s sha=%s" % [manager.get("install_mode"), manager.get("local_sha")])
		get_tree().quit(1)
		return
	print("PASS: exported build embeds %s and uses Standalone Build mode." % args[0])
	get_tree().quit()
