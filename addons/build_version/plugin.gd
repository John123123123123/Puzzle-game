@tool
extends EditorPlugin

const BuildVersionExport = preload("res://addons/build_version/export_plugin.gd")

var _export_plugin: EditorExportPlugin

func _enter_tree() -> void:
	_export_plugin = BuildVersionExport.new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
