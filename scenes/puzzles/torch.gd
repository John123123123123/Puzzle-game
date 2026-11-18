extends Node3D
class_name Torch

@onready var light: OmniLight3D = $OmniLight3D
@onready var flame_mesh: MeshInstance3D = $Flame

var is_lit: bool = true
var _flicker_time: float = 0.0

func _ready() -> void:
	add_to_group("carryable")
	_flicker_time = randf() * 10.0

func _process(delta: float) -> void:
	if is_lit and is_instance_valid(light):
		_flicker_time += delta
		light.light_energy = 1.9 + sin(_flicker_time * 13.0) * 0.15 + sin(_flicker_time * 27.0) * 0.08

func extinguish() -> void:
	if not is_lit:
		return
	is_lit = false
	if is_instance_valid(light):
		light.visible = false
	if is_instance_valid(flame_mesh):
		flame_mesh.visible = false

func relight() -> void:
	if is_lit:
		return
	is_lit = true
	if is_instance_valid(light):
		light.visible = true
	if is_instance_valid(flame_mesh):
		flame_mesh.visible = true

func get_interact_prompt() -> String:
	return "Pick Up Torch"

func on_picked_up(player: Player) -> void:
	pass

func on_dropped(player: Player) -> void:
	pass
