extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 5: The Sunken Cistern
## Features: Floodgate levers raising/lowering water levels, floating wooden crates forming walkable bridges,
## dual lock reservoirs, and a terraced Rising Flood-Tide Escape finale.

const FLOOR_SHADER := preload("res://shaders/ancient_stone_floor.gdshader")
const WALL_SHADER := preload("res://shaders/ancient_temple_wall.gdshader")
const DOOR_SCENE := preload("res://scenes/puzzles/ancient_door.tscn")
const PLATE_SCENE := preload("res://scenes/puzzles/pressure_plate.tscn")
const BLOCK_SCENE := preload("res://scenes/puzzles/pushable_block.tscn")
const LEVER_SCENE := preload("res://scenes/puzzles/wall_lever.tscn")
const RAFT_SCENE := preload("res://scenes/puzzles/moving_platform.tscn")
const CONVEYOR_SCENE := preload("res://scenes/puzzles/conveyor_floor.tscn")
const QUICKSAND_SCENE := preload("res://scenes/puzzles/quicksand_pit.tscn")
const WATER_SCENE := preload("res://scenes/puzzles/cistern_water.tscn")
const SPIKE_PIT_SCENE := preload("res://scenes/puzzles/spike_pit.tscn")
const PILLAR_SCENE := preload("res://scenes/props/temple_pillar.tscn")
const URN_SCENE := preload("res://scenes/props/ancient_urn.tscn")

var _floor_mat: ShaderMaterial = null
var _wall_mat: ShaderMaterial = null

var _sluice_gate: AncientDoor = null
var _reservoir_gate: AncientDoor = null
var _escape_gate: AncientDoor = null

var _water_1: CisternWater = null
var _water_w: CisternWater = null
var _water_e: CisternWater = null
var _escape_water: CisternWater = null
var _flood_started: bool = false

func _ready() -> void:
	super._ready()
	register_room_checkpoint(10.0, -17.1, Vector3(0.0, 0.25, 3.5))
	register_room_checkpoint(-17.1, -38.1, Vector3(0.0, 0.25, -19.4))
	register_room_checkpoint(-38.1, -76.0, Vector3(0.0, 0.25, -40.5))
	_init_materials()
	_build_chamber_1()
	_build_chamber_2()
	_build_chamber_3()

	spawn_initial_players(get_configured_player_count(1))

	for g in [_sluice_gate, _reservoir_gate, _escape_gate]:
		if is_instance_valid(g):
			g.door_opened.connect(func(_d): _refresh_objective())
			g.door_closed.connect(func(_d): _refresh_objective())

	_refresh_objective()

	var scarab_spots: Array[Vector3] = [
		Vector3(0.0, 0.1, -4.4),
		Vector3(5.8, -1.35, -8.5),
		Vector3(9.4, -1.35, -29.5),
		Vector3(5.5, 0.80, -52.5),
		Vector3(0.0, 2.20, -66.8),
	]
	spawn_scarabs(scarab_spots)

func _init_materials() -> void:
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FLOOR_SHADER
	_floor_mat.set_shader_parameter("base_color", Color(0.28, 0.36, 0.39))
	_floor_mat.set_shader_parameter("mortar_color", Color(0.10, 0.14, 0.17))
	_floor_mat.set_shader_parameter("edge_highlight", Color(0.45, 0.62, 0.66))
	_floor_mat.set_shader_parameter("sand_color", Color(0.24, 0.42, 0.42))

	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = WALL_SHADER
	_wall_mat.set_shader_parameter("wall_base", Color(0.22, 0.30, 0.34))
	_wall_mat.set_shader_parameter("wall_dark", Color(0.10, 0.14, 0.18))
	_wall_mat.set_shader_parameter("trim_gold", Color(0.35, 0.84, 0.86))

