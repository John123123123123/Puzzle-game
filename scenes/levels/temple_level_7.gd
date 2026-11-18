extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 6: The Twin-Weight Sanctum (Introduces HeavyPressurePlate requiring 2 weight units)

const HEAVY_PLATE_SCRIPT := preload("res://scenes/puzzles/heavy_pressure_plate.gd")
const WHIP_HOOK_SCRIPT := preload("res://scenes/puzzles/whip_hook.gd")
const CRATE_SCENE := preload("res://scenes/puzzles/pushable_block.tscn")
const MIRROR_SCENE := preload("res://scenes/puzzles/mirror_pillar.tscn")
const RECEIVER_SCENE := preload("res://scenes/puzzles/sun_receiver.tscn")
const SPIKE_SCENE := preload("res://scenes/puzzles/spike_trap.tscn")
const DOOR_SCENE := preload("res://scenes/puzzles/ancient_door.tscn")
const EXIT_SCENE := preload("res://scenes/puzzles/level_exit.tscn")

var _mirror_1: MirrorPillar
var _mirror_2: MirrorPillar
var _sun_receiver: SunReceiver

func _ready() -> void:
	super._ready()
	hud.set_objective("Level 6: Weigh down the heavy twin-rune plates (2/2) to unlock the sanctum!")
	_build_level()
	spawn_initial_players(get_configured_player_count(1))

	if _mirror_1 and _mirror_2:
		_mirror_1.rotated.connect(_evaluate_mirrors)
		_mirror_2.rotated.connect(_evaluate_mirrors)
		_evaluate_mirrors()

	var scarabs: Array[Vector3] = [
		Vector3(-17.5, 0.2, 2.0),
		Vector3(11.0, 0.2, -7.5),
		Vector3(0.0, 0.2, -2.0),
	]
	spawn_scarabs(scarabs)

func _build_level() -> void:
	# Tutorial Entry Room
	build_floor(Vector3(0.0, -0.1, 11.0), Vector3(12.0, 0.2, 9.0))
	build_wall(Vector3(-6.2, 2.0, 11.0), Vector3(0.5, 4.0, 9.0))
	build_wall(Vector3(6.2, 2.0, 11.0), Vector3(0.5, 4.0, 9.0))
	build_wall(Vector3(0.0, 2.0, 15.7), Vector3(12.8, 4.0, 0.5))
	build_wall(Vector3(-4.0, 2.0, 6.2), Vector3(4.5, 4.0, 0.5))
	build_wall(Vector3(4.0, 2.0, 6.2), Vector3(4.5, 4.0, 0.5))
	build_light(Vector3(0.0, 4.5, 11.0), Color(1.0, 0.85, 0.5), 1.8, 14.0)

	var gate_a := spawn_prop(DOOR_SCENE, Vector3(0.0, 0.0, 6.2)) as AncientDoor
	gate_a.required_triggers = 1

	spawn_prop(CRATE_SCENE, Vector3(-3.5, 0.0, 10.5))
	var plate_a := Node3D.new()
	plate_a.set_script(HEAVY_PLATE_SCRIPT)
	plate_a.position = Vector3(0.0, 0.0, 8.8)
	plate_a.stay_pressed = true
	plate_a.linked_targets = [gate_a.get_path()]
	add_child(plate_a)

	# Main Sanctum
	build_floor(Vector3(0.0, -0.1, -2.0), Vector3(24.0, 0.2, 16.0))
	build_wall(Vector3(0.0, 2.0, -10.2), Vector3(8.0, 4.0, 0.5))
	build_light(Vector3(0.0, 5.5, -2.0), Color(1.0, 0.88, 0.55), 2.2, 18.0)

	# Center Spike guarding Scarab 3
	spawn_prop(SPIKE_SCENE, Vector3(0.0, 0.0, -2.0))

	# Left Island (WhipHook to Crate 1)
	var hook_l := Node3D.new()
	hook_l.set_script(WHIP_HOOK_SCRIPT)
	hook_l.position = Vector3(-13.5, 0.0, -1.0)
	add_child(hook_l)
	build_floor(Vector3(-18.0, -0.1, -1.0), Vector3(7.0, 0.2, 7.0))
	build_light(Vector3(-18.0, 4.5, -1.0), Color(1.0, 0.85, 0.5), 1.6, 12.0)
	spawn_prop(CRATE_SCENE, Vector3(-18.0, 0.0, -1.0))

	# Right Wing (Mirror puzzle -> opens Crate 2 cage)
	_mirror_1 = spawn_prop(MIRROR_SCENE, Vector3(8.5, 0.0, 2.0), 180.0) as MirrorPillar
	_mirror_2 = spawn_prop(MIRROR_SCENE, Vector3(8.5, 0.0, -6.0), -90.0) as MirrorPillar

	var crate_gate := spawn_prop(DOOR_SCENE, Vector3(4.5, 0.0, -6.0), 90.0) as AncientDoor
	crate_gate.required_triggers = 1
	_sun_receiver = spawn_prop(RECEIVER_SCENE, Vector3(11.0, 0.0, -6.0), -90.0) as SunReceiver
	_sun_receiver.linked_targets = [crate_gate.get_path()]
	spawn_prop(CRATE_SCENE, Vector3(2.5, 0.0, -6.0))

	# Final Heavy Plate C -> Exit Door
	var final_door := spawn_prop(DOOR_SCENE, Vector3(0.0, 0.0, -10.2)) as AncientDoor
	final_door.required_triggers = 1

	var plate_c := Node3D.new()
	plate_c.set_script(HEAVY_PLATE_SCRIPT)
	plate_c.position = Vector3(0.0, 0.0, -7.8)
	plate_c.linked_targets = [final_door.get_path()]
	add_child(plate_c)

	# Exit Room
	build_floor(Vector3(0.0, -0.1, -15.0), Vector3(8.0, 0.2, 9.0))
	build_wall(Vector3(-4.2, 2.0, -15.0), Vector3(0.5, 4.0, 9.0))
	build_wall(Vector3(4.2, 2.0, -15.0), Vector3(0.5, 4.0, 9.0))
	build_wall(Vector3(0.0, 2.0, -19.7), Vector3(8.8, 4.0, 0.5))
	build_light(Vector3(0.0, 4.5, -15.0), Color(1.0, 0.85, 0.5), 1.8, 12.0)
	spawn_prop(EXIT_SCENE, Vector3(0.0, 0.0, -16.5))

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	if (_mirror_1 and _mirror_1.is_turning) or (_mirror_2 and _mirror_2.is_turning):
		_evaluate_mirrors()

func _evaluate_mirrors(_angle: float = 0.0) -> void:
	if not is_instance_valid(_mirror_1) or not is_instance_valid(_mirror_2):
		return
	var all_mirrors: Array = [_mirror_1, _mirror_2]
	var lit: Array[MirrorPillar] = []
	var powered := false

	var cur: MirrorPillar = _mirror_1
	while is_instance_valid(cur) and not lit.has(cur):
		lit.append(cur)
		var trace := cur.trace_beam(28.0)
		cur.set_beam_active(true, trace["length"])
		if trace["hit_receiver"] == _sun_receiver:
			powered = true
			cur = null
		elif trace["hit_mirror"] is MirrorPillar:
			cur = trace["hit_mirror"]
		else:
			cur = null

	for m in all_mirrors:
		if is_instance_valid(m) and not lit.has(m):
			m.set_beam_active(false)

	if is_instance_valid(_sun_receiver):
		_sun_receiver.set_powered(powered)
