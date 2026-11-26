extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 4: Sanctum of Shifting Light
## Features: Co-op Mirror + Solar/Lunar Phase Combo Puzzle, Sandstone Quicksand, Conveyor Floors, and Gear-Driven Stone Rafts.

const FLOOR_SHADER := preload("res://shaders/ancient_stone_floor.gdshader")
const WALL_SHADER := preload("res://shaders/ancient_temple_wall.gdshader")
const DOOR_SCENE := preload("res://scenes/puzzles/ancient_door.tscn")
const PLATE_SCENE := preload("res://scenes/puzzles/pressure_plate.tscn")
const BLOCK_SCENE := preload("res://scenes/puzzles/pushable_block.tscn")
const LEVER_SCENE := preload("res://scenes/puzzles/wall_lever.tscn")
const MIRROR_SCENE := preload("res://scenes/puzzles/mirror_pillar.tscn")
const RECEIVER_SCENE := preload("res://scenes/puzzles/sun_receiver.tscn")
const OBELISK_SCENE := preload("res://scenes/puzzles/phase_obelisk.tscn")
const PHASE_PLAT_SCENE := preload("res://scenes/puzzles/phase_platform.tscn")
const QUICKSAND_SCENE := preload("res://scenes/puzzles/quicksand_pit.tscn")
const CONVEYOR_SCENE := preload("res://scenes/puzzles/conveyor_floor.tscn")
const RAFT_SCENE := preload("res://scenes/puzzles/moving_platform.tscn")
const SPIKE_PIT_SCENE := preload("res://scenes/puzzles/spike_pit.tscn")
const SKYLIGHT_SCENE := preload("res://scenes/props/skylight_beam.tscn")
const PILLAR_SCENE := preload("res://scenes/props/temple_pillar.tscn")
const URN_SCENE := preload("res://scenes/props/ancient_urn.tscn")

var _floor_mat: ShaderMaterial = null
var _wall_mat: ShaderMaterial = null

var _gate_1: AncientDoor = null
var _west_shutter: AncientDoor = null
var _sanctum_gate: AncientDoor = null
var _exit_gate: AncientDoor = null

var _receiver_north: SunReceiver = null
var _west_shutter_lever: WallLever = null

var _all_mirrors: Array[MirrorPillar] = []
var _all_receivers: Array[SunReceiver] = []
var _beam_sources: Array[MirrorPillar] = []
var _world_phase: int = 0
var _recheck_mirrors_frames: int = 0

func _ready() -> void:
	super._ready()
	register_room_checkpoint(10.0, -10.3, Vector3(0.0, 0.25, 4.0))
	register_room_checkpoint(-10.3, -36.4, Vector3(0.0, 0.25, -13.2))
	register_room_checkpoint(-36.4, -59.1, Vector3(0.0, 0.25, -39.0))
	register_room_checkpoint(-59.1, -72.0, Vector3(0.0, 0.25, -61.5))
	_init_materials()
	_build_chamber_1()
	_build_chamber_2()
	_build_chamber_3()
	_build_exit_sanctum()

	spawn_initial_players(get_configured_player_count(1))

	for node in get_tree().get_nodes_in_group("phase_obelisk"):
		if node is PhaseObelisk:
			node.phase_shifted.connect(_on_phase_shifted)

	for m in _all_mirrors:
		if is_instance_valid(m):
			m.rotated.connect(_on_mirror_rotated)
	for r in _all_receivers:
		if is_instance_valid(r):
			r.power_changed.connect(func(_p): _refresh_objective())

	for g in [_gate_1, _west_shutter, _sanctum_gate, _exit_gate]:
		if is_instance_valid(g):
			g.door_opened.connect(func(_d): _refresh_objective())
			g.door_closed.connect(func(_d): _refresh_objective())

	_recheck_mirrors_frames = 2
	_refresh_objective()

	var scarab_spots: Array[Vector3] = [
		Vector3(-5.2, 0.1, -3.5),
		Vector3(-11.0, 0.1, -21.0),
		Vector3(10.8, 0.1, -28.0),
		Vector3(-6.2, 0.1, -40.5),
		Vector3(0.0, 0.1, -61.5),
	]
	spawn_scarabs(scarab_spots)

