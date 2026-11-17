extends CharacterBody3D
class_name PushableBlock

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")

@export var push_speed: float = 3.2
@export var friction: float = 14.0

var push_velocity: Vector3 = Vector3.ZERO
var grabbed_by: Player = null
var _dust_timer: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("pushable")
	add_to_group("interactable")

func get_interact_prompt() -> String:
	return "Release Block" if is_instance_valid(grabbed_by) else "Grab Block"

func push(direction: Vector3, force: float = 3.0) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		push_velocity = direction.normalized() * min(force, push_speed)

func interact(player: Player) -> void:
	if grabbed_by == null:
		grab(player)
	elif grabbed_by == player:
		release()

func grab(player: Player) -> void:
	grabbed_by = player
	if is_instance_valid(player):
		player.grabbed_block = self

func release() -> void:
	if is_instance_valid(grabbed_by) and grabbed_by.grabbed_block == self:
		grabbed_by.grabbed_block = null
	grabbed_by = null

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0

	# If grabbed by a player, follow player's movement
	if is_instance_valid(grabbed_by):
		var dist = global_position.distance_to(grabbed_by.global_position)
		if dist > 2.6:
			# Auto-release if player moves too far away
			release()
		else:
			# Pull/push in sync with grabbing player
			velocity.x = grabbed_by.velocity.x
			velocity.z = grabbed_by.velocity.z
	else:
		# Natural push velocity from walking into it
		velocity.x = push_velocity.x
		velocity.z = push_velocity.z
		push_velocity = push_velocity.move_toward(Vector3.ZERO, friction * delta)

	move_and_slide()

	if Vector2(velocity.x, velocity.z).length() > 0.6 and is_on_floor():
		_dust_timer += delta
		if _dust_timer >= 0.18:
			_dust_timer = 0.0
			DUST_PUFF.spawn(get_parent(), global_position - Vector3(0, 0.35, 0), 2, 0.85)
	else:
		_dust_timer = 0.12
