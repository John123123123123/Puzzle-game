extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 3: Vault of Twin Moons (Solar / Lunar Phase-Shifting Puzzle)
## Mapped as index 2 in GameManager.exploration_levels (between Chamber of Mirrors and The Golden Idol).

@onready var gate_chamber_2: AncientDoor = $Chamber1/GateToChamber2
@onready var sanctum_gate: AncientDoor = $Chamber2/SanctumGate
@onready var plate_chamber_1: PressurePlate = $Chamber1/PlateChamber1
@onready var plate_west: PressurePlate = $Chamber2/PlateWest
@onready var plate_east: PressurePlate = $Chamber2/PlateEast
@onready var obelisk_center: PhaseObelisk = $Chamber1/ObeliskCenter

var _world_phase: int = 0 # 0 = Sun, 1 = Moon

func _ready() -> void:
	super._ready()
	spawn_initial_players(get_configured_player_count(1))

	for node in get_tree().get_nodes_in_group("phase_obelisk"):
		if node is PhaseObelisk:
			node.phase_shifted.connect(_on_phase_shifted)

	if is_instance_valid(plate_chamber_1):
		plate_chamber_1.state_changed.connect(func(_a): _refresh_objective())
	if is_instance_valid(plate_west):
		plate_west.state_changed.connect(func(_a): _refresh_objective())
	if is_instance_valid(plate_east):
		plate_east.state_changed.connect(func(_a): _refresh_objective())
	if is_instance_valid(gate_chamber_2):
		gate_chamber_2.door_opened.connect(func(_d): _refresh_objective())
	if is_instance_valid(sanctum_gate):
		sanctum_gate.door_opened.connect(func(_d): _refresh_objective())

	_refresh_objective()

	var scarab_spots: Array[Vector3] = [
		Vector3(3.0, 0.1, -5.0),
		Vector3(-5.8, 0.1, -29.2),
		Vector3(5.8, 0.1, -29.2),
	]
	spawn_scarabs(scarab_spots)

func _on_phase_shifted(new_phase: int) -> void:
	_world_phase = new_phase
	_refresh_objective()

func _refresh_objective() -> void:
	if not is_instance_valid(hud):
		return
	var phase_name := "SUN" if _world_phase == 0 else "MOON"
	if is_instance_valid(sanctum_gate) and sanctum_gate.is_open:
		hud.set_objective("Level 3 [Phase: %s]: Enter the astral portal to reach the Temple of the Golden Idol!" % phase_name)
	elif is_instance_valid(gate_chamber_2) and gate_chamber_2.is_open:
		var plates_lit := 0
		if is_instance_valid(plate_west) and plate_west.is_pressed:
			plates_lit += 1
		if is_instance_valid(plate_east) and plate_east.is_pressed:
			plates_lit += 1
		hud.set_objective("Level 3 [Phase: %s]: Shift Sun/Moon gates to retrieve both relics (%d/2 seals)!" % [phase_name, plates_lit])
	else:
		hud.set_objective("Level 3 [Phase: %s]: Strike the Celestial Obelisks to shift bridges across the chasm!" % phase_name)
