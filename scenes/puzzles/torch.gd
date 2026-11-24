extends Node3D
class_name Torch

@onready var light: OmniLight3D = $OmniLight3D
@onready var pickup_area: Area3D = $PickupArea

var _flicker_time: float = 0.0
var is_carried: bool = false

func _ready() -> void:
	add_to_group("carryable")
	_flicker_time = randf() * 10.0

func _process(delta: float) -> void:
	if is_instance_valid(light):
		_flicker_time += delta
		light.light_energy = 1.95 + sin(_flicker_time * 13.0) * 0.15 + sin(_flicker_time * 27.0) * 0.08

func get_interact_prompt() -> String:
	return "" if is_carried else "Pick Up Torch"

func on_whipped(player: Player) -> void:
	if is_carried or not is_instance_valid(player):
		return
	if player.carried_item == null and not is_instance_valid(player.grabbed_block):
		player.pick_up_item(self)

func on_picked_up(_player: Player) -> void:
	is_carried = true
	if is_instance_valid(pickup_area):
		pickup_area.set_deferred("monitorable", false)

func on_dropped(_player: Player) -> void:
	is_carried = false
	if is_instance_valid(pickup_area):
		pickup_area.set_deferred("monitorable", true)
