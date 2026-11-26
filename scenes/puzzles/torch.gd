extends Node3D
class_name Torch

@onready var light: OmniLight3D = $OmniLight3D
@onready var pickup_area: Area3D = $PickupArea
@onready var pitch_head: MeshInstance3D = get_node_or_null("PitchHead")
@onready var ember_trail: CPUParticles3D = get_node_or_null("EmberTrail")

var _flicker_time: float = 0.0
var _ember_mat: StandardMaterial3D = null
var is_carried: bool = false

func _ready() -> void:
	add_to_group("carryable")
	_flicker_time = randf() * 10.0
	if is_instance_valid(pitch_head):
		var pm := pitch_head.get_active_material(0) as StandardMaterial3D
		if pm:
			_ember_mat = pm.duplicate() as StandardMaterial3D
			pitch_head.material_override = _ember_mat

func _process(delta: float) -> void:
	_flicker_time += delta
	var pulse := sin(_flicker_time * 13.0) * 0.15 + sin(_flicker_time * 27.0) * 0.08
	if is_instance_valid(light):
		light.light_energy = 1.95 + pulse
	if _ember_mat:
		_ember_mat.emission_energy_multiplier = 1.6 + pulse * 2.2
	if is_instance_valid(ember_trail):
		ember_trail.speed_scale = 1.35 if is_carried else 0.95

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
