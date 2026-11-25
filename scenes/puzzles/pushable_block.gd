extends CharacterBody3D
class_name PushableBlock

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")
const CARRY_DISTANCE: float = 1.25
const CARRY_FOLLOW_SPEED: float = 14.0

@export var push_speed: float = 3.2
@export var friction: float = 14.0

var push_velocity: Vector3 = Vector3.ZERO
var grabbed_by: Player = null
var spawn_position: Vector3 = Vector3.ZERO
var _dust_timer: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("pushable")
	add_to_group("interactable")
	floor_snap_length = 0.16
	spawn_position = global_position

func get_interact_prompt() -> String:
	return "Release Block" if is_instance_valid(grabbed_by) else "Grab Block"

func push(direction: Vector3, force: float = 3.0) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
			_rpc_request_push.rpc_id(1, direction.normalized(), force)
		push_velocity = direction.normalized() * min(force, push_speed)

@rpc("any_peer", "unreliable_ordered")
func _rpc_request_push(dir: Vector3, force: float) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_host and grabbed_by == null:
		push_velocity = dir * min(force, push_speed)

func interact(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		_rpc_request_grab_toggle.rpc_id(1, player.player_id)
		return
	if grabbed_by == null:
		grab(player)
	elif grabbed_by == player:
		release()

func on_whipped(player: Player) -> void:
	if is_instance_valid(grabbed_by) or not is_instance_valid(player):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		_rpc_request_whip_pull.rpc_id(1, player.global_position)
		return
	var pull_dir := player.global_position - global_position
	pull_dir.y = 0.0
	if pull_dir.length_squared() > 0.05:
		push_velocity = pull_dir.normalized() * 7.2
		if is_instance_valid(get_parent()):
			DUST_PUFF.spawn(get_parent(), global_position - Vector3(0, 0.3, 0), 3, 0.95)

@rpc("any_peer", "reliable")
func _rpc_request_whip_pull(from_pos: Vector3) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_host or is_instance_valid(grabbed_by):
		return
	var pull_dir := from_pos - global_position
	pull_dir.y = 0.0
	if pull_dir.length_squared() > 0.05:
		push_velocity = pull_dir.normalized() * 7.2

@rpc("any_peer", "reliable")
func _rpc_request_grab_toggle(pid: int) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_host:
		return
	var lvl := get_tree().current_scene
	if not is_instance_valid(lvl) or not ("players" in lvl) or not lvl.players.has(pid):
		return
	var p: Player = lvl.players[pid]
	if grabbed_by == null:
		grab(p)
	elif grabbed_by == p:
		release()

func grab(player: Player) -> void:
	grabbed_by = player
	if is_instance_valid(player):
		player.grabbed_block = self
		add_collision_exception_with(player)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_grab.rpc(player.player_id if is_instance_valid(player) else 0)

func release() -> void:
	if is_instance_valid(grabbed_by):
		remove_collision_exception_with(grabbed_by)
		if grabbed_by.grabbed_block == self:
			grabbed_by.grabbed_block = null
	grabbed_by = null
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_grab.rpc(0)

@rpc("authority", "reliable")
func _rpc_sync_grab(pid: int) -> void:
	if pid == 0:
		if is_instance_valid(grabbed_by):
			remove_collision_exception_with(grabbed_by)
			if grabbed_by.grabbed_block == self:
				grabbed_by.grabbed_block = null
		grabbed_by = null
		return
	var lvl := get_tree().current_scene
	if is_instance_valid(lvl) and ("players" in lvl) and lvl.players.has(pid):
		var p: Player = lvl.players[pid]
		grabbed_by = p
		p.grabbed_block = self
		add_collision_exception_with(p)

func _physics_process(delta: float) -> void:
	# If grabbed by a player, lift slightly and carry the crate smoothly in front of them
	if is_instance_valid(grabbed_by):
		var dist = global_position.distance_to(grabbed_by.global_position)
		if dist > 3.6:
			# Auto-release if blocked by a solid wall and player walks far away
			release()
		else:
			var forward := Vector3(grabbed_by.mesh_root.global_basis.z.x, 0.0, grabbed_by.mesh_root.global_basis.z.z)
			forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.BACK
			var target_pos := grabbed_by.global_position + forward * CARRY_DISTANCE
			var to_target := target_pos - global_position
			velocity.x = to_target.x * CARRY_FOLLOW_SPEED
			velocity.z = to_target.z * CARRY_FOLLOW_SPEED
			var target_y := grabbed_by.global_position.y + 0.18
			velocity.y = (target_y - global_position.y) * 14.0
	else:
		# Gravity when resting or pushed along the floor
		if not is_on_floor():
			velocity.y -= 19.6 * delta
		else:
			velocity.y = 0.0
		# Natural push velocity from walking into it
		velocity.x = push_velocity.x
		velocity.z = push_velocity.z
		push_velocity = push_velocity.move_toward(Vector3.ZERO, friction * delta)

	move_and_slide()

	# Save safe respawn spot when resting on permanent stone floor (not temporary phase bridges)
	if grabbed_by == null and is_on_floor():
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var col_body := col.get_collider()
			if col.get_normal().y > 0.8 and col_body is StaticBody3D and not (col_body is PhasePlatform):
				spawn_position = global_position
				break

	if global_position.y < -4.5:
		release()
		velocity = Vector3.ZERO
		push_velocity = Vector3.ZERO
		global_position = spawn_position + Vector3(0.0, 0.25, 0.0)
		DUST_PUFF.spawn(get_parent(), global_position, 4, 1.0)
		return

	if Vector2(velocity.x, velocity.z).length() > 0.6 and is_on_floor():
		_dust_timer += delta
		if _dust_timer >= 0.18:
			_dust_timer = 0.0
			DUST_PUFF.spawn(get_parent(), global_position - Vector3(0, 0.35, 0), 2, 0.85)
	else:
		_dust_timer = 0.12
