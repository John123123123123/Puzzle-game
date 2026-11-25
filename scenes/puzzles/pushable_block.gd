extends CharacterBody3D
class_name PushableBlock

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")
const CARRY_DISTANCE: float = 1.25
const CARRY_FOLLOW_SPEED: float = 14.0

@export var push_speed: float = 3.2
@export var friction: float = 14.0

var push_velocity: Vector3 = Vector3.ZERO
var grabbed_by: Player = null
var initial_spawn_position: Vector3 = Vector3.ZERO
var spawn_position: Vector3 = Vector3.ZERO
var _dust_timer: float = 0.0
var _last_respawn_time: float = -10.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("pushable")
	add_to_group("interactable")
	floor_snap_length = 0.16
	initial_spawn_position = global_position
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
	var was_local_client_grab: bool = (
		is_instance_valid(grabbed_by)
		and grabbed_by.is_local_controlled()
		and is_instance_valid(NetworkManager)
		and NetworkManager.is_online
		and not NetworkManager.is_host
	)
	if was_local_client_grab:
		_rpc_request_release.rpc_id(1, global_position)
	if is_instance_valid(grabbed_by):
		remove_collision_exception_with(grabbed_by)
		if grabbed_by.grabbed_block == self:
			grabbed_by.grabbed_block = null
	grabbed_by = null
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_grab.rpc(0)

@rpc("any_peer", "reliable")
func _rpc_request_release(client_pos: Vector3) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_online or not NetworkManager.is_host:
		return
	if not is_instance_valid(grabbed_by):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != NetworkManager.get_peer_for_slot(grabbed_by.player_id):
		return
	if global_position.distance_to(client_pos) < 2.8:
		global_position = client_pos
	release()

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
	var is_authority: bool = not (is_instance_valid(NetworkManager) and NetworkManager.is_online) or NetworkManager.is_host
	# If grabbed by a player, lift slightly and carry the crate smoothly in front of them
	if is_instance_valid(grabbed_by):
		var dist = global_position.distance_to(grabbed_by.global_position)
		if dist > 3.6:
			if is_authority:
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
			velocity.y = -0.15
		# Natural push velocity from walking into it
		velocity.x = push_velocity.x
		velocity.z = push_velocity.z
		push_velocity = push_velocity.move_toward(Vector3.ZERO, friction * delta)

	move_and_slide()

	# Save safe respawn spot only when fully supported on permanent stone floor (not temporary phase bridges or edges)
	if grabbed_by == null and is_on_floor() and _is_position_supported_on_permanent_floor(global_position):
		spawn_position = global_position

	if is_authority and global_position.y < -2.5:
		var now_sec: float = float(Time.get_ticks_msec()) * 0.001
		var respawn_target: Vector3 = spawn_position if (now_sec - _last_respawn_time > 3.5 and _is_position_supported_on_permanent_floor(spawn_position)) else initial_spawn_position
		_last_respawn_time = now_sec
		spawn_position = respawn_target
		release()
		if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
			_rpc_respawn_block.rpc(respawn_target)
		else:
			_apply_respawn(respawn_target)
		return

	if Vector2(velocity.x, velocity.z).length() > 0.6 and is_on_floor():
		_dust_timer += delta
		if _dust_timer >= 0.18:
			_dust_timer = 0.0
			DUST_PUFF.spawn(get_parent(), global_position - Vector3(0, 0.35, 0), 2, 0.85)
	else:
		_dust_timer = 0.12

func _is_position_supported_on_permanent_floor(pos: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return false
	var offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-0.56, -0.56),
		Vector2(0.56, -0.56),
		Vector2(-0.56, 0.56),
		Vector2(0.56, 0.56),
	]
	var excl: Array[RID] = [get_rid()]
	for off in offsets:
		var ray_from := pos + Vector3(off.x, 0.4, off.y)
		var ray_to := pos + Vector3(off.x, -0.6, off.y)
		var rq := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		rq.collide_with_areas = false
		rq.collide_with_bodies = true
		rq.exclude = excl
		var hit: Dictionary = space_state.intersect_ray(rq)
		if hit.is_empty():
			return false
		var col_body: Object = hit["collider"]
		var hit_normal: Vector3 = hit["normal"]
		if not (col_body is StaticBody3D) or (col_body is PhasePlatform) or hit_normal.y <= 0.85:
			return false
	return true

@rpc("authority", "call_local", "reliable")
func _rpc_respawn_block(target_pos: Vector3) -> void:
	_apply_respawn(target_pos)

func _apply_respawn(target_pos: Vector3) -> void:
	if is_instance_valid(grabbed_by):
		remove_collision_exception_with(grabbed_by)
		if grabbed_by.grabbed_block == self:
			grabbed_by.grabbed_block = null
	grabbed_by = null
	velocity = Vector3.ZERO
	push_velocity = Vector3.ZERO
	global_position = target_pos + Vector3(0.0, 0.2, 0.0)
	if is_instance_valid(get_parent()):
		DUST_PUFF.spawn(get_parent(), global_position, 5, 1.1)
	if is_instance_valid(mesh_instance):
		mesh_instance.scale = Vector3(0.15, 0.15, 0.15)
		var tw := create_tween()
		tw.tween_property(mesh_instance, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
