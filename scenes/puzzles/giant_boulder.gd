extends CharacterBody3D
class_name GiantBoulder

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")

signal boulder_stopped()

@export var roll_speed: float = 7.0
@export var is_rolling: bool = false
@export var roll_direction: Vector3 = Vector3(0, 0, 1) # Rolling forward toward entrance

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var damage_area: Area3D = $DamageArea
@onready var rumble_light: OmniLight3D = $OmniLight3D

var camera_ref: CoopCamera = null
var rumble_audio: AudioStreamPlayer3D = null
var _dust_timer: float = 0.0

func _ready() -> void:
	visible = false  # Hidden until idol is grabbed
	damage_area.body_entered.connect(_on_damage_area_entered)
	var cams = get_tree().get_nodes_in_group("coop_camera")
	if cams.size() > 0:
		camera_ref = cams[0]
	if is_instance_valid(AudioManager):
		rumble_audio = AudioManager.create_player_3d(&"boulder_rumble", self, -3.0, 32.0, 8.0)

func trigger_roll() -> void:
	visible = true  # Reveal boulder right before it starts rolling
	is_rolling = true
	if is_instance_valid(rumble_audio):
		rumble_audio.play()

func _physics_process(delta: float) -> void:
	if not is_rolling:
		return

	# Auto-steer slightly toward center of hallway (x = 0) so it tracks clean through every door
	var center_correction = clampf(-global_position.x * 2.5, -3.0, 3.0)
	velocity.x = center_correction
	velocity.z = roll_speed * roll_direction.z
	velocity.y -= 19.6 * delta
	move_and_slide()

	# Rotate the boulder mesh as it rolls forward
	mesh_instance.rotate_x(roll_speed * delta * 0.75)

	# Trail dust puffs behind the rolling boulder
	_dust_timer += delta
	if _dust_timer >= 0.09:
		_dust_timer = 0.0
		DUST_PUFF.spawn(get_parent(), global_position - Vector3(0, 1.0, 1.0), 3, 1.6)

	# Camera rumble based on proximity to players
	if is_instance_valid(camera_ref) and global_position.distance_to(camera_ref.global_position) < 22.0:
		camera_ref.trigger_shake(0.06, 0.1)

	# Handle collisions
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()

		# Smash through any pushable blocks in the corridor!
		if collider is PushableBlock or (collider and collider.is_in_group("pushable")):
			collider.queue_free()
			continue

		# Only stop when hitting the dead-end wall at the very end of the entrance room (z >= 4.5)
		if global_position.z >= 4.5:
			if col.get_normal().dot(-roll_direction) > 0.6:
				is_rolling = false
				boulder_stopped.emit()
				_smash_effect()
				break

	# Fallback safety: stop if it rolls past the back wall
	if is_rolling and global_position.z >= 5.5:
		is_rolling = false
		boulder_stopped.emit()
		_smash_effect()

func _smash_effect() -> void:
	if is_instance_valid(rumble_audio):
		rumble_audio.stop()
	if is_instance_valid(camera_ref):
		camera_ref.trigger_shake(0.22, 0.35)
	DUST_PUFF.spawn(get_parent(), global_position, 8, 2.0)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.85, 1.15), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.15)

func _on_damage_area_entered(body: Node3D) -> void:
	if not is_rolling:
		return
	if body is Player:
		body.take_damage(2)
		var knock_dir = (body.global_position - global_position).normalized()
		knock_dir.y = 0.5
		body.velocity = knock_dir * 12.0
