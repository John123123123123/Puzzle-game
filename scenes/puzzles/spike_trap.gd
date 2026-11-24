extends Node3D
class_name SpikeTrap

@export var cycle_time: float = 3.0
@export var warning_time: float = 0.5
@export var active_time: float = 1.0
@export var phase_offset: float = 0.0
@export var damage: int = 1

var is_active: bool = false
var timer: float = 0.0

@onready var spikes_mesh: Node3D = $SpikesRoot
@onready var damage_area: Area3D = $DamageArea

func _ready() -> void:
	add_to_group("spike_trap")
	damage_area.body_entered.connect(_on_body_entered)
	spikes_mesh.position.y = -0.45

func _physics_process(delta: float) -> void:
	timer += delta
	var current_phase = fmod(timer + phase_offset, cycle_time)

	if current_phase < (cycle_time - warning_time - active_time):
		# Retracted safe state
		if is_active:
			_retract_spikes()
	elif current_phase < (cycle_time - active_time):
		# Warning phase: silent visual tremor/peek
		spikes_mesh.position.y = -0.32 + randf_range(-0.015, 0.015)
	else:
		# Thrust up!
		if not is_active:
			_thrust_spikes()

func _thrust_spikes() -> void:
	is_active = true

	var tween = create_tween()
	# Fast, violent snap upward with overshoot
	tween.tween_property(spikes_mesh, "position:y", 0.38, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Check any players already standing on the trap when it triggers!
	_check_damage_overlapping()

func _retract_spikes() -> void:
	is_active = false
	var tween = create_tween()
	tween.tween_property(spikes_mesh, "position:y", -0.45, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _check_damage_overlapping() -> void:
	if not is_instance_valid(damage_area):
		return
	for body in damage_area.get_overlapping_bodies():
		if body is Player:
			body.take_damage(damage)

func _on_body_entered(body: Node3D) -> void:
	if is_active and body is Player:
		body.take_damage(damage)
