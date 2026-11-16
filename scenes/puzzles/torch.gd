extends Node3D
class_name Torch

@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	add_to_group("carryable")

func on_picked_up(player: Player) -> void:
	pass

func on_dropped(player: Player) -> void:
	pass