func _add_stone_slab(pos: Vector3, sz: Vector3, is_wall: bool = false, rot_x: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	if is_wall:
		body.add_to_group("wall")
	body.position = pos
	body.rotation.x = rot_x
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

func _add_channel_guide(pos: Vector3, sz: Vector3) -> void:
	var guide := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.62, 0.30)
	mat.metallic = 0.55
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = Color(0.28, 0.72, 0.78)
	mat.emission_energy_multiplier = 0.35
	bm.material = mat
	guide.mesh = bm
	guide.position = pos
	add_child(guide)

## Connects low_pos (top surface) to high_pos (top surface) along Z with a gentle walkable stone ramp.
func _add_ramp_z(x_pos: float, width: float, z_from: float, y_from: float, z_to: float, y_to: float) -> void:
	var dz := z_to - z_from
	var dy := y_to - y_from
	var horiz_len := absf(dz)
	var slope_len := sqrt(horiz_len * horiz_len + dy * dy) + 0.08
	# Right-handed X-rotation gives y' = -z_local * sin(angle), so dy/dz = -tan(angle).
	var angle := atan2(dy, horiz_len) * (1.0 if dz < 0.0 else -1.0)
	var half_thick := 0.11
	var mid := Vector3(x_pos, (y_from + y_to) * 0.5 - half_thick / maxf(0.25, cos(angle)), (z_from + z_to) * 0.5)
	_add_stone_slab(mid, Vector3(width, half_thick * 2.0, slope_len), false, angle)

func _add_wall_with_doorway(z_pos: float, width: float, y_base: float = 0.0, door_width: float = 3.8) -> void:
	var side_w := (width - door_width) * 0.5
	var side_x := (door_width + side_w) * 0.5
	_add_stone_slab(Vector3(0.0, y_base - 0.1, z_pos), Vector3(door_width + 1.2, 0.2, 1.6), false)
	_add_stone_slab(Vector3(-side_x, y_base + 2.5, z_pos), Vector3(side_w, 5.0, 0.6), true)
	_add_stone_slab(Vector3(side_x, y_base + 2.5, z_pos), Vector3(side_w, 5.0, 0.6), true)
	_add_stone_slab(Vector3(0.0, y_base + 4.6, z_pos), Vector3(door_width + 0.4, 0.8, 0.6), true)

