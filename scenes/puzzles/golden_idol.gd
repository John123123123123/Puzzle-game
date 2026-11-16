extends Node3D
class_name GoldenIdol

signal idol_taken(by_player: Player)

var is_taken: bool = false

@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	add_to_group("carryable")

func on_picked_up(player: Player) -> void:
	if not is_taken:
		is_taken = true
		idol_taken.emit(player)

func on_dropped(player: Player) -> void:
	pass
