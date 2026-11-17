extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 1: The Dark Catacombs (Braziers, spikes, levers)
## Mapped as index 0 in GameManager.exploration_levels.

@onready var level_exit: LevelExit = $LevelExit

# Puzzles
@onready var brazier_1: Brazier = $Room1/Brazier1
@onready var brazier_2: Brazier = $Room1/Brazier2
@onready var brazier_3: Brazier = $Room1/Brazier3
@onready var gate_room1: AncientDoor = $Room1/GateToRoom2

@onready var lever_a: WallLever = $Room2/LeverA
@onready var lever_b: WallLever = $Room2/LeverB
@onready var gate_room2: AncientDoor = $Room2/GateToRoom3

var lit_braziers: int = 0

func _ready() -> void:
	super._ready()
	hud.set_objective("Level 1: Light the braziers (0/3) and navigate the catacombs!")
	spawn_initial_players(get_configured_player_count(1))

	# Connect Brazier puzzle
	brazier_1.lit_state_changed.connect(_on_brazier_lit)
	brazier_2.lit_state_changed.connect(_on_brazier_lit)
	brazier_3.lit_state_changed.connect(_on_brazier_lit)

	var scarab_spots: Array[Vector3] = []
	if is_instance_valid(brazier_2):
		scarab_spots.append(brazier_2.global_position + Vector3(1.8, 0.0, 0.0))
	if is_instance_valid(lever_a):
		scarab_spots.append(lever_a.global_position + Vector3(0.0, -1.0, 1.8))
	if is_instance_valid(gate_room2):
		scarab_spots.append(gate_room2.global_position + Vector3(-2.0, 0.0, 2.0))
	spawn_scarabs(scarab_spots)

func _on_brazier_lit(is_lit: bool) -> void:
	if is_lit:
		lit_braziers += 1
		if lit_braziers >= 3:
			hud.set_objective("Level 1: Gate unlocked! Pull the levers and reach the exit!")
			if gate_room1:
				gate_room1.register_trigger_activated()
		else:
			hud.set_objective("Level 1: Light the braziers (%d/3) and navigate the catacombs!" % lit_braziers)