func _build_chamber_1() -> void:
	# Chamber 1: The Sluice Basin (Z = +6 to -17.0)
	_add_stone_slab(Vector3(0.0, -0.1, 2.5), Vector3(16.0, 0.2, 7.0), false) # Entrance terrace (-1.0 to +6.0)
	_add_stone_slab(Vector3(0.0, -0.1, -3.6), Vector3(3.4, 0.2, 5.2), false) # South central pier (-1.0 to -6.2)
	_add_stone_slab(Vector3(0.0, -0.1, -11.05), Vector3(3.4, 0.2, 3.3), false) # North central pier (-9.4 to -12.7)
	_add_stone_slab(Vector3(0.0, -1.55, -7.2), Vector3(16.0, 0.2, 12.6), false) # Sunken basin floor (top y=-1.45)
	_add_stone_slab(Vector3(0.0, -0.1, -14.8), Vector3(16.0, 0.2, 4.2), false) # North terrace (-12.7 to -16.9)
	_add_channel_guide(Vector3(0.0, -1.44, -7.8), Vector3(1.5, 0.02, 3.2))

	# Ramps descending from Entrance Terrace (y=0.0) into Sunken Basin (y=-1.45)
	_add_ramp_z(-5.5, 2.6, -1.02, 0.0, -4.4, -1.45)
	_add_ramp_z(5.5, 2.6, -1.02, 0.0, -4.4, -1.45)

	# Outer walls
	_add_stone_slab(Vector3(0.0, 2.5, 6.2), Vector3(16.6, 5.0, 0.6), true)
	_add_stone_slab(Vector3(-8.3, 2.5, -5.5), Vector3(0.6, 5.0, 23.8), true)
	_add_stone_slab(Vector3(8.3, 2.5, -5.5), Vector3(0.6, 5.0, 23.8), true)
	_add_wall_with_doorway(-17.1, 16.6, 0.0, 3.8)

	_sluice_gate = DOOR_SCENE.instantiate() as AncientDoor
	_sluice_gate.stays_open = false
	_sluice_gate.required_triggers = 1
	_sluice_gate.position = Vector3(0.0, 0.0, -17.1)
	add_child(_sluice_gate)

	_water_1 = WATER_SCENE.instantiate() as CisternWater
	_water_1.pool_size = Vector2(15.6, 11.4)
	_water_1.low_y = -1.42
	_water_1.high_y = -0.18
	_water_1.starts_high = false
	_water_1.position = Vector3(0.0, 0.0, -7.0)
	add_child(_water_1)

	# Floodgate lever on West entrance wall -> raises _water_1, floating crates up to y=0.0 bridge!
	var flood_lever_1 := LEVER_SCENE.instantiate() as WallLever
	flood_lever_1.is_one_shot = false
	flood_lever_1.position = Vector3(-7.95, 0.85, 1.5)
	flood_lever_1.rotation.y = deg_to_rad(90.0)
	add_child(flood_lever_1)
	flood_lever_1.targets = [flood_lever_1.get_path_to(_water_1)]

	# Three wooden crates in the drained basin bridging the 3.2m central gap (Z=-6.2..-9.4)
	for crate_pos in [
		Vector3(-2.6, -1.40, -6.8),
		Vector3(2.6, -1.40, -7.8),
		Vector3(-2.4, -1.40, -8.8),
	]:
		var blk := BLOCK_SCENE.instantiate() as PushableBlock
		blk.position = crate_pos
		add_child(blk)

	var sluice_lever := LEVER_SCENE.instantiate() as WallLever
	sluice_lever.is_one_shot = false
	sluice_lever.position = Vector3(-7.95, 0.85, -14.8)
	sluice_lever.rotation.y = deg_to_rad(90.0)
	add_child(sluice_lever)
	sluice_lever.targets = [sluice_lever.get_path_to(_sluice_gate)]

	for ux in [-6.5, 6.5]:
		var urn := URN_SCENE.instantiate()
		urn.position = Vector3(ux, 0.0, 4.4)
		add_child(urn)

