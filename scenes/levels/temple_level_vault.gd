extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 3: Vault of Twin Moons (5-Section Co-op Scaled Astral Expedition)
## Mapped as index 2 in GameManager.exploration_levels.

const SPIKE_PIT_SCENE := preload("res://scenes/puzzles/spike_pit.tscn")

@onready var gate_chamber_2: AncientDoor = $Chamber1/GateToChamber2
@onready var sanctum_gate: AncientDoor = $Chamber2/SanctumGate
@onready var eclipse_gate: AncientDoor = $Chamber3/EclipseGate
@onready var observatory_gate: AncientDoor = $Chamber4/ObservatoryGate

@onready var plate_chamber_1: PressurePlate = $Chamber1/PlateChamber1
@onready var plate_west: PressurePlate = $Chamber2/PlateWest
@onready var plate_east: PressurePlate = $Chamber2/PlateEast

@onready var brazier_sun: Brazier = $Chamber3/BrazierSun
@onready var brazier_moon: Brazier = $Chamber3/BrazierMoon

@onready var gauntlet_lever_w: WallLever = $Chamber4/GauntletLeverW
@onready var gauntlet_lever_e: WallLever = $Chamber4/GauntletLeverE

var _world_phase: int = 0 # 0 = Sun, 1 = Moon
var _eclipse_braziers_lit: int = 0

func _ready() -> void:
	super._ready()
	register_room_checkpoint(10.0, -15.0, Vector3(0.0, 0.25, 4.5))
	register_room_checkpoint(-15.0, -31.0, Vector3(0.0, 0.25, -16.2))
	register_room_checkpoint(-31.0, -55.0, Vector3(0.0, 0.25, -32.2))
	register_room_checkpoint(-55.0, -75.0, Vector3(0.0, 0.25, -56.6))
	register_room_checkpoint(-75.0, -90.0, Vector3(0.0, 0.25, -77.0))
	_spawn_chasm_spike_pits()
	spawn_initial_players(get_configured_player_count(1))

	for node in get_tree().get_nodes_in_group("phase_obelisk"):
		if node is PhaseObelisk:
			node.phase_shifted.connect(_on_phase_shifted)

	for pl in [plate_chamber_1, plate_west, plate_east]:
		if is_instance_valid(pl):
			pl.state_changed.connect(func(_a): _refresh_objective())

	if is_instance_valid(brazier_sun):
		brazier_sun.lit_state_changed.connect(_on_eclipse_brazier_lit)
	if is_instance_valid(brazier_moon):
		brazier_moon.lit_state_changed.connect(_on_eclipse_brazier_lit)

	if is_instance_valid(gauntlet_lever_w):
		gauntlet_lever_w.toggled.connect(func(_s): _refresh_objective())
	if is_instance_valid(gauntlet_lever_e):
		gauntlet_lever_e.toggled.connect(func(_s): _refresh_objective())

	for g in [gate_chamber_2, sanctum_gate, eclipse_gate, observatory_gate]:
		if is_instance_valid(g):
			g.door_opened.connect(func(_d): _refresh_objective())
			g.door_closed.connect(func(_d): _refresh_objective())

	_refresh_objective()

	var scarab_spots: Array[Vector3] = [
		Vector3(3.0, 0.1, -5.0),
		Vector3(-5.8, 0.1, -29.2),
		Vector3(5.8, 0.1, -29.2),
		Vector3(5.0, 0.1, -42.5),
		Vector3(0.0, 0.1, -65.5),
	]
	spawn_scarabs(scarab_spots)

func _spawn_chasm_spike_pits() -> void:
	var specs := [
		{"pos": Vector3(0.0, 0.0, -5.0), "size": Vector2(14.0, 12.2)},
		{"pos": Vector3(0.0, 0.0, -42.5), "size": Vector2(16.0, 15.2)},
		{"pos": Vector3(0.0, 0.0, -65.0), "size": Vector2(16.0, 12.2)},
	]
	for spec in specs:
		var pit := SPIKE_PIT_SCENE.instantiate() as SpikePit
		pit.pit_size = spec["size"]
		pit.pit_depth = 2.4
		pit.position = spec["pos"]
		add_child(pit)

func on_difficulty_scaled(_party_size: int) -> void:
	_refresh_objective()

func _on_phase_shifted(new_phase: int) -> void:
	_world_phase = new_phase
	_refresh_objective()

func _on_eclipse_brazier_lit(is_lit: bool) -> void:
	if not is_lit:
		return
	_eclipse_braziers_lit += 1
	if is_instance_valid(eclipse_gate):
		eclipse_gate.register_trigger_activated()
	_refresh_objective()

func _refresh_objective() -> void:
	if not is_instance_valid(hud):
		return
	var phase_name := "SUN" if _world_phase == 0 else "MOON"
	if is_instance_valid(observatory_gate) and observatory_gate.is_open:
		hud.set_objective("Level 3 [Phase: %s]: Enter the astral portal to reach the Temple of the Golden Idol!" % phase_name)
	elif is_instance_valid(eclipse_gate) and eclipse_gate.is_open:
		hud.set_objective("Level 3 [Phase: %s]: Cross the Twin-Moon Gauntlet and pull both observatory levers!" % phase_name)
	elif is_instance_valid(sanctum_gate) and sanctum_gate.is_open:
		hud.set_objective("Level 3 [Phase: %s]: Shift phases across the chasm to ignite Sun & Moon braziers (%d/2)!" % [phase_name, _eclipse_braziers_lit])
	elif is_instance_valid(gate_chamber_2) and gate_chamber_2.is_open:
		var plates_lit := 0
		if is_instance_valid(plate_west) and plate_west.is_pressed:
			plates_lit += 1
		if is_instance_valid(plate_east) and plate_east.is_pressed:
			plates_lit += 1
		hud.set_objective("Level 3 [Phase: %s]: Unlock the Sun & Moon vaults and place both crates on the plates (%d/2)!" % [phase_name, plates_lit])
	else:
		hud.set_objective("Level 3 [Phase: %s]: Move the crate across the astral phase bridges onto the pressure plate!" % phase_name)
