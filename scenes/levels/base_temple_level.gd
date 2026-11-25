extends Node3D
class_name BaseTempleLevel

@onready var coop_camera: CoopCamera = $CoopCamera
@onready var hud: GameHUD = $HUD
@onready var player_spawn_1: Marker3D = $SpawnPoints/Spawn1
@onready var player_spawn_2: Marker3D = $SpawnPoints/Spawn2
@onready var player_spawn_3: Marker3D = $SpawnPoints/Spawn3
@onready var player_spawn_4: Marker3D = $SpawnPoints/Spawn4

var players: Dictionary = {}
var player_scene = preload("res://scenes/characters/player.tscn")
var scarab_scene = preload("res://scenes/puzzles/collectible_scarab.tscn")
var is_game_over: bool = false
var level_complete: bool = false
var latest_checkpoint_pos: Vector3 = Vector3.ZERO
var _world_sync_timer: float = 0.0
var _trap_clock: float = 0.0
var _trap_sync_timer: float = 0.0

func _ready() -> void:
	if is_instance_valid(player_spawn_1):
		latest_checkpoint_pos = player_spawn_1.global_position
	for door in get_tree().get_nodes_in_group("ancient_door"):
		if door.has_signal("door_opened"):
			door.door_opened.connect(_on_door_opened)
	if is_instance_valid(NetworkManager):
		NetworkManager.slot_joined_midgame.connect(_on_online_slot_joined)
		NetworkManager.slot_left_midgame.connect(_on_online_slot_left)
	if is_instance_valid(AudioManager):
		AudioManager.start_ambient_temple()
	if is_instance_valid(SettingsManager):
		SettingsManager.apply_environment()
	call_deferred("_announce_level_start")

func _process(delta: float) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_online or not NetworkManager.is_host:
		return
	_trap_clock += delta
	_world_sync_timer += delta
	if _world_sync_timer >= 0.05:
		_world_sync_timer = 0.0
		var paths: Array = []
		var positions: PackedVector3Array = PackedVector3Array()
		for b in get_tree().get_nodes_in_group("pushable"):
			if is_instance_valid(b) and b is Node3D:
				paths.append(get_path_to(b))
				positions.append(b.global_position)
		if not paths.is_empty():
			_rpc_sync_blocks.rpc(paths, positions)
	_trap_sync_timer += delta
	if _trap_sync_timer >= 0.10:
		_trap_sync_timer = 0.0
		var spinner_paths: Array = []
		var spinner_yaws: PackedFloat32Array = PackedFloat32Array()
		for sp in get_tree().get_nodes_in_group("flame_spinner"):
			if is_instance_valid(sp) and sp is Node3D and sp.has_method("sync_network_yaw"):
				var head: Node3D = sp.get("spinner_head") as Node3D
				if is_instance_valid(head):
					spinner_paths.append(get_path_to(sp))
					spinner_yaws.append(head.rotation.y)
		_rpc_sync_traps.rpc(_trap_clock, spinner_paths, spinner_yaws)

@rpc("authority", "unreliable_ordered")
func _rpc_sync_traps(host_clock: float, spinner_paths: Array, spinner_yaws: PackedFloat32Array) -> void:
	for st in get_tree().get_nodes_in_group("spike_trap"):
		if is_instance_valid(st) and st.has_method("sync_network_time"):
			st.sync_network_time(host_clock)
	for i in range(mini(spinner_paths.size(), spinner_yaws.size())):
		var sp := get_node_or_null(spinner_paths[i])
		if is_instance_valid(sp) and sp.has_method("sync_network_yaw"):
			sp.sync_network_yaw(spinner_yaws[i])

@rpc("authority", "unreliable_ordered")
func _rpc_sync_blocks(paths: Array, positions: PackedVector3Array) -> void:
	for i in range(mini(paths.size(), positions.size())):
		var node := get_node_or_null(paths[i]) as Node3D
		if is_instance_valid(node):
			if node is PushableBlock and is_instance_valid(node.grabbed_by) and node.grabbed_by.is_local_controlled():
				continue
			if node.global_position.distance_to(positions[i]) > 2.5:
				node.global_position = positions[i]
			else:
				node.global_position = node.global_position.lerp(positions[i], 0.45)

func _announce_level_start() -> void:
	if is_instance_valid(hud) and hud.has_method("show_chapter_banner"):
		var lvl_idx := GameManager.current_level_index if is_instance_valid(GameManager) else 1
		hud.show_chapter_banner(lvl_idx)

func _on_door_opened(door: Node3D) -> void:
	if is_instance_valid(door):
		latest_checkpoint_pos = door.global_position + Vector3(0.0, 0.1, 0.0)

## Virtual hook overridden by levels that scale door triggers on co-op drop-in.
func on_player_joined(_total_players: int) -> void:
	pass