func _build_chamber_2() -> void:
	# Chamber 2: Twin Lock Reservoir (Z = -17.4 to -38.0, X = -11 to +11)
	_add_stone_slab(Vector3(0.0, -0.1, -19.6), Vector3(22.0, 0.2, 4.6), false) # South walkway
	_add_stone_slab(Vector3(-7.2, -1.55, -26.8), Vector3(7.6, 0.2, 10.6), false) # West basin floor
	_add_stone_slab(Vector3(7.2, -1.55, -26.8), Vector3(7.6, 0.2, 10.6), false) # East basin floor
	_add_stone_slab(Vector3(0.0, -0.1, -34.9), Vector3(22.0, 0.2, 6.2), false) # North walkway

	# West Lock piers (gap Z = -25.6 to -27.8 = 2.2m) & Canal retaining curbs
	_add_stone_slab(Vector3(-6.2, -0.1, -23.7), Vector3(2.8, 0.2, 3.8), false) # West South Pier
	_add_stone_slab(Vector3(-6.2, -0.1, -29.8), Vector3(2.8, 0.2, 4.0), false) # West North Pier
	_add_channel_guide(Vector3(-6.2, -1.44, -26.7), Vector3(1.5, 0.02, 2.2))
	_add_stone_slab(Vector3(-3.55, -0.80, -26.85), Vector3(0.3, 1.5, 10.2), false)
	_add_stone_slab(Vector3(3.55, -0.80, -26.85), Vector3(0.3, 1.5, 10.2), false)

	_add_ramp_z(-9.6, 2.4, -21.92, 0.0, -25.2, -1.45) # West ramp
	_add_ramp_z(9.4, 2.4, -21.92, 0.0, -25.2, -1.45) # East ramp

	_add_stone_slab(Vector3(-11.3, 2.5, -27.6), Vector3(0.6, 5.0, 21.2), true)
	_add_stone_slab(Vector3(11.3, 2.5, -27.6), Vector3(0.6, 5.0, 21.2), true)
	_add_stone_slab(Vector3(-9.6, 2.5, -17.1), Vector3(3.4, 5.0, 0.6), true)
	_add_stone_slab(Vector3(9.6, 2.5, -17.1), Vector3(3.4, 5.0, 0.6), true)
	_add_stone_slab(Vector3(-3.8, 2.5, -34.9), Vector3(0.6, 5.0, 6.2), true) # North-West Alcove divider
	_add_wall_with_doorway(-38.1, 22.6, 0.0, 3.8)

	_reservoir_gate = DOOR_SCENE.instantiate() as AncientDoor
	_reservoir_gate.stays_open = false
	_reservoir_gate.required_triggers = 2
	_reservoir_gate.position = Vector3(0.0, 0.0, -38.1)
	add_child(_reservoir_gate)

	# Central Canal Moving Stone Ferry + Recessed Spike Pit
	var canal_pit := SPIKE_PIT_SCENE.instantiate() as SpikePit
	canal_pit.pit_size = Vector2(6.8, 10.1)
	canal_pit.pit_depth = 2.6
	canal_pit.position = Vector3(0.0, 0.0, -26.85)
	add_child(canal_pit)

	var ferry := RAFT_SCENE.instantiate() as MovingPlatform
	ferry.platform_size = Vector3(3.2, 0.34, 3.2)
	ferry.travel_offset = Vector3(0.0, 0.0, -7.2)
	ferry.travel_duration = 3.0
	ferry.pause_duration = 0.8
	ferry.position = Vector3(0.0, -0.17, -23.2)
	add_child(ferry)

	# West Basin (starts drained -> push 2 crates into West channel -> flood to float bridge -> pull NW Alcove lever)
	_water_w = WATER_SCENE.instantiate() as CisternWater
	_water_w.pool_size = Vector2(7.2, 9.8)
	_water_w.low_y = -1.42
	_water_w.high_y = -0.18
	_water_w.starts_high = false
	_water_w.position = Vector3(-7.3, 0.0, -26.8)
	add_child(_water_w)

	var lever_w := LEVER_SCENE.instantiate() as WallLever
	lever_w.is_one_shot = false
	lever_w.position = Vector3(-10.95, 0.85, -19.8)
	lever_w.rotation.y = deg_to_rad(90.0)
	add_child(lever_w)
	lever_w.targets = [lever_w.get_path_to(_water_w)]

	for w_crate in [
		Vector3(-8.4, -1.40, -26.2),
		Vector3(-5.0, -1.40, -27.3),
	]:
		var block_w := BLOCK_SCENE.instantiate() as PushableBlock
		block_w.position = w_crate
		add_child(block_w)

	var nw_gate_lever := LEVER_SCENE.instantiate() as WallLever
	nw_gate_lever.is_one_shot = false
	nw_gate_lever.position = Vector3(-10.95, 0.85, -35.0)
	nw_gate_lever.rotation.y = deg_to_rad(90.0)
	add_child(nw_gate_lever)
	nw_gate_lever.targets = [nw_gate_lever.get_path_to(_reservoir_gate)]
	nw_gate_lever.toggled.connect(func(_s): _refresh_objective())

	# East Basin (starts flooded -> pull lever ONCE to drain -> collect Scarab #3 & weight East sunken plate!)
	_water_e = WATER_SCENE.instantiate() as CisternWater
	_water_e.pool_size = Vector2(7.2, 9.8)
	_water_e.low_y = -1.42
	_water_e.high_y = -0.18
	_water_e.starts_high = true
	_water_e.position = Vector3(7.3, 0.0, -26.8)
	add_child(_water_e)

	var lever_e := LEVER_SCENE.instantiate() as WallLever
	lever_e.is_one_shot = false
	lever_e.position = Vector3(10.95, 0.85, -19.8)
	lever_e.rotation.y = deg_to_rad(-90.0)
	add_child(lever_e)
	lever_e.targets = [lever_e.get_path_to(_water_e)]

	var block_e := BLOCK_SCENE.instantiate() as PushableBlock
	block_e.position = Vector3(5.6, -1.40, -26.8)
	add_child(block_e)

	var east_plate := PLATE_SCENE.instantiate() as PressurePlate
	east_plate.is_permanent = false
	east_plate.position = Vector3(7.4, -1.45, -29.5)
	add_child(east_plate)
	_reservoir_gate.pressure_plates = [_reservoir_gate.get_path_to(east_plate)]
	east_plate.state_changed.connect(_reservoir_gate._on_plate_state_changed)
	east_plate.state_changed.connect(func(_a): _refresh_objective())
	_reservoir_gate._evaluate_door_state()

	for px in [-9.8, 9.8]:
		var p := PILLAR_SCENE.instantiate()
		p.position = Vector3(px, 0.0, -34.5)
		add_child(p)

