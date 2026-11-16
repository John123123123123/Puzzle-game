extends Node3D

@onready var coop_camera: CoopCamera = $CoopCamera
@onready var hud: GameHUD = $HUD
@onready var level_exit: LevelExit = $LevelExit
@onready var player_spawn_1: Marker3D = $SpawnPoints/Spawn1
@onready var player_spawn_2: Marker3D = $SpawnPoints/Spawn2
@onready var player_spawn_3: Marker3D = $SpawnPoints/Spawn3
@onready var player_spawn_4: Marker3D = $SpawnPoints/Spawn4

# Puzzles
@onready var brazier_1: Brazier = $Room1/Brazier1
@onready var brazier_2: Brazier = $Room1/Brazier2
@onready var brazier_3: Brazier = $Room1/Brazier3
@onready var gate_room1: AncientDoor = $Room1/GateToRoom2

@onready var lever_a: WallLever = $Room2/LeverA
@onready var lever_b: WallLever = $Room2/LeverB
@onready var gate_room2: AncientDoor = $Room2/GateToRoom3

var players: Dictionary = {}
var player_scene = preload("res://scenes/characters/player.tscn")
var lit_braziers: int = 0
var is_game_over: bool = false
var level_complete: bool = false

func _ready() -> void:
	hud.set_objective("Nivå 1: Tänd eldfaten och ta er genom katakomberna!")

	# Spawn players based on GameManager
	var count = 1
	if is_instance_valid(GameManager):
		count = GameManager.player_count

	var spawn_markers = [player_spawn_1, player_spawn_2, player_spawn_3, player_spawn_4]
	for i in range(count):
		var id = i + 1
		var pos = spawn_markers[i].global_position if i < spawn_markers.size() else player_spawn_1.global_position + Vector3(i * 1.0, 0, 0)
		spawn_player(id, pos)

	# Connect Brazier puzzle
	brazier_1.lit_state_changed.connect(_on_brazier_lit)
	brazier_2.lit_state_changed.connect(_on_brazier_lit)
	brazier_3.lit_state_changed.connect(_on_brazier_lit)

func _on_brazier_lit(is_lit: bool) -> void:
	if is_lit:
		lit_braziers += 1
		if lit_braziers >= 3 and gate_room1:
			gate_room1.register_trigger_activated()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		return

	# Drop-in join
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
			return  # At least one player is still alive

	# All players have fallen!
	is_game_over = true
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(hud):
		hud.show_game_over()
