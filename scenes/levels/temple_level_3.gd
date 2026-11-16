extends Node3D

@onready var coop_camera: CoopCamera = $CoopCamera
@onready var hud: GameHUD = $HUD
@onready var level_exit: LevelExit = $LevelExit
@onready var player_spawn_1: Marker3D = $SpawnPoints/Spawn1
@onready var player_spawn_2: Marker3D = $SpawnPoints/Spawn2
@onready var player_spawn_3: Marker3D = $SpawnPoints/Spawn3
@onready var player_spawn_4: Marker3D = $SpawnPoints/Spawn4

# Mirror & Light Beam elements
@onready var mirror_1: MirrorPillar = $Chamber/Mirror1
@onready var mirror_2: MirrorPillar = $Chamber/Mirror2
@onready var sun_receiver: SunReceiver = $Chamber/SunReceiver
@onready var pharaoh_gate: AncientDoor = $Chamber/PharaohGate

# Co-op plates
@onready var plate_1: PressurePlate = $Chamber/Plate1
@onready var plate_2: PressurePlate = $Chamber/Plate2
@onready var plate_3: PressurePlate = $Chamber/Plate3
@onready var plate_4: PressurePlate = $Chamber/Plate4

var players: Dictionary = {}
var player_scene = preload("res://scenes/characters/player.tscn")
var is_game_over: bool = false
var level_complete: bool = false

func _ready() -> void:
	hud.set_objective("Level 2: Direct the sunbeam through the mirrors to break the seal!")

	var count = 1
	if is_instance_valid(GameManager):
		count = GameManager.player_count

	var spawn_markers = [player_spawn_1, player_spawn_2, player_spawn_3, player_spawn_4]
	for i in range(count):
		var id = i + 1
		var pos = spawn_markers[i].global_position if i < spawn_markers.size() else player_spawn_1.global_position + Vector3(i * 1.0, 0, 0)
		spawn_player(id, pos)

	# Initial light beam check
	mirror_1.rotated.connect(_evaluate_mirrors)
	mirror_2.rotated.connect(_evaluate_mirrors)
	_evaluate_mirrors()

func _evaluate_mirrors(_angle: float = 0.0) -> void:
	# Mirror 1 receives direct skylight beam from above.
	# If Mirror 1 is facing East (step 1 = 90°), beam reaches Mirror 2 (8.0m away)!
	if mirror_1.current_step == 1:
		mirror_1.set_beam_active(true, 8.0)
		# Mirror 2 is illuminated!
		if mirror_2.current_step == 0:
			# Facing North -> strikes SunReceiver on the north wall!
			mirror_2.set_beam_active(true, 8.5)
			sun_receiver.set_powered(true)
		elif mirror_2.current_step == 1:
			# Facing East -> right wall (5.0m away)
			mirror_2.set_beam_active(true, 5.0)
			sun_receiver.set_powered(false)
		elif mirror_2.current_step == 2:
			# Facing South -> entrance/back wall (9.0m away)
			mirror_2.set_beam_active(true, 9.0)
			sun_receiver.set_powered(false)
		elif mirror_2.current_step == 3:
			# Facing West -> reflects back toward Mirror 1 (8.0m away)
			mirror_2.set_beam_active(true, 8.0)
			sun_receiver.set_powered(false)
	else:
		# Mirror 1 is not aimed at Mirror 2; beam strikes wall based on direction
		if mirror_1.current_step == 0:
			# North -> strikes partition wall (9.0m away)
			mirror_1.set_beam_active(true, 9.0)
		elif mirror_1.current_step == 2:
			# South -> strikes back wall (9.0m away)
			mirror_1.set_beam_active(true, 9.0)
		elif mirror_1.current_step == 3:
			# West -> strikes left wall (5.0m away)
			mirror_1.set_beam_active(true, 5.0)

		mirror_2.set_beam_active(false)
		sun_receiver.set_powered(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		return

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