func _build_chamber_3() -> void:
	# Chamber 3: Rising Flood-Tide Escape (Z = -38.4 to -71.8, terraced from y=0.0 up to y=2.10)
	_add_stone_slab(Vector3(0.0, -0.1, -42.3), Vector3(18.0, 0.2, 7.8), false) # Tier 0 (y=0.0, Z=-38.4..-46.2)
	_add_ramp_z(4.5, 3.4, -46.2, 0.0, -49.18, 0.70) # Ramp Tier 0 -> Tier 1
	_add_stone_slab(Vector3(0.0, 0.60, -52.5), Vector3(18.0, 0.2, 6.6), false) # Tier 1 (y=0.70, Z=-49.2..-55.8)
	_add_ramp_z(-4.5, 3.4, -55.8, 0.70, -58.78, 1.40) # Ramp Tier 1 -> Tier 2
	_add_stone_slab(Vector3(0.0, 1.30, -61.0), Vector3(18.0, 0.2, 4.4), false) # Tier 2 (y=1.40, Z=-58.8..-63.2)
	_add_ramp_z(0.0, 3.6, -63.0, 1.40, -64.98, 2.10) # Ramp Tier 2 -> Exit Sanctum
	_add_stone_slab(Vector3(0.0, 2.00, -68.6), Vector3(12.0, 0.2, 6.4), false) # Exit Sanctum (y=2.10, Z=-65.4..-71.8)

	# Outer walls enclosing Chamber 3 + Exit Sanctum
	_add_stone_slab(Vector3(-9.3, 3.2, -51.0), Vector3(0.6, 6.6, 25.4), true)
	_add_stone_slab(Vector3(9.3, 3.2, -51.0), Vector3(0.6, 6.6, 25.4), true)
	_add_stone_slab(Vector3(-6.3, 4.5, -68.8), Vector3(0.6, 5.0, 6.2), true)
	_add_stone_slab(Vector3(6.3, 4.5, -68.8), Vector3(0.6, 5.0, 6.2), true)
	_add_stone_slab(Vector3(0.0, 4.5, -72.0), Vector3(13.2, 5.0, 0.6), true)
	_add_wall_with_doorway(-65.8, 18.6, 2.1, 3.8)

	# Recessed spike pit strips beneath the inter-tier ramp gaps (X = -9..+9)
	for gap_spec in [
		{"pos": Vector3(0.0, 0.0, -47.7), "size": Vector2(18.0, 3.2)},
		{"pos": Vector3(0.0, 0.0, -57.3), "size": Vector2(18.0, 3.2)},
		{"pos": Vector3(0.0, 0.0, -64.5), "size": Vector2(18.0, 2.8)},
	]:
		var gap_pit := SPIKE_PIT_SCENE.instantiate() as SpikePit
		gap_pit.pit_size = gap_spec["size"]
		gap_pit.pit_depth = 2.4
		gap_pit.position = gap_spec["pos"]
		add_child(gap_pit)

	_escape_gate = DOOR_SCENE.instantiate() as AncientDoor
	_escape_gate.stays_open = false
	_escape_gate.required_triggers = 1
	_escape_gate.position = Vector3(0.0, 2.1, -65.8)
	add_child(_escape_gate)

	_escape_water = WATER_SCENE.instantiate() as CisternWater
	_escape_water.pool_size = Vector2(18.0, 27.0)
	_escape_water.low_y = -0.65
	_escape_water.high_y = 1.92
	_escape_water.is_rising_hazard = true
	_escape_water.rise_speed = 0.15
	_escape_water.max_hazard_y = 1.92
	_escape_water.position = Vector3(0.0, 0.0, -52.0)
	add_child(_escape_water)

	# Muddy quicksand patch on Tier 0 West + speed conveyor across Tier 1
	var qs_mud := QUICKSAND_SCENE.instantiate() as QuicksandPit
	qs_mud.pit_size = Vector3(4.2, 0.4, 3.8)
	qs_mud.position = Vector3(-4.2, 0.0, -43.0)
	add_child(qs_mud)

	var boost_conv := CONVEYOR_SCENE.instantiate() as ConveyorFloor
	boost_conv.belt_size = Vector3(8.0, 0.16, 2.6)
	boost_conv.belt_direction = Vector3(-1.0, 0.0, 0.0)
	boost_conv.belt_speed = 2.3
	boost_conv.position = Vector3(0.0, 0.64, -52.5)
	add_child(boost_conv)

	# Pulling FloodReleaseLever opens EscapeGate AND unleashes the Rising Flood-Tide!
	var flood_release_lever := LEVER_SCENE.instantiate() as WallLever
	flood_release_lever.is_one_shot = false
	flood_release_lever.position = Vector3(-8.95, 0.85, -40.5)
	flood_release_lever.rotation.y = deg_to_rad(90.0)
	add_child(flood_release_lever)
	flood_release_lever.targets = [
		flood_release_lever.get_path_to(_escape_gate),
		flood_release_lever.get_path_to(_escape_water),
	]
	flood_release_lever.toggled.connect(func(on: bool):
		if on:
			_flood_started = true
			for cam in get_tree().get_nodes_in_group("coop_camera"):
				if cam.has_method("trigger_shake"):
					cam.trigger_shake(0.14, 0.55)
			_refresh_objective()
	)