## Virtual hook overridden by levels with custom difficulty scaling (e.g. boulder speed).
func on_difficulty_scaled(_party_size: int) -> void:
	pass

func apply_party_difficulty(party_size: int) -> void:
	var clamped_size := clampi(party_size, 1, 4)
	for grp in ["spike_trap", "dart_trap", "flame_spinner", "pressure_plate", "ancient_door"]:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and node.has_method("apply_coop_difficulty"):
				node.apply_coop_difficulty(clamped_size)
	if is_instance_valid(hud) and hud.has_method("set_party_difficulty"):
		hud.set_party_difficulty(clamped_size)
	on_difficulty_scaled(clamped_size)

func spawn_scarabs(positions: Array[Vector3]) -> void:
	for idx in range(positions.size()):
		var scarab := scarab_scene.instantiate() as Area3D
		scarab.name = "Scarab_%d" % idx
		add_child(scarab)
		scarab.global_position = positions[idx]
	if is_instance_valid(hud):
		hud.set_scarab_total(positions.size())

func get_configured_player_count(default_count: int = 1) -> int:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		return NetworkManager.get_online_player_count()
	if is_instance_valid(GameManager):
		return GameManager.player_count
	return default_count

func spawn_initial_players(count: int) -> void:
	var spawn_markers = [player_spawn_1, player_spawn_2, player_spawn_3, player_spawn_4]
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		var slots: Array = NetworkManager.slot_to_peer.keys()
		slots.sort()
		for slot_val in slots:
			var id := int(slot_val)
			var idx := clampi(id - 1, 0, 3)
			var pos = spawn_markers[idx].global_position if idx < spawn_markers.size() else player_spawn_1.global_position + Vector3(idx * 1.0, 0, 0)
			spawn_player(id, pos)
		return

	for i in range(count):
		var id = i + 1
		var pos = spawn_markers[i].global_position if i < spawn_markers.size() else player_spawn_1.global_position + Vector3(i * 1.0, 0, 0)
		spawn_player(id, pos)

func _on_online_slot_joined(slot_id: int, _peer_id: int) -> void:
	var pos := latest_checkpoint_pos + Vector3((slot_id - 1) * 0.6, 0.1, 0.6)
	if is_instance_valid(NetworkManager) and NetworkManager.is_host:
		_rpc_spawn_midgame_player.rpc(slot_id, pos)

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_midgame_player(slot_id: int, pos: Vector3) -> void:
	spawn_player(slot_id, pos)

func _on_online_slot_left(slot_id: int, _peer_id: int) -> void:
	if players.has(slot_id):
		var p: Player = players[slot_id]
		players.erase(slot_id)
		if is_instance_valid(p):
			if p.carried_item != null:
				p._do_drop_item(p.global_position)
			if is_instance_valid(p.grabbed_block):
				p.grabbed_block.release()
			if coop_camera:
				coop_camera.unregister_target(p)
			p.queue_free()
		apply_party_difficulty(maxi(1, players.size()))

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		return
	# Local Couch Drop-in join during gameplay at latest unlocked gate / checkpoint
	for id in range(1, 5):
		var prefix = "p%d_" % id
		if not players.has(id):
			if event.is_action_pressed(prefix + "interact") or event.is_action_pressed(prefix + "action"):
				var pos := latest_checkpoint_pos + Vector3((id - 1) * 0.6, 0.0, 0.6)
				spawn_player(id, pos)

func spawn_player(id: int, pos: Vector3) -> Player:
	if players.has(id):
		return players[id]

	var player = player_scene.instantiate() as Player
	player.name = "Player_%d" % id
	player.player_id = id
	add_child(player)
	player.global_position = pos
	players[id] = player

	if coop_camera and player.is_local_controlled():
		coop_camera.register_target(player)

	if hud:
		hud.register_player(id, player.current_health)
		player.health_changed.connect(func(new_h):
			hud.update_player_health(id, new_h)
			_check_game_over()
		)
		player.player_died.connect(_on_player_died)

	on_player_joined(players.size())
	apply_party_difficulty(players.size())
	return player

func _on_player_died(_player: Player) -> void:
	_check_game_over()
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	for exit_node in get_tree().get_nodes_in_group("level_exit"):
		if is_instance_valid(exit_node) and exit_node.has_method("_evaluate_coop_exit"):
			exit_node._evaluate_coop_exit()

func _has_living_player() -> bool:
	for id in players.keys():
		var p = players[id]
		if is_instance_valid(p) and p.current_health > 0:
			return true
	return false

func _check_game_over() -> void:
	if is_game_over or level_complete:
		return

	if players.is_empty():
		return

	for id in players.keys():
		var p = players[id]
		if is_instance_valid(p) and p.current_health > 0:
			return

	is_game_over = true
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if is_instance_valid(hud):
		hud.show_game_over()