func _init_materials() -> void:
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FLOOR_SHADER
	_floor_mat.set_shader_parameter("base_color", Color(0.36, 0.34, 0.42))
	_floor_mat.set_shader_parameter("mortar_color", Color(0.14, 0.12, 0.18))
	_floor_mat.set_shader_parameter("edge_highlight", Color(0.56, 0.52, 0.64))
	_floor_mat.set_shader_parameter("sand_color", Color(0.54, 0.44, 0.28))

	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = WALL_SHADER
	_wall_mat.set_shader_parameter("wall_base", Color(0.30, 0.27, 0.34))
	_wall_mat.set_shader_parameter("wall_dark", Color(0.14, 0.12, 0.18))
	_wall_mat.set_shader_parameter("trim_gold", Color(0.88, 0.72, 0.28))

func _add_stone_slab(pos: Vector3, sz: Vector3, is_wall: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	if is_wall:
		body.add_to_group("wall")
	body.position = pos
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	col.shape = bs
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	bm.material = _wall_mat if is_wall else _floor_mat
	mi.mesh = bm
	body.add_child(mi)
	add_child(body)
	return body

func _add_wall_with_doorway(z_pos: float, width: float, door_width: float = 3.8) -> void:
	var side_w := (width - door_width) * 0.5
	var side_x := (door_width + side_w) * 0.5
	_add_stone_slab(Vector3(0.0, -0.1, z_pos), Vector3(door_width + 1.2, 0.2, 1.6), false)
	_add_stone_slab(Vector3(-side_x, 2.5, z_pos), Vector3(side_w, 5.0, 0.6), true)
	_add_stone_slab(Vector3(side_x, 2.5, z_pos), Vector3(side_w, 5.0, 0.6), true)
	_add_stone_slab(Vector3(0.0, 4.6, z_pos), Vector3(door_width + 0.4, 0.8, 0.6), true)

func _build_chamber_1() -> void:
	# Chamber 1: Shifting Sands Courtyard (Z = +6 to -10.3, X = -9 to +9)
	_add_stone_slab(Vector3(0.0, -0.1, -2.2), Vector3(18.0, 0.2, 16.8), false)
	_add_stone_slab(Vector3(0.0, 2.5, 6.2), Vector3(18.6, 5.0, 0.6), true)
	_add_stone_slab(Vector3(-9.3, 2.5, -2.0), Vector3(0.6, 5.0, 16.4), true)
	_add_stone_slab(Vector3(9.3, 2.5, -2.0), Vector3(0.6, 5.0, 16.4), true)
	_add_wall_with_doorway(-10.3, 18.6, 3.8)

	_gate_1 = DOOR_SCENE.instantiate() as AncientDoor
	_gate_1.stays_open = false
	_gate_1.required_triggers = 1
	_gate_1.position = Vector3(0.0, 0.0, -10.3)
	add_child(_gate_1)

	# Flanking Quicksand Pits
	for q_x in [-5.2, 5.2]:
		var qs := QUICKSAND_SCENE.instantiate() as QuicksandPit
		qs.pit_size = Vector3(4.6, 0.4, 5.2)
		qs.position = Vector3(q_x, 0.0, -3.5)
		add_child(qs)

	# Conveyor Belt carrying crate toward Plate1 once reversed via WallLever
	var conv := CONVEYOR_SCENE.instantiate() as ConveyorFloor
	conv.belt_size = Vector3(2.8, 0.16, 6.2)
	conv.belt_direction = Vector3(0.0, 0.0, 1.0)
	conv.belt_speed = 2.1
	conv.position = Vector3(0.0, -0.06, -3.4)
	add_child(conv)

	var lever1 := LEVER_SCENE.instantiate() as WallLever
	lever1.position = Vector3(-8.95, 0.85, 1.2)
	lever1.rotation.y = deg_to_rad(90.0)
	add_child(lever1)
	lever1.targets = [lever1.get_path_to(conv)]

	var block1 := BLOCK_SCENE.instantiate() as PushableBlock
	block1.position = Vector3(0.0, 0.1, 0.6)
	add_child(block1)

	var plate1 := PLATE_SCENE.instantiate() as PressurePlate
	plate1.is_permanent = false
	plate1.position = Vector3(0.0, 0.0, -7.2)
	add_child(plate1)
	_gate_1.pressure_plates = [_gate_1.get_path_to(plate1)]
	plate1.state_changed.connect(_gate_1._on_plate_state_changed)
	_gate_1._evaluate_door_state()

	for ux in [-7.5, 7.5]:
		var urn := URN_SCENE.instantiate()
		urn.position = Vector3(ux, 0.0, 4.4)
		add_child(urn)

func _build_chamber_2() -> void:
	# Chamber 2: Split-Path Prism Gallery (Z = -10.6 to -36.4, X = -13 to +13)
	_add_stone_slab(Vector3(0.0, -0.1, -13.7), Vector3(26.0, 0.2, 6.8), false)
	_add_stone_slab(Vector3(-8.5, -0.1, -23.5), Vector3(9.0, 0.2, 13.4), false)
	_add_stone_slab(Vector3(8.5, -0.1, -23.5), Vector3(9.0, 0.2, 13.4), false)
	_add_stone_slab(Vector3(0.0, -0.1, -33.4), Vector3(26.0, 0.2, 6.8), false)

	_add_stone_slab(Vector3(-13.3, 2.5, -23.4), Vector3(0.6, 5.0, 26.2), true)
	_add_stone_slab(Vector3(13.3, 2.5, -23.4), Vector3(0.6, 5.0, 26.2), true)
	_add_stone_slab(Vector3(-11.1, 2.5, -10.3), Vector3(4.0, 5.0, 0.6), true)
	_add_stone_slab(Vector3(11.1, 2.5, -10.3), Vector3(4.0, 5.0, 0.6), true)
	_add_wall_with_doorway(-36.4, 26.6, 3.8)

	_sanctum_gate = DOOR_SCENE.instantiate() as AncientDoor
	_sanctum_gate.stays_open = false
	_sanctum_gate.required_triggers = 1
	_sanctum_gate.position = Vector3(0.0, 0.0, -36.4)
	add_child(_sanctum_gate)

	# Central Chasm Raft (East <-> West) + Moon Bridge connecting East & West wings
	var chasm_pit_2 := SPIKE_PIT_SCENE.instantiate() as SpikePit
	chasm_pit_2.pit_size = Vector2(8.2, 13.1)
	chasm_pit_2.pit_depth = 2.4
	chasm_pit_2.position = Vector3(0.0, 0.0, -23.55)
	add_child(chasm_pit_2)

	var center_raft := RAFT_SCENE.instantiate() as MovingPlatform
	center_raft.platform_size = Vector3(3.2, 0.34, 3.2)
	center_raft.travel_offset = Vector3(4.8, 0.0, 0.0)
	center_raft.travel_duration = 3.0
	center_raft.pause_duration = 0.8
	center_raft.position = Vector3(-2.4, -0.17, -21.0)
	add_child(center_raft)

	var moon_bridge := PHASE_PLAT_SCENE.instantiate() as PhasePlatform
	moon_bridge.active_phase = 1
	moon_bridge.platform_kind = 0
	moon_bridge.box_size = Vector3(8.2, 0.28, 2.8)
	moon_bridge.position = Vector3(0.0, -0.14, -28.6)
	add_child(moon_bridge)

	# Solar side alcove for Scarab #2 (enclosed north/south so forcefield truly gates it)
	_add_stone_slab(Vector3(-11.3, 2.5, -19.3), Vector3(3.4, 5.0, 0.5), true)
	_add_stone_slab(Vector3(-11.3, 2.5, -22.7), Vector3(3.4, 5.0, 0.5), true)
	var solar_alcove_gate := PHASE_PLAT_SCENE.instantiate() as PhasePlatform
	solar_alcove_gate.active_phase = 0
	solar_alcove_gate.platform_kind = 1
	solar_alcove_gate.box_size = Vector3(0.32, 3.0, 3.2)
	solar_alcove_gate.position = Vector3(-9.6, 1.5, -21.0)
	add_child(solar_alcove_gate)

	# Dual Phase Obelisks (Hub for solo ease + West Wing for splitscreen P2)
	for ob_pos in [Vector3(-3.2, 0.0, -13.6), Vector3(-6.0, 0.0, -21.5)]:
		var ob := OBELISK_SCENE.instantiate() as PhaseObelisk
		ob.position = ob_pos
		add_child(ob)

	# East Mirror Wing (Skylight -> Mirror1 -> Mirror2)
	var skylight := SKYLIGHT_SCENE.instantiate()
	skylight.position = Vector3(6.0, 0.0, -19.0)
	add_child(skylight)

	var m1 := MIRROR_SCENE.instantiate() as MirrorPillar
	m1.current_step = 0 # Facing North (-Z)
	m1.is_rotatable = false
	m1.position = Vector3(6.0, 0.0, -19.0)
	add_child(m1)

	var m2 := MIRROR_SCENE.instantiate() as MirrorPillar
	m2.current_step = 1 # Facing East initially; player rotates North (0) or West (3)
	m2.position = Vector3(6.0, 0.0, -25.0)
	add_child(m2)

	# Lunar Forcefield across East corridor (open in SUN phase to pull the West Shutter Lever!)
	var shield_lunar := PHASE_PLAT_SCENE.instantiate() as PhasePlatform
	shield_lunar.active_phase = 1
	shield_lunar.platform_kind = 1
	shield_lunar.box_size = Vector3(8.6, 3.0, 0.32)
	shield_lunar.position = Vector3(8.5, 1.5, -28.4)
	add_child(shield_lunar)

	# West Mirror Wing shutter framed with archway walls (held open by reversible WallLever in East alcove)
	_add_stone_slab(Vector3(-11.45, 2.5, -28.6), Vector3(3.1, 5.0, 0.6), true)
	_add_stone_slab(Vector3(-5.05, 2.5, -28.6), Vector3(2.1, 5.0, 0.6), true)
	_west_shutter = DOOR_SCENE.instantiate() as AncientDoor
	_west_shutter.stays_open = false
	_west_shutter.required_triggers = 1
	_west_shutter.scale = Vector3(1.0, 0.72, 1.0)
	_west_shutter.position = Vector3(-8.0, 0.0, -28.6)
	add_child(_west_shutter)

	_west_shutter_lever = LEVER_SCENE.instantiate() as WallLever
	_west_shutter_lever.is_one_shot = false
	_west_shutter_lever.position = Vector3(12.95, 0.85, -32.0)
	_west_shutter_lever.rotation.y = deg_to_rad(-90.0)
	add_child(_west_shutter_lever)
	_west_shutter_lever.targets = [_west_shutter_lever.get_path_to(_west_shutter)]

	var shield_solar := PHASE_PLAT_SCENE.instantiate() as PhasePlatform
	shield_solar.active_phase = 0
	shield_solar.platform_kind = 1
	shield_solar.box_size = Vector3(0.32, 3.0, 2.8)
	shield_solar.position = Vector3(-1.2, 1.5, -25.0)
	add_child(shield_solar)

	var m3 := MIRROR_SCENE.instantiate() as MirrorPillar
	m3.current_step = 3 # Facing West initially; align to North (0)
	m3.position = Vector3(-8.0, 0.0, -25.0)
	add_child(m3)

	var m4 := MIRROR_SCENE.instantiate() as MirrorPillar
	m4.current_step = 2 # Facing South initially; align to East (1)
	m4.position = Vector3(-8.0, 0.0, -32.0)
	add_child(m4)

	# Mounted at exact Mirror BeamPivot height (y = 1.07), facing West (-X) toward Mirror4
	_add_stone_slab(Vector3(-2.05, 0.85, -32.0), Vector3(0.9, 1.7, 1.2), true)
	_receiver_north = RECEIVER_SCENE.instantiate() as SunReceiver
	_receiver_north.position = Vector3(-2.6, 1.07, -32.0)
	_receiver_north.rotation.y = deg_to_rad(-90.0)
	add_child(_receiver_north)
	_receiver_north.required_target = _receiver_north.get_path_to(_sanctum_gate)

	_all_mirrors = [m1, m2, m3, m4]
	_beam_sources = [m1]
	_all_receivers = [_receiver_north]

	for px in [-11.5, 11.5]:
		var p := PILLAR_SCENE.instantiate()
		p.position = Vector3(px, 0.0, -14.0)
		add_child(p)

func _build_chamber_3() -> void:
	# Chamber 3: Gear-Raft & Conveyor Abyss (Z = -36.4 to -59.1)
	_add_stone_slab(Vector3(0.0, -0.1, -39.35), Vector3(18.0, 0.2, 6.3), false)
	_add_stone_slab(Vector3(0.0, -0.1, -55.0), Vector3(18.0, 0.2, 8.6), false)

	var chasm_pit_3 := SPIKE_PIT_SCENE.instantiate() as SpikePit
	chasm_pit_3.pit_size = Vector2(18.2, 8.4)
	chasm_pit_3.pit_depth = 2.4
	chasm_pit_3.position = Vector3(0.0, 0.0, -46.6)
	add_child(chasm_pit_3)

	_add_stone_slab(Vector3(-9.3, 2.5, -47.6), Vector3(0.6, 5.0, 22.8), true)
	_add_stone_slab(Vector3(9.3, 2.5, -47.6), Vector3(0.6, 5.0, 22.8), true)
	_add_wall_with_doorway(-59.1, 19.2, 3.8)

	_exit_gate = DOOR_SCENE.instantiate() as AncientDoor
	_exit_gate.stays_open = false
	_exit_gate.required_triggers = 2
	_exit_gate.position = Vector3(0.0, 0.0, -59.1)
	add_child(_exit_gate)

	# Dual counter-cycling Gear Stone Rafts across chasm (-42.5 to -50.7)
	var raft_l := RAFT_SCENE.instantiate() as MovingPlatform
	raft_l.platform_size = Vector3(3.4, 0.34, 3.4)
	raft_l.travel_offset = Vector3(0.0, 0.0, -4.8)
	raft_l.travel_duration = 2.8
	raft_l.pause_duration = 0.7
	raft_l.position = Vector3(-3.6, -0.17, -44.2)
	add_child(raft_l)

	var raft_r := RAFT_SCENE.instantiate() as MovingPlatform
	raft_r.platform_size = Vector3(3.4, 0.34, 3.4)
	raft_r.travel_offset = Vector3(0.0, 0.0, 4.8)
	raft_r.travel_duration = 2.8
	raft_r.pause_duration = 0.7
	raft_r.position = Vector3(3.6, -0.17, -49.0)
	add_child(raft_r)

	# Island Quicksand center + outward Conveyor strips + twin exit levers
	var qs_island := QUICKSAND_SCENE.instantiate() as QuicksandPit
	qs_island.pit_size = Vector3(4.2, 0.4, 4.0)
	qs_island.position = Vector3(0.0, 0.0, -53.8)
	add_child(qs_island)

	var conv_l := CONVEYOR_SCENE.instantiate() as ConveyorFloor
	conv_l.belt_size = Vector3(2.4, 0.16, 4.8)
	conv_l.belt_direction = Vector3(1.0, 0.0, 0.0)
	conv_l.belt_speed = 1.9
	conv_l.position = Vector3(-4.2, -0.06, -54.5)
	add_child(conv_l)

	var conv_r := CONVEYOR_SCENE.instantiate() as ConveyorFloor
	conv_r.belt_size = Vector3(2.4, 0.16, 4.8)
	conv_r.belt_direction = Vector3(-1.0, 0.0, 0.0)
	conv_r.belt_speed = 1.9
	conv_r.position = Vector3(4.2, -0.06, -54.5)
	add_child(conv_r)

	var lever_w := LEVER_SCENE.instantiate() as WallLever
	lever_w.is_one_shot = false
	lever_w.position = Vector3(-8.95, 0.85, -55.0)
	lever_w.rotation.y = deg_to_rad(90.0)
	add_child(lever_w)
	lever_w.targets = [lever_w.get_path_to(_exit_gate)]

	var lever_e := LEVER_SCENE.instantiate() as WallLever
	lever_e.is_one_shot = false
	lever_e.position = Vector3(8.95, 0.85, -55.0)
	lever_e.rotation.y = deg_to_rad(-90.0)
	add_child(lever_e)
	lever_e.targets = [lever_e.get_path_to(_exit_gate)]

func _build_exit_sanctum() -> void:
	_add_stone_slab(Vector3(0.0, -0.1, -62.9), Vector3(12.0, 0.2, 8.2), false)
	_add_stone_slab(Vector3(-6.3, 2.5, -63.0), Vector3(0.6, 5.0, 8.2), true)
	_add_stone_slab(Vector3(6.3, 2.5, -63.0), Vector3(0.6, 5.0, 8.2), true)
	_add_stone_slab(Vector3(0.0, 2.5, -67.2), Vector3(13.2, 5.0, 0.6), true)

func _physics_process(_delta: float) -> void:
	_evaluate_mirrors()

func _on_mirror_rotated(_angle: float) -> void:
	_recheck_mirrors_frames = 2
	_evaluate_mirrors()

func _on_phase_shifted(new_phase: int) -> void:
	_world_phase = new_phase
	_recheck_mirrors_frames = 3
	_refresh_objective()

func _evaluate_mirrors() -> void:
	var lit_mirrors: Array[MirrorPillar] = []
	var powered_receivers: Array[SunReceiver] = []

	for src in _beam_sources:
		var current: MirrorPillar = src
		while is_instance_valid(current) and not lit_mirrors.has(current):
			lit_mirrors.append(current)
			var trace := current.trace_beam(24.0)
			current.set_beam_active(true, trace["length"])
			if trace["hit_receiver"] is SunReceiver:
				var hit_r := trace["hit_receiver"] as SunReceiver
				if not powered_receivers.has(hit_r):
					powered_receivers.append(hit_r)
				current = null
			elif trace["hit_mirror"] is MirrorPillar:
				current = trace["hit_mirror"]
			else:
				current = null

	for m in _all_mirrors:
		if is_instance_valid(m) and not lit_mirrors.has(m):
			m.set_beam_active(false)

	for r in _all_receivers:
		if is_instance_valid(r):
			r.set_powered(powered_receivers.has(r))

func _refresh_objective() -> void:
	if not is_instance_valid(hud):
		return
	var phase_name := "SUN" if _world_phase == 0 else "MOON"
	if is_instance_valid(_exit_gate) and _exit_gate.is_open:
		hud.set_objective("Level 4 [Phase: %s]: Cross into the portal to reach The Sunken Cistern!" % phase_name)
	elif is_instance_valid(_sanctum_gate) and _sanctum_gate.is_open:
		hud.set_objective("Level 4 [Phase: %s]: Ride the stone rafts across the abyss and pull both exit levers!" % phase_name)
	elif is_instance_valid(_west_shutter) and _west_shutter.is_open:
		hud.set_objective("Level 4 [Phase: %s]: Shift to MOON phase and route the sunbeam across the chasm into the North crystal!" % phase_name)
	elif is_instance_valid(_gate_1) and _gate_1.is_open:
		hud.set_objective("Level 4 [Phase: %s]: In SUN phase, cross the East shield and pull the alcove lever to unseal the West shutter!" % phase_name)
	else:
		hud.set_objective("Level 4 [Phase: %s]: Pull the lever to reverse the conveyor or push the crate onto the seal!" % phase_name)
