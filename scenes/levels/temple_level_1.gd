extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 3 (FINALE): Golden Idol Temple & Giant Boulder Escape
## Mapped as FINALE_LEVEL in GameManager.

@export var start_with_two_players: bool = false

@onready var golden_idol: GoldenIdol = $Room3/GoldenIdol
@onready var giant_boulder: GiantBoulder = $Room3/GiantBoulder
@onready var pedestal: StaticBody3D = $Room3/Pedestal
@onready var escape_zone: Area3D = $Architecture/EscapeZone
@onready var gate_room2: AncientDoor = $Room1/GateToRoom2
@onready var gate_room3: AncientDoor = $Room2/GateToRoom3

var is_escaping: bool = false

# Tracks which players have returned to spawn after grabbing the idol
var players_in_escape_zone: Dictionary = {}

func _ready() -> void:
	super._ready()
	var count = get_configured_player_count(2 if start_with_two_players else 1)

	# Single-player friendly: Gate 1 only requires 1 trigger when solo
	if count == 1 and is_instance_valid(gate_room2):
		gate_room2.required_triggers = 1

	if hud:
		var lvl_num = GameManager.current_level_index if is_instance_valid(GameManager) else 3
		if count == 1:
			hud.set_objective("Level %d (FINALE): Solve the temple riddles and find the mythical Golden Idol!" % lvl_num)
		else:
			hud.set_objective("Level %d (FINALE): Cooperate to venture deep into the temple to reach the Golden Idol!" % lvl_num)

	spawn_initial_players(count)

	if golden_idol:
		golden_idol.idol_taken.connect(_on_golden_idol_taken)

	if escape_zone:
		escape_zone.body_entered.connect(_on_escape_zone_entered)
		escape_zone.body_exited.connect(_on_escape_zone_exited)

	var scarab_spots: Array[Vector3] = []
	if is_instance_valid(gate_room2):
		scarab_spots.append(gate_room2.global_position + Vector3(-2.0, 0.0, 2.0))
	if is_instance_valid(gate_room3):
		scarab_spots.append(gate_room3.global_position + Vector3(2.0, 0.0, 2.0))
	if is_instance_valid(pedestal):
		scarab_spots.append(pedestal.global_position + Vector3(2.5, 0.0, 0.0))
	spawn_scarabs(scarab_spots)

# ---------------------------------------------------------------------------
# Golden Idol grab sequence
# ---------------------------------------------------------------------------

func _on_golden_idol_taken(_by_player: Player) -> void:
	if is_escaping:
		return
	is_escaping = true

	if players.size() <= 1:
		hud.set_objective("WARNING: TEMPLE COLLAPSE! Escape the boulder and run to the entrance!")
		hud.show_victory("THE GOLDEN IDOL IS YOURS!\nRUN TO THE ENTRANCE!")
	else:
		hud.set_objective("WARNING: TEMPLE COLLAPSE! All players run to the entrance!")
		hud.show_victory("THE GOLDEN IDOL IS YOURS!\nEVERYONE BACK TO THE ENTRANCE!")

	_sink_pedestal()
	_open_all_doors()
	_trigger_temple_rumble()

	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
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
	var all_doors = get_tree().get_nodes_in_group("ancient_door")
	for door in all_doors:
		if door is AncientDoor:
			door.force_open_permanent()

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

	var living_count: int = 0
	var safe_count: int = 0
	for id in players.keys():
		var player = players[id]
		if is_instance_valid(player) and player.current_health <= 0:
			continue
		living_count += 1
		if players_in_escape_zone.has(id):
			safe_count += 1

	if is_instance_valid(hud) and living_count > 0:
		hud.set_objective("ESCAPE! Run to the entrance! (%d/%d players safe)" % [safe_count, living_count])

	if safe_count < living_count:
		return

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
	if is_instance_valid(coop_camera):
		coop_camera.trigger_shake(0.18, 2.0)
