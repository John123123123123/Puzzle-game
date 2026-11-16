extends CharacterBody3D
class_name PushableBlock

@export var push_speed: float = 3.2
@export var friction: float = 14.0

var push_velocity: Vector3 = Vector3.ZERO
var grabbed_by: Player = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("pushable")
	add_to_group("interactable")

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

func release() -> void:
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
			velocity.x = grabbed_by.velocity.x * 0.75
			velocity.z = grabbed_by.velocity.z * 0.75
	else:
		# Natural push velocity from walking into it
		velocity.x = push_velocity.x
		velocity.z = push_velocity.z
		push_velocity = push_velocity.move_toward(Vector3.ZERO, friction * delta)

	move_and_slide()
