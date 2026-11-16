extends Node3D

@export var start_with_two_players: bool = false

@onready var coop_camera: CoopCamera = $CoopCamera
@onready var hud: GameHUD = $HUD
@onready var golden_idol: GoldenIdol = $Room3/GoldenIdol
@onready var giant_boulder: GiantBoulder = $Room3/GiantBoulder
@onready var pedestal: StaticBody3D = $Room3/Pedestal
@onready var escape_zone: Area3D = $Architecture/EscapeZone
@onready var gate_room2: AncientDoor = $Room1/GateToRoom2
@onready var gate_room3: AncientDoor = $Room2/GateToRoom3
@onready var player_spawn_1: Marker3D = $SpawnPoints/Spawn1
@onready var player_spawn_2: Marker3D = $SpawnPoints/Spawn2
@onready var player_spawn_3: Marker3D = $SpawnPoints/Spawn3
@onready var player_spawn_4: Marker3D = $SpawnPoints/Spawn4

var players: Dictionary = {}
var player_scene = preload("res://scenes/characters/player.tscn")

var is_escaping: bool = false
var level_complete: bool = false
var is_game_over: bool = false

# Tracks which players have returned to spawn after grabbing the idol
var players_in_escape_zone: Dictionary = {}

func _ready() -> void:
	# Determine how many players to spawn from GameManager
	var count = 1
	if is_instance_valid(GameManager):
		count = GameManager.player_count
	elif start_with_two_players:
		count = 2

	# Single-player friendly: Gate 1 only requires 1 trigger when solo
	if count == 1 and is_instance_valid(gate_room2):
		gate_room2.required_triggers = 1

	if hud:
		var lvl_num = GameManager.current_level_index if is_instance_valid(GameManager) else 3
		if count == 1:
			hud.set_objective("Level %d (FINALE): Solve the temple riddles and find the mythical Golden Idol!" % lvl_num)
		else:
			hud.set_objective("Level %d (FINALE): Cooperate to venture deep into the temple to reach the Golden Idol!" % lvl_num)

	var spawn_markers = [player_spawn_1, player_spawn_2, player_spawn_3, player_spawn_4]
	for i in range(count):
		var id = i + 1
		var pos = spawn_markers[i].global_position if i < spawn_markers.size() else player_spawn_1.global_position + Vector3(i * 1.0, 0, 0)
		spawn_player(id, pos)

	if golden_idol:
		golden_idol.idol_taken.connect(_on_golden_idol_taken)

	if escape_zone:
		escape_zone.body_entered.connect(_on_escape_zone_entered)
		escape_zone.body_exited.connect(_on_escape_zone_exited)

func _unhandled_input(event: InputEvent) -> void:
	# Return to menu on Escape / ui_cancel
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return

	# Check for additional players joining dynamically during gameplay
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

# ---------------------------------------------------------------------------
# Golden Idol grab sequence
# ---------------------------------------------------------------------------

func _on_golden_idol_taken(by_player: Player) -> void:
	if is_escaping:
		return
	is_escaping = true

	if players.size() <= 1:
		hud.set_objective("WARNING: TEMPLE COLLAPSE! Escape the boulder and run to the entrance!")
		hud.show_victory("THE GOLDEN IDOL IS YOURS!\nRUN TO THE ENTRANCE!")
	else:
		hud.set_objective("WARNING: TEMPLE COLLAPSE! All players run to the entrance!")
		hud.show_victory("THE GOLDEN IDOL IS YOURS!\nEVERYONE BACK TO THE ENTRANCE!")

	# 1. Sink the pedestal into the ground
	_sink_pedestal()

	# 2. Open ALL doors permanently
	_open_all_doors()

	# 3. Temple rumble
	_trigger_temple_rumble()

	# 4. After a dramatic pause, reveal and release the boulder
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(giant_boulder):
		giant_boulder.trigger_roll()

func _sink_pedestal() -> void:
	if not is_instance_valid(pedestal):
		return
	var tween = create_tween()
	tween.tween_property(pedestal, "position:y", pedestal.position.y - 2.5, 1.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		var col = pedestal.get_node_or_null("CollisionShape3D")
		if col:
			col.set_deferred("disabled", true)
	)

func _open_all_doors() -> void:
	# Collect every AncientDoor in the scene and permanently open it
	var all_doors = get_tree().get_nodes_in_group("ancient_door")
	for door in all_doors:
		if door is AncientDoor:
			door.force_open_permanent()

	# Also directly open the two named gates (safe even if already in group)
	if is_instance_valid(gate_room2):
		gate_room2.force_open_permanent()
	if is_instance_valid(gate_room3):
		gate_room3.force_open_permanent()

# ---------------------------------------------------------------------------
# Escape zone — track ALL spawned players returning to spawn
# ---------------------------------------------------------------------------

func _on_escape_zone_entered(body: Node3D) -> void:
	if not is_escaping or level_complete:
		return
	if not (body is Player):
		return

	players_in_escape_zone[body.player_id] = true
	_check_all_players_escaped()

func _on_escape_zone_exited(body: Node3D) -> void:
	if not (body is Player):
		return
	players_in_escape_zone.erase(body.player_id)

func _check_all_players_escaped() -> void:
	if level_complete:
		return

	# Every living player must be inside the escape zone
	for id in players.keys():
		var player = players[id]
		# Skip dead players (they can't walk back)
		if is_instance_valid(player) and player.current_health <= 0:
			continue
		if not players_in_escape_zone.has(id):
			return  # At least one living player is still out

	# All living players are in the zone!
	level_complete = true
	_show_level_complete()

func _show_level_complete() -> void:
	var current_level = 1
	if is_instance_valid(GameManager):
		current_level = GameManager.current_level_index

	hud.show_level_complete(current_level)

# ---------------------------------------------------------------------------
# Camera rumble helper
# ---------------------------------------------------------------------------

func _trigger_temple_rumble() -> void:
	var initial_y = coop_camera.position.y
	var tween = create_tween().set_loops(16)
	tween.tween_property(coop_camera, "position:y", initial_y + 0.18, 0.05)
	tween.tween_property(coop_camera, "position:y", initial_y - 0.18, 0.05)
	tween.tween_property(coop_camera, "position:y", initial_y, 0.05)
