extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 4 (FINALE): Temple of the Golden Idol (5-Room Co-op Scaled Climax & Boulder Escape)
## Mapped as FINALE_LEVEL in GameManager.

@export var start_with_two_players: bool = false

@onready var golden_idol: GoldenIdol = $Room5/GoldenIdol
@onready var giant_boulder: GiantBoulder = $Room5/GiantBoulder
@onready var pedestal: StaticBody3D = $Room5/Pedestal
@onready var escape_zone: Area3D = $Architecture/EscapeZone

@onready var gate_room2: AncientDoor = $Room1/GateToRoom2
@onready var gate_room3: AncientDoor = $Room2/GateToRoom3
@onready var gate_room4: AncientDoor = $Room3/GateToRoom4
@onready var gate_room5: AncientDoor = $Room4/GateToRoom5

# Room 3 Pharaoh's Trial elements
@onready var trial_mirror_1: MirrorPillar = $Room3/TrialMirror1
@onready var trial_mirror_2: MirrorPillar = $Room3/TrialMirror2
@onready var trial_receiver: SunReceiver = $Room3/TrialSunReceiver
@onready var trial_brazier_1: Brazier = $Room3/TrialBrazier1
@onready var trial_brazier_2: Brazier = $Room3/TrialBrazier2

# Room 4 Anubis Judgment Hall levers
@onready var judgment_lever_l: WallLever = $Room4/JudgmentLeverL
@onready var judgment_lever_r: WallLever = $Room4/JudgmentLeverR

var is_escaping: bool = false
var _trial_braziers_lit: int = 0
var players_in_escape_zone: Dictionary = {}

func _ready() -> void:
	super._ready()
	var count = get_configured_player_count(2 if start_with_two_players else 1)
	spawn_initial_players(count)

	if is_instance_valid(trial_mirror_1):
		trial_mirror_1.rotated.connect(_evaluate_trial_mirrors)
	if is_instance_valid(trial_mirror_2):
		trial_mirror_2.rotated.connect(_evaluate_trial_mirrors)
	if is_instance_valid(trial_receiver):
		trial_receiver.power_changed.connect(func(_p): _refresh_objective())
	if is_instance_valid(trial_brazier_1):
		trial_brazier_1.lit_state_changed.connect(_on_trial_brazier_lit)
	if is_instance_valid(trial_brazier_2):
		trial_brazier_2.lit_state_changed.connect(_on_trial_brazier_lit)

	if is_instance_valid(judgment_lever_l):
		judgment_lever_l.toggled.connect(func(_s): _refresh_objective())
	if is_instance_valid(judgment_lever_r):
		judgment_lever_r.toggled.connect(func(_s): _refresh_objective())

	for g in [gate_room2, gate_room3, gate_room4, gate_room5]:
		if is_instance_valid(g):
			g.door_opened.connect(func(_d): _refresh_objective())

	_evaluate_trial_mirrors()
	_refresh_objective()

	if golden_idol:
		golden_idol.idol_taken.connect(_on_golden_idol_taken)

	if escape_zone:
		escape_zone.body_entered.connect(_on_escape_zone_entered)
		escape_zone.body_exited.connect(_on_escape_zone_exited)

	var scarab_spots: Array[Vector3] = [
		Vector3(-5.2, 0.1, -3.8),
		Vector3(2.8, 0.1, -18.5),
		Vector3(-6.4, 0.1, -35.5),
		Vector3(6.4, 0.1, -53.5),
		Vector3(4.5, 0.1, -62.0),
	]
	spawn_scarabs(scarab_spots)

func on_difficulty_scaled(party_size: int) -> void:
	# Scale Giant Boulder pursuit speed with party size (6.4 solo -> 7.6 at 4P)
	if is_instance_valid(giant_boulder):
		giant_boulder.roll_speed = 6.4 + 0.4 * float(maxi(0, party_size - 1))
	_refresh_objective()

func _physics_process(_delta: float) -> void:
	if (is_instance_valid(trial_mirror_1) and trial_mirror_1.is_turning) or (is_instance_valid(trial_mirror_2) and trial_mirror_2.is_turning):
		_evaluate_trial_mirrors()