func get_room_respawn_pos(from_pos: Vector3) -> Vector3:
	if from_pos.z < -38.1 and is_instance_valid(_escape_water):
		var wy := _escape_water.current_water_y
		if wy < 0.0:
			return Vector3(0.0, 0.25, -40.5)
		elif wy < 0.65:
			return Vector3(4.5, 0.85, -50.5)
		elif wy < 1.35:
			return Vector3(-4.5, 1.55, -60.5)
		else:
			return Vector3(0.0, 2.25, -67.2)
	return super.get_room_respawn_pos(from_pos)

func _physics_process(_delta: float) -> void:
	# Advance checkpoint up the terraces so flood respawns never drop players below safe water height
	for p in players.values():
		if is_instance_valid(p) and p.current_health > 0:
			if p.global_position.y >= 1.35 and latest_checkpoint_pos.y < 1.35:
				latest_checkpoint_pos = Vector3(-4.5, 1.45, -60.5)
			elif p.global_position.y >= 0.65 and latest_checkpoint_pos.y < 0.65:
				latest_checkpoint_pos = Vector3(4.5, 0.75, -50.5)

func _refresh_objective() -> void:
	if not is_instance_valid(hud):
		return
	if _flood_started:
		hud.set_objective("Level 5: 🌊 FLOOD TIDE RISING! Climb the cistern terraces to the summit portal!")
	elif is_instance_valid(_reservoir_gate) and _reservoir_gate.is_open:
		hud.set_objective("Level 5: Pull the floodgate release lever in the final chamber to unseal the summit gate!")
	elif is_instance_valid(_sluice_gate) and _sluice_gate.is_open:
		hud.set_objective("Level 5: Flood West to bridge to the alcove lever, drain East to weight the sunken plate, then ride the ferry!")
	else:
		hud.set_objective("Level 5: Push the 3 crates into the center channel, flood the basin to float your bridge, and pull the north sluice lever!")
