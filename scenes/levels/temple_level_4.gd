extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 3: The Chasm of Hooks (Introduces WhipHook swinging)

const WHIP_HOOK_SCRIPT := preload("res://scenes/puzzles/whip_hook.gd")
const MIRROR_SCENE := preload("res://scenes/puzzles/mirror_pillar.tscn")
const RECEIVER_SCENE := preload("res://scenes/puzzles/sun_receiver.tscn")
const DOOR_SCENE := preload("res://scenes/puzzles/ancient_door.tscn")
const EXIT_SCENE := preload("res://scenes/puzzles/level_exit.tscn")
const PILLAR_SCENE := preload("res://scenes/props/temple_pillar.tscn")
const SPIKE_SCENE := preload("res://scenes/puzzles/spike_trap.tscn")

var _mirror_1: MirrorPillar
var _mirror_2: MirrorPillar
var _sun_receiver: SunReceiver

func _ready() -> void:
	super._ready()
	hud.set_objective("Level 3: Whip the golden rings to swing across the chasm and align the sunbeam!")
	_build_level()
	spawn_initial_players(get_configured_player_count(1))

	if _mirror_1 and _mirror_2:
		_mirror_1.rotated.connect(_evaluate_mirrors)
		_mirror_2.rotated.connect(_evaluate_mirrors)
		_evaluate_mirrors()

	var scarabs: Array[Vector3] = [
		Vector3(19.5, 0.2, 2.5),
		Vector3(-19.5, 0.2, 2.5),
		Vector3(0.0, 0.2, -13.5),
	]
	spawn_scarabs(scarabs)

func _build_level() -> void:
	# Start platform (Tutorial)
	build_floor(Vector3(0.0, -0.1, 11.5), Vector3(10.0, 0.2, 7.0))
	build_wall(Vector3(0.0, 2.0, 15.2), Vector3(10.4, 4.0, 0.5))
	build_light(Vector3(0.0, 4.5, 11.5), Color(1.0, 0.82, 0.5), 1.8, 14.0)

	# Tutorial WhipHook over first gap (z = 4.5..8.0)
	var hook_tut := Node3D.new()
	hook_tut.set_script(WHIP_HOOK_SCRIPT)
	hook_tut.position = Vector3(0.0, 0.0, 6.25)
	add_child(hook_tut)

	# Central Hub
	build_floor(Vector3(0.0, -0.1, -0.5), Vector3(18.0, 0.2, 10.0))
	build_light(Vector3(0.0, 5.0, -0.5), Color(1.0, 0.85, 0.55), 2.0, 16.0)
	spawn_prop(PILLAR_SCENE, Vector3(-7.0, 0.0, 3.0))
	spawn_prop(PILLAR_SCENE, Vector3(7.0, 0.0, 3.0))

	# Right Island (Mirror 1 - Skylight source)
	var hook_r := Node3D.new()
	hook_r.set_script(WHIP_HOOK_SCRIPT)
	hook_r.position = Vector3(11.5, 0.0, -1.0)
	add_child(hook_r)

	build_floor(Vector3(18.5, -0.1, -1.0), Vector3(9.0, 0.2, 9.0))
	build_light(Vector3(18.5, 5.0, -1.0), Color(1.0, 0.9, 0.6), 2.0, 13.0)
	_mirror_1 = spawn_prop(MIRROR_SCENE, Vector3(18.5, 0.0, -1.0), 90.0) as MirrorPillar

	# Left Island (Mirror 2)
	var hook_l := Node3D.new()
	hook_l.set_script(WHIP_HOOK_SCRIPT)
	hook_l.position = Vector3(-11.5, 0.0, -1.0)
	add_child(hook_l)

	build_floor(Vector3(-18.5, -0.1, -1.0), Vector3(9.0, 0.2, 9.0))
	build_light(Vector3(-18.5, 5.0, -1.0), Color(1.0, 0.9, 0.6), 2.0, 13.0)
	_mirror_2 = spawn_prop(MIRROR_SCENE, Vector3(-18.5, 0.0, -1.0), 0.0) as MirrorPillar

	# Spike hazard on Central Hub bridge toward SunReceiver
	spawn_prop(SPIKE_SCENE, Vector3(0.0, 0.0, -3.5))

	# North Exit Bridge & Room
	build_floor(Vector3(0.0, -0.1, -10.5), Vector3(10.0, 0.2, 10.0))
	build_wall(Vector3(-5.2, 2.0, -10.5), Vector3(0.5, 4.0, 10.0))
	build_wall(Vector3(5.2, 2.0, -10.5), Vector3(0.5, 4.0, 10.0))
	build_wall(Vector3(0.0, 2.0, -15.7), Vector3(10.8, 4.0, 0.5))
	build_light(Vector3(0.0, 4.5, -11.0), Color(1.0, 0.85, 0.5), 1.8, 13.0)

	var door := spawn_prop(DOOR_SCENE, Vector3(0.0, 0.0, -6.5)) as AncientDoor
	door.required_triggers = 1

	_sun_receiver = spawn_prop(RECEIVER_SCENE, Vector3(-4.0, 0.0, -4.5), 90.0) as SunReceiver
	_sun_receiver.required_target = _sun_receiver.get_path_to(door)

	spawn_prop(EXIT_SCENE, Vector3(0.0, 0.0, -12.0))

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
		var trace := cur.trace_beam(42.0)
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
