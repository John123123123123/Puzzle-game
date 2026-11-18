extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 5: The Shifting Causeway (Introduces SlidingBridge over chasms)

const BRIDGE_SCRIPT := preload("res://scenes/puzzles/sliding_bridge.gd")
const CRATE_SCENE := preload("res://scenes/puzzles/pushable_block.tscn")
const PLATE_SCENE := preload("res://scenes/puzzles/pressure_plate.tscn")
const LEVER_SCENE := preload("res://scenes/puzzles/wall_lever.tscn")
const TORCH_SCENE := preload("res://scenes/puzzles/torch.tscn")
const BRAZIER_SCENE := preload("res://scenes/puzzles/brazier.tscn")
const DOOR_SCENE := preload("res://scenes/puzzles/ancient_door.tscn")
const EXIT_SCENE := preload("res://scenes/puzzles/level_exit.tscn")

func _ready() -> void:
	super._ready()
	hud.set_objective("Level 5: Extend the sliding stone bridges to carry fire to the exit!")
	_build_level()
	spawn_initial_players(get_configured_player_count(1))

	var scarabs: Array[Vector3] = [
		Vector3(4.0, 0.2, 8.0),
		Vector3(-3.5, 0.2, -2.0),
		Vector3(3.5, 0.2, -13.0),
	]
	spawn_scarabs(scarabs)

func _build_level() -> void:
	# Island A (Start + Crate + Plate A)
	build_floor(Vector3(0.0, -0.1, 10.0), Vector3(12.0, 0.2, 8.0))
	build_light(Vector3(0.0, 4.5, 10.0), Color(1.0, 0.82, 0.5), 1.8, 14.0)
	spawn_prop(CRATE_SCENE, Vector3(-3.5, 0.0, 9.0))

	# Bridge 1 (Auto-cycling timed bridge)
	var b1 := AnimatableBody3D.new()
	b1.set_script(BRIDGE_SCRIPT)
	b1.position = Vector3(0.0, -0.1, 4.0)
	b1.bridge_size = Vector3(2.8, 0.35, 4.2)
	b1.auto_cycle = true
	b1.start_extended = true
	add_child(b1)

	# Island B (Lever for Bridge 3)
	build_floor(Vector3(0.0, -0.1, -2.0), Vector3(10.0, 0.2, 8.0))
	build_light(Vector3(0.0, 4.5, -2.0), Color(1.0, 0.82, 0.5), 1.8, 14.0)

	# Bridge 2 (Held extended by Plate A on Island A)
	var b2 := AnimatableBody3D.new()
	b2.set_script(BRIDGE_SCRIPT)
	b2.position = Vector3(0.0, -0.1, -8.0)
	b2.bridge_size = Vector3(2.8, 0.35, 4.2)
	b2.auto_cycle = false
	b2.start_extended = false
	add_child(b2)

	var plate_a := spawn_prop(PLATE_SCENE, Vector3(0.0, 0.0, 7.5)) as PressurePlate
	plate_a.linked_targets = [b2.get_path()]

	# Island C (Torch + Scarab 3)
	build_floor(Vector3(0.0, -0.1, -13.5), Vector3(10.0, 0.2, 7.0))
	build_light(Vector3(0.0, 4.5, -13.5), Color(1.0, 0.82, 0.5), 1.8, 14.0)
	spawn_prop(TORCH_SCENE, Vector3(-2.5, 0.0, -13.5))

	# Bridge 3 (Controlled by WallLever on Island B)
	var b3 := AnimatableBody3D.new()
	b3.set_script(BRIDGE_SCRIPT)
	b3.position = Vector3(7.5, -0.1, -13.5)
	b3.bridge_size = Vector3(5.2, 0.35, 2.8)
	b3.auto_cycle = false
	b3.start_extended = false
	add_child(b3)

	var lever := spawn_prop(LEVER_SCENE, Vector3(4.0, 0.0, -2.0), -90.0) as WallLever
	lever.linked_targets = [b3.get_path()]

	# Island D (Final Brazier + Door + Exit)
	build_floor(Vector3(15.0, -0.1, -13.5), Vector3(10.0, 0.2, 10.0))
	build_light(Vector3(15.0, 4.5, -13.5), Color(1.0, 0.85, 0.55), 2.0, 14.0)

	var door := spawn_prop(DOOR_SCENE, Vector3(15.0, 0.0, -15.0)) as AncientDoor
	door.required_triggers = 1

	var brazier := spawn_prop(BRAZIER_SCENE, Vector3(12.5, 0.0, -12.0)) as Brazier
	brazier.linked_targets = [door.get_path()]

	spawn_prop(EXIT_SCENE, Vector3(15.0, 0.0, -17.0))
