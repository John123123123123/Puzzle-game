extends Node3D
class_name WallLever

signal toggled(is_on: bool)

@export var is_on: bool = false
@export var is_one_shot: bool = false
@export var targets: Array[NodePath] = []

@onready var handle_pivot: Node3D = $Base/HandlePivot
@onready var light_indicator: OmniLight3D = $LightIndicator

func _ready() -> void:
	add_to_group("whip_target")
	_update_visuals(false)

func interact(player: Player) -> void:
	toggle()

func on_whipped(player: Player) -> void:
	toggle()

func toggle() -> void:
	if is_one_shot and is_on:
		return

	is_on = !is_on
	_update_visuals(true)
	toggled.emit(is_on)

	# Trigger any directly linked objects (like doors or traps)
	for path in targets:
		var node = get_node_or_null(path)
		if node:
			if is_on and node.has_method("register_trigger_activated"):
				node.register_trigger_activated()
			elif not is_on and node.has_method("register_trigger_deactivated"):
				node.register_trigger_deactivated()
			elif node.has_method("toggle"):
				node.toggle()

func _update_visuals(animate: bool) -> void:
	var target_rot_x = deg_to_rad(45.0) if is_on else deg_to_rad(-45.0)
	if animate:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(handle_pivot, "rotation:x", target_rot_x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if light_indicator:
			var target_color = Color(0.2, 1.0, 0.4) if is_on else Color(1.0, 0.2, 0.2)
			tween.tween_property(light_indicator, "light_color", target_color, 0.2)
	else:
		handle_pivot.rotation.x = target_rot_x
		if light_indicator:
			light_indicator.light_color = Color(0.2, 1.0, 0.4) if is_on else Color(1.0, 0.2, 0.2)
