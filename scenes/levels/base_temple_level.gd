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

func _ready() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.start_ambient_temple()
	if is_instance_valid(SettingsManager):
		SettingsManager.apply_environment()

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
	# Drop-in join during gameplay
	for id in range(1, 5):
		var prefix = "p%d_" % id
		if not players.has(id):
			if event.is_action_pressed(prefix + "interact") or event.is_action_pressed(prefix + "action"):
				var sp = get_node_or_null("SpawnPoints/Spawn%d" % id)
				var pos = sp.global_position if sp else player_spawn_1.global_position + Vector3(id * 1.0, 0, 0)
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
		player.player_died.connect(func(_p): _check_game_over())

	return player

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
