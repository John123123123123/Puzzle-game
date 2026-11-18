extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 4: The Wind-Swept Vault (Introduces WindVent gusts & Torch extinguishing)

const WIND_VENT_SCRIPT := preload("res://scenes/puzzles/wind_vent.gd")
const BRAZIER_SCENE := preload("res://scenes/puzzles/brazier.tscn")
const TORCH_SCENE := preload("res://scenes/puzzles/torch.tscn")
const CRATE_SCENE := preload("res://scenes/puzzles/pushable_block.tscn")
const DART_SCENE := preload("res://scenes/puzzles/dart_trap.tscn")
const DOOR_SCENE := preload("res://scenes/puzzles/ancient_door.tscn")
const EXIT_SCENE := preload("res://scenes/puzzles/level_exit.tscn")
const PILLAR_SCENE := preload("res://scenes/props/temple_pillar.tscn")

var _lit_count: int = 0
var _exit_door: AncientDoor

func _ready() -> void:
	super._ready()
	hud.set_objective("Level 4: Keep your torch lit past the wind vents to light both braziers (0/2)!")
	_build_level()
	spawn_initial_players(get_configured_player_count(1))

	var scarabs: Array[Vector3] = [
		Vector3(10.5, 0.2, -4.5),
		Vector3(-10.5, 0.2, -8.5),
		Vector3(0.0, 0.2, -3.5),
	]
	spawn_scarabs(scarabs)

func _build_level() -> void:
	# Entry & Demo Hall
	build_floor(Vector3(0.0, -0.1, 8.0), Vector3(12.0, 0.2, 12.0))
	build_wall(Vector3(-6.2, 2.0, 8.0), Vector3(0.5, 4.0, 12.0))
	build_wall(Vector3(6.2, 2.0, 8.0), Vector3(0.5, 4.0, 12.0))
	build_wall(Vector3(0.0, 2.0, 14.2), Vector3(12.8, 4.0, 0.5))
	build_light(Vector3(0.0, 4.5, 9.0), Color(1.0, 0.8, 0.5), 1.8, 14.0)

	# Eternal lit brazier + Torch at start so players can always relight
	var eternal_brazier := spawn_prop(BRAZIER_SCENE, Vector3(-3.0, 0.0, 10.5)) as Brazier
	eternal_brazier.is_lit = true
	spawn_prop(TORCH_SCENE, Vector3(2.5, 0.0, 10.5))

	# Safe Wind Demo across entry hall
	var demo_vent := Node3D.new()
	demo_vent.set_script(WIND_VENT_SCRIPT)
	demo_vent.position = Vector3(-5.8, 0.0, 5.5)
	demo_vent.rotation.y = deg_to_rad(-90.0)
	demo_vent.continuous = false
	demo_vent.gust_length = 11.0
	add_child(demo_vent)

	# Main Split Vault
	build_floor(Vector3(0.0, -0.1, -5.0), Vector3(26.0, 0.2, 14.0))
	build_wall(Vector3(-13.2, 2.0, -5.0), Vector3(0.5, 4.0, 14.0))
	build_wall(Vector3(13.2, 2.0, -5.0), Vector3(0.5, 4.0, 14.0))
	build_wall(Vector3(-8.5, 2.0, -12.2), Vector3(9.5, 4.0, 0.5))
	build_wall(Vector3(8.5, 2.0, -12.2), Vector3(9.5, 4.0, 0.5))
	build_light(Vector3(-7.0, 5.0, -5.0), Color(0.75, 0.9, 1.0), 1.8, 15.0)
	build_light(Vector3(7.0, 5.0, -5.0), Color(0.75, 0.9, 1.0), 1.8, 15.0)

	spawn_prop(PILLAR_SCENE, Vector3(-4.0, 0.0, -2.0))
	spawn_prop(PILLAR_SCENE, Vector3(4.0, 0.0, -2.0))

	# Left Lane: Continuous wind blocked by PushableBlock
	spawn_prop(CRATE_SCENE, Vector3(-4.5, 0.0, 0.5))
	var cont_vent := Node3D.new()
	cont_vent.set_script(WIND_VENT_SCRIPT)
	cont_vent.position = Vector3(-12.8, 0.0, -5.0)
	cont_vent.rotation.y = deg_to_rad(-90.0)
	cont_vent.continuous = true
	cont_vent.gust_length = 9.0
	add_child(cont_vent)

	# Right Lane: Timed alternating wind vents
	var timed_vent_1 := Node3D.new()
	timed_vent_1.set_script(WIND_VENT_SCRIPT)
	timed_vent_1.position = Vector3(12.8, 0.0, -3.0)
	timed_vent_1.rotation.y = deg_to_rad(90.0)
	timed_vent_1.continuous = false
	timed_vent_1.gust_length = 8.5
	add_child(timed_vent_1)

	var timed_vent_2 := Node3D.new()
	timed_vent_2.set_script(WIND_VENT_SCRIPT)
	timed_vent_2.position = Vector3(12.8, 0.0, -7.0)
	timed_vent_2.rotation.y = deg_to_rad(90.0)
	timed_vent_2.continuous = false
	timed_vent_2.start_delay = 1.5
	timed_vent_2.gust_length = 8.5
	add_child(timed_vent_2)

	# Center Dart Trap guarding Scarab 3
	spawn_prop(DART_SCENE, Vector3(0.0, 0.0, -11.5), 180.0)

	# Target Braziers
	var b1 := spawn_prop(BRAZIER_SCENE, Vector3(-9.0, 0.0, -10.0)) as Brazier
	var b2 := spawn_prop(BRAZIER_SCENE, Vector3(9.0, 0.0, -10.0)) as Brazier
	b1.lit_state_changed.connect(_on_brazier_lit)
	b2.lit_state_changed.connect(_on_brazier_lit)

	# Exit Room
	build_floor(Vector3(0.0, -0.1, -16.5), Vector3(8.0, 0.2, 9.0))
	build_wall(Vector3(-4.2, 2.0, -16.5), Vector3(0.5, 4.0, 9.0))
	build_wall(Vector3(4.2, 2.0, -16.5), Vector3(0.5, 4.0, 9.0))
	build_wall(Vector3(0.0, 2.0, -21.2), Vector3(8.8, 4.0, 0.5))
	build_light(Vector3(0.0, 4.5, -17.0), Color(1.0, 0.85, 0.5), 1.8, 12.0)

	_exit_door = spawn_prop(DOOR_SCENE, Vector3(0.0, 0.0, -12.2)) as AncientDoor
	_exit_door.required_triggers = 2
	spawn_prop(EXIT_SCENE, Vector3(0.0, 0.0, -18.0))

func _on_brazier_lit(is_lit: bool) -> void:
	if is_lit:
		_lit_count += 1
		if is_instance_valid(_exit_door):
			_exit_door.register_trigger_activated()
		if _lit_count >= 2:
			hud.set_objective("Level 4: Both braziers lit! Head through the exit!")
		else:
			hud.set_objective("Level 4: Light both braziers (%d/2)!" % _lit_count)