func _evaluate_trial_mirrors(_angle: float = 0.0) -> void:
	var all_m: Array[MirrorPillar] = [trial_mirror_1, trial_mirror_2]
	var lit_m: Array[MirrorPillar] = []
	var powered_r: Array[SunReceiver] = []

	var current: MirrorPillar = trial_mirror_1
	while is_instance_valid(current) and not lit_m.has(current):
		lit_m.append(current)
		var trace := current.trace_beam(26.0)
		current.set_beam_active(true, trace["length"])
		if trace["hit_receiver"] is SunReceiver:
			powered_r.append(trace["hit_receiver"])
			current = null
		elif trace["hit_mirror"] is MirrorPillar:
			current = trace["hit_mirror"]
		else:
			current = null

	for m in all_m:
		if is_instance_valid(m) and not lit_m.has(m):
			m.set_beam_active(false)

	if is_instance_valid(trial_receiver):
		trial_receiver.set_powered(powered_r.has(trial_receiver))

func _on_trial_brazier_lit(is_lit: bool) -> void:
	if not is_lit:
		return
	_trial_braziers_lit += 1
	if is_instance_valid(gate_room4):
		gate_room4.register_trigger_activated()
	_refresh_objective()

func _refresh_objective() -> void:
	if is_escaping or not is_instance_valid(hud):
		return
	var lvl_num := GameManager.current_level_index if is_instance_valid(GameManager) else 4
	if is_instance_valid(gate_room5) and gate_room5.is_open:
		hud.set_objective("Level %d (FINALE): Claim the mythical Golden Idol of Ra!" % lvl_num)
	elif is_instance_valid(gate_room4) and gate_room4.is_open:
		hud.set_objective("Level %d (FINALE): Survive Anubis Judgment Hall and pull both levers!" % lvl_num)
	elif is_instance_valid(gate_room3) and gate_room3.is_open:
		var sun_txt := "1/1" if (is_instance_valid(trial_receiver) and trial_receiver.is_powered) else "0/1"
		hud.set_objective("Level %d (FINALE): Pharaoh's Trial — Charge Solar Crystal (%s) & Light Braziers (%d/2)!" % [lvl_num, sun_txt, _trial_braziers_lit])
	elif is_instance_valid(gate_room2) and gate_room2.is_open:
		hud.set_objective("Level %d (FINALE): Push the crate through the dart corridor onto the plate & pull the lever!" % lvl_num)
	else:
		hud.set_objective("Level %d (FINALE): Push both stone crates onto the two offering plates to begin the descent!" % lvl_num)

# ---------------------------------------------------------------------------
# Golden Idol grab sequence
# ---------------------------------------------------------------------------

func _on_golden_idol_taken(_by_player: Player) -> void:
	if is_escaping:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		if NetworkManager.is_host:
			_rpc_start_escape.rpc()
		return
	_begin_escape_sequence()

@rpc("authority", "call_local", "reliable")
func _rpc_start_escape() -> void:
	_begin_escape_sequence()

func _begin_escape_sequence() -> void:
	if is_escaping:
		return
	is_escaping = true

	if players.size() <= 1:
		hud.set_objective("WARNING: TEMPLE COLLAPSE! Outrun the giant boulder all the way to the entrance!")
		hud.show_victory("THE GOLDEN IDOL IS YOURS!\nRUN TO THE ENTRANCE!")
	else:
		hud.set_objective("WARNING: TEMPLE COLLAPSE! All %d explorers sprint back to the entrance!" % players.size())
		hud.show_victory("THE GOLDEN IDOL IS YOURS!\nEVERYONE BACK TO THE ENTRANCE!")

	_sink_pedestal()
	_open_all_doors()
	_trigger_temple_rumble()

	await get_tree().create_timer(1.8).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if is_instance_valid(giant_boulder):
		giant_boulder.trigger_roll()

func _sink_pedestal() -> void:
	if not is_instance_valid(pedestal):
		return
	var tween = create_tween()
	tween.tween_property(pedestal, "position:y", pedestal.position.y - 2.5, 1.4) \
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

	for d in [gate_room2, gate_room3, gate_room4, gate_room5]:
		if is_instance_valid(d):
			d.force_open_permanent()

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
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
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

	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_complete_finale.rpc()
	else:
		level_complete = true
		_show_level_complete()

@rpc("authority", "call_local", "reliable")
func _rpc_complete_finale() -> void:
	if level_complete:
		return
	level_complete = true
	_show_level_complete()

func _show_level_complete() -> void:
	var current_level = 4
	if is_instance_valid(GameManager):
		current_level = GameManager.current_level_index

	hud.show_level_complete(current_level)

func _trigger_temple_rumble() -> void:
	if is_instance_valid(coop_camera):
		coop_camera.trigger_shake(0.22, 2.4)
