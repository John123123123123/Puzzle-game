extends Node3D
class_name Torch

@onready var light: OmniLight3D = $OmniLight3D

var _flicker_time: float = 0.0

func _ready() -> void:
	add_to_group("carryable")
	_flicker_time = randf() * 10.0

func _process(delta: float) -> void:
	if is_instance_valid(light):
		_flicker_time += delta
		light.light_energy = 1.9 + sin(_flicker_time * 13.0) * 0.15 + sin(_flicker_time * 27.0) * 0.08

func get_interact_prompt() -> String:
	return "Pick Up Torch"

func on_picked_up(player: Player) -> void:
	pass

func on_dropped(player: Player) -> void:
	pass
