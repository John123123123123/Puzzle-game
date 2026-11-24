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

func _ready() -> void:
	if is_instance_valid(player_spawn_1):
		latest_checkpoint_pos = player_spawn_1.global_position
	for door in get_tree().get_nodes_in_group("ancient_door"):
		if door.has_signal("door_opened"):
			door.door_opened.connect(_on_door_opened)
	if is_instance_valid(AudioManager):
		AudioManager.start_ambient_temple()
	if is_instance_valid(SettingsManager):
		SettingsManager.apply_environment()
	call_deferred("_announce_level_start")

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
	for pos in positions:
		var scarab := scarab_scene.instantiate() as Area3D
		add_child(scarab)
		scarab.global_position = pos
	if is_instance_valid(hud):
		hud.set_scarab_total(positions.size())

func get_configured_player_count(default_count: int = 1) -> int:
	if is_instance_valid(GameManager):
		return GameManager.player_count
	return default_count

func spawn_initial_players(count: int) -> void:
	var spawn_markers = [player_spawn_1, player_spawn_2, player_spawn_3, player_spawn_4]
	for i in range(count):
		var id = i + 1
		var pos = spawn_markers[i].global_position if i < spawn_markers.size() else player_spawn_1.global_position + Vector3(i * 1.0, 0, 0)
		spawn_player(id, pos)

func _unhandled_input(event: InputEvent) -> void:
	# Drop-in join during gameplay at latest unlocked gate / checkpoint
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
	player.player_id = id
	add_child(player)
	player.global_position = pos
	players[id] = player

	if coop_camera:
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

func _on_player_died(player: Player) -> void:
	_check_game_over()
	if is_game_over or level_complete or not _has_living_player():
		return
	# Respawn fallen co-op player at the latest unlocked gate after 5.5s if not revived on the spot
	await get_tree().create_timer(5.5).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if is_game_over or level_complete or not _has_living_player():
		return
	if is_instance_valid(player) and player.current_health <= 0:
		player.respawn_at(latest_checkpoint_pos + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)))

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
