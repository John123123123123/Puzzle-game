extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 1: The Dark Catacombs (5-Chamber Co-op Scaled Expedition)
## Mapped as index 0 in GameManager.exploration_levels.

@onready var level_exit: LevelExit = $LevelExit

# Chamber 1: Torchlight Antechamber
@onready var brazier_1: Brazier = $Room1/Brazier1
@onready var brazier_2: Brazier = $Room1/Brazier2
@onready var brazier_3: Brazier = $Room1/Brazier3
@onready var gate_room1: AncientDoor = $Room1/GateToRoom2

# Chamber 2: Gauntlet of Blades & Darts
@onready var lever_a: WallLever = $Room2/LeverA
@onready var lever_b: WallLever = $Room2/LeverB
@onready var gate_room2: AncientDoor = $Room2/GateToRoom3

# Chamber 3: Sunken Ossuary Vault
@onready var brazier_4: Brazier = $Room3/Brazier4
@onready var brazier_5: Brazier = $Room3/Brazier5
@onready var vault_plate: PressurePlate = $Room3/VaultPlate
@onready var gate_room3: AncientDoor = $Room3/GateToRoom4

# Chamber 4: The Catacomb Crucible (Levers + 1-4P Co-op Guardian Seals)
@onready var crucible_lever_l: WallLever = $Room4/CrucibleLeverL
@onready var crucible_lever_r: WallLever = $Room4/CrucibleLeverR
@onready var gate_room4: AncientDoor = $Room4/GateToRoom5

var lit_entry_braziers: int = 0
var lit_vault_braziers: int = 0

func _ready() -> void:
	super._ready()
	hud.show_controls_hint()
	spawn_initial_players(get_configured_player_count(1))

	brazier_1.lit_state_changed.connect(_on_entry_brazier_lit)
	brazier_2.lit_state_changed.connect(_on_entry_brazier_lit)
	brazier_3.lit_state_changed.connect(_on_entry_brazier_lit)

	for gate in [gate_room1, gate_room2, gate_room3, gate_room4]:
		if is_instance_valid(gate):
			gate.door_opened.connect(func(_d): _refresh_objective())

	if is_instance_valid(brazier_4):
		brazier_4.lit_state_changed.connect(_on_vault_brazier_lit)
	if is_instance_valid(brazier_5):
		brazier_5.lit_state_changed.connect(_on_vault_brazier_lit)
	if is_instance_valid(vault_plate):
		vault_plate.state_changed.connect(func(_p): _refresh_objective())
	if is_instance_valid(crucible_lever_l):
		crucible_lever_l.toggled.connect(func(_s): _refresh_objective())
	if is_instance_valid(crucible_lever_r):
		crucible_lever_r.toggled.connect(func(_s): _refresh_objective())

	_refresh_objective()

	var scarab_spots: Array[Vector3] = [
		Vector3(6.2, 0.1, -4.8),
		Vector3(-4.2, 0.1, -11.5),
		Vector3(6.2, 0.1, -38.5),
		Vector3(-6.4, 0.1, -55.0),
		Vector3(0.0, 0.1, -63.5),
	]
	spawn_scarabs(scarab_spots)

func on_difficulty_scaled(_party_size: int) -> void:
	_refresh_objective()

func _on_entry_brazier_lit(is_lit: bool) -> void:
	if not is_lit:
		return
	lit_entry_braziers += 1
	if lit_entry_braziers == 3 and is_instance_valid(gate_room1):
		gate_room1.register_trigger_activated()
	_refresh_objective()

func _on_vault_brazier_lit(is_lit: bool) -> void:
	if not is_lit:
		return
	lit_vault_braziers += 1
	if is_instance_valid(gate_room3):
		gate_room3.register_trigger_activated()
	_refresh_objective()

func _refresh_objective() -> void:
	if not is_instance_valid(hud):
		return
	var p_cnt := maxi(1, players.size())
	if is_instance_valid(gate_room4) and gate_room4.is_open:
		hud.set_objective("Level 1: The Catacomb Crucible is conquered! Enter the portal ahead!")
	elif is_instance_valid(gate_room3) and gate_room3.is_open:
		if p_cnt >= 2:
			hud.set_objective("Level 1: Pull both Crucible levers and stand on all %d Guardian Seals together!" % p_cnt)
		else:
			hud.set_objective("Level 1: Pull both Crucible levers and step onto the Guardian Seal!")
	elif is_instance_valid(gate_room2) and gate_room2.is_open:
		var plate_txt := "1/1" if (is_instance_valid(vault_plate) and vault_plate.is_pressed) else "0/1"
		hud.set_objective("Level 1: Light the Ossuary braziers (%d/2) and weigh down the crypt seal (%s)!" % [lit_vault_braziers, plate_txt])
	elif is_instance_valid(gate_room1) and gate_room1.is_open:
		hud.set_objective("Level 1: Use the shield crate and pull both corridor levers to breach the Ossuary!")
	elif lit_entry_braziers >= 3:
		hud.set_objective("Level 1: Braziers lit! All %d explorers stand on the threshold Guardian Seals!" % p_cnt)
	else:
		hud.set_objective("Level 1: Light the 3 antechamber braziers (%d/3) to awaken the threshold seals!" % lit_entry_braziers)
