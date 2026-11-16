extends Node3D
class_name SpikeTrap

@export var cycle_time: float = 3.0
@export var warning_time: float = 0.6
@export var active_time: float = 1.2
@export var damage: int = 1

var is_active: bool = false
var timer: float = 0.0

@onready var spikes_mesh: Node3D = $SpikesRoot
@onready var damage_area: Area3D = $DamageArea

func _ready() -> void:
	damage_area.body_entered.connect(_on_body_entered)
	spikes_mesh.position.y = -0.4

func _physics_process(delta: float) -> void:
	timer += delta
	var current_phase = fmod(timer, cycle_time)

	if current_phase < (cycle_time - warning_time - active_time):
		# Retracted state
		if is_active:
			_retract_spikes()
	elif current_phase < (cycle_time - active_time):
		# Warning: small rumble
		spikes_mesh.position.y = -0.28 + randf_range(-0.02, 0.02)
	else:
		# Thrust up!
		if not is_active:
			_thrust_spikes()

func _thrust_spikes() -> void:
	is_active = true
	var tween = create_tween()
	tween.tween_property(spikes_mesh, "position:y", 0.35, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _retract_spikes() -> void:
	is_active = false
	var tween = create_tween()
	tween.tween_property(spikes_mesh, "position:y", -0.4, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_body_entered(body: Node3D) -> void:
	if is_active and body is Player:
		body.take_damage(damage)
