extends Node3D
class_name SpikePit
## Recessed temple spike pit replacing endless chasm falls: renders a stone basin, metallic spear spikes,
## warm underglow, and teleports fallen players back to the start of the current room.

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")
const WALL_SHADER := preload("res://shaders/ancient_temple_wall.gdshader")

@export var pit_size: Vector2 = Vector2(8.0, 10.0)
@export var pit_depth: float = 2.4
@export var spike_spacing: float = 0.74
@export var spike_height: float = 1.05

@onready var pit_floor: StaticBody3D = $PitFloor
@onready var pit_floor_mesh: MeshInstance3D = $PitFloor/MeshInstance3D
@onready var pit_floor_col: CollisionShape3D = $PitFloor/CollisionShape3D
@onready var pit_walls: Node3D = $PitWalls
@onready var spikes_mm: MultiMeshInstance3D = $SpikesMultiMesh
@onready var pit_glow: OmniLight3D = $PitGlow
@onready var hazard_area: Area3D = $HazardArea
@onready var hazard_shape: CollisionShape3D = $HazardArea/CollisionShape3D

var _inside_players: Array[Player] = []
var _cooldowns: Dictionary = {} # instance_id -> float

func _ready() -> void:
	add_to_group("spike_pit")
	_configure_geometry()
	if is_instance_valid(hazard_area):
		hazard_area.body_entered.connect(_on_body_entered)
		hazard_area.body_exited.connect(_on_body_exited)

func _configure_geometry() -> void:
	var floor_y := -pit_depth
	if is_instance_valid(pit_floor):
		pit_floor.add_to_group("spike_pit_floor")
		pit_floor.position = Vector3(0.0, floor_y - 0.1, 0.0)

	var dark_stone_mat := StandardMaterial3D.new()
	dark_stone_mat.albedo_color = Color(0.08, 0.07, 0.08)
	dark_stone_mat.roughness = 0.94

	if is_instance_valid(pit_floor_mesh):
		var fm := BoxMesh.new()
		fm.size = Vector3(pit_size.x + 0.4, 0.2, pit_size.y + 0.4)
		fm.material = dark_stone_mat
		pit_floor_mesh.mesh = fm

	if is_instance_valid(pit_floor_col):
		var fs := BoxShape3D.new()
		fs.size = Vector3(pit_size.x + 0.4, 0.2, pit_size.y + 0.4)
		pit_floor_col.shape = fs

	# Visual-only carved dark chasm walls lining all 4 sides down from y = -0.08
	if is_instance_valid(pit_walls):
		for ch in pit_walls.get_children():
			ch.queue_free()
		var wall_mat := ShaderMaterial.new()
		wall_mat.shader = WALL_SHADER
		wall_mat.set_shader_parameter("wall_color", Color(0.16, 0.14, 0.16))
		wall_mat.set_shader_parameter("brick_dark", Color(0.09, 0.08, 0.10))
		wall_mat.set_shader_parameter("mortar_color", Color(0.04, 0.035, 0.045))
		wall_mat.set_shader_parameter("frieze_color", Color(0.28, 0.22, 0.14))

		var wall_h := pit_depth + 0.08
		var wall_mid_y := -wall_h * 0.5 - 0.06
		var ns_mesh := BoxMesh.new()
		ns_mesh.size = Vector3(pit_size.x + 0.36, wall_h, 0.22)
		ns_mesh.material = wall_mat
		for sz in [-1.0, 1.0]:
			var w_ns := MeshInstance3D.new()
			w_ns.mesh = ns_mesh
			w_ns.position = Vector3(0.0, wall_mid_y, sz * (pit_size.y * 0.5 + 0.11))
			pit_walls.add_child(w_ns)

		var ew_mesh := BoxMesh.new()
		ew_mesh.size = Vector3(0.22, wall_h, pit_size.y + 0.36)
		ew_mesh.material = wall_mat
		for sx in [-1.0, 1.0]:
			var w_ew := MeshInstance3D.new()
			w_ew.mesh = ew_mesh
			w_ew.position = Vector3(sx * (pit_size.x * 0.5 + 0.11), wall_mid_y, 0.0)
			pit_walls.add_child(w_ew)

	# Single-draw-call MultiMesh of 4-sided metallic spear spikes across the pit floor
	if is_instance_valid(spikes_mm):
		var spear_mat := StandardMaterial3D.new()
		spear_mat.albedo_color = Color(0.58, 0.60, 0.66)
		spear_mat.metallic = 0.90
		spear_mat.roughness = 0.24
		spear_mat.rim_enabled = true
		spear_mat.rim = 0.35

		var spear_mesh := CylinderMesh.new()
		spear_mesh.top_radius = 0.008
		spear_mesh.bottom_radius = 0.088
		spear_mesh.height = spike_height
		spear_mesh.radial_segments = 4
		spear_mesh.material = spear_mat

		var usable_x := maxf(0.4, pit_size.x - 0.50)
		var usable_z := maxf(0.4, pit_size.y - 0.50)
		var step := maxf(0.35, spike_spacing)
		var nx := maxi(1, int(floor(usable_x / step)) + 1)
		var nz := maxi(1, int(floor(usable_z / step)) + 1)

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = spear_mesh
		mm.instance_count = nx * nz

		var idx := 0
		var half_span_x := usable_x * 0.5
		var half_span_z := usable_z * 0.5
		for ix in range(nx):
			var fx := 0.0 if nx == 1 else (float(ix) / float(nx - 1) - 0.5) * 2.0 * half_span_x
			for iz in range(nz):
				var fz := 0.0 if nz == 1 else (float(iz) / float(nz - 1) - 0.5) * 2.0 * half_span_z
				# Deterministic per-spike hash variation for organic ancient trap cluster
				var h1 := fposmod(sin(float(ix * 73 + iz * 139) * 12.9898) * 43758.5453, 1.0)
				var h2 := fposmod(sin(float(ix * 197 + iz * 53) * 78.233) * 24634.6345, 1.0)
				var jx := (h1 - 0.5) * minf(0.16, step * 0.22)
				var jz := (h2 - 0.5) * minf(0.16, step * 0.22)
				var sy := 0.88 + h1 * 0.24
				var yaw := h2 * PI * 0.5
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3(1.0, sy, 1.0))
				var pos := Vector3(fx + jx, floor_y + (spike_height * sy) * 0.5 - 0.04, fz + jz)
				mm.set_instance_transform(idx, Transform3D(basis, pos))
				idx += 1
		spikes_mm.multimesh = mm

	if is_instance_valid(pit_glow):
		pit_glow.light_color = Color(0.88, 0.28, 0.14)
		pit_glow.light_energy = 1.15
		pit_glow.position = Vector3(0.0, floor_y + 0.95, 0.0)
		pit_glow.omni_range = maxf(6.5, maxf(pit_size.x, pit_size.y) * 0.65)

	if is_instance_valid(hazard_shape):
		var hs := BoxShape3D.new()
		var area_h := spike_height + 0.55
		hs.size = Vector3(maxf(0.5, pit_size.x - 0.08), area_h, maxf(0.5, pit_size.y - 0.08))
		hazard_shape.shape = hs
		hazard_shape.position = Vector3(0.0, floor_y + area_h * 0.5, 0.0)

func _on_body_entered(body: Node3D) -> void:
	if body is PushableBlock:
		var blk := body as PushableBlock
		if blk.grabbed_by == null and not blk.is_floating and blk.has_method("respawn_from_pit"):
			blk.respawn_from_pit()
	elif body is Player:
		var p := body as Player
		if not _inside_players.has(p):
			_inside_players.append(p)
		_trigger_player_pit(p)

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		_inside_players.erase(p)

func _physics_process(delta: float) -> void:
	for pid in _cooldowns.keys():
		var next_cd := float(_cooldowns[pid]) - delta
		if next_cd <= 0.0:
			_cooldowns.erase(pid)
		else:
			_cooldowns[pid] = next_cd

	for i in range(_inside_players.size() - 1, -1, -1):
		var p := _inside_players[i]
		if not is_instance_valid(p) or not p.is_inside_tree():
			_inside_players.remove_at(i)
			continue
		if p.current_health > 0 and not _cooldowns.has(p.get_instance_id()):
			_trigger_player_pit(p)

func _trigger_player_pit(p: Player) -> void:
	if not is_instance_valid(p) or p.current_health <= 0 or not p.is_local_controlled():
		return
	var pid := p.get_instance_id()
	if _cooldowns.has(pid):
		return
	_cooldowns[pid] = 0.85

	var impact_pos := p.global_position
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"spike_up", impact_pos, 0.9, 1.1, -2.0, 22.0, 5.0)

	var is_authority := not (is_instance_valid(NetworkManager) and NetworkManager.is_online) or NetworkManager.is_host
	if is_authority:
		p.take_damage(1)
	else:
		p._rpc_request_chasm_damage.rpc_id(1)

	if p.current_health > 0:
		var respawn_pos := Vector3(0.0, 0.4, 4.0)
		var lvl := _find_temple_level()
		if is_instance_valid(lvl) and lvl.has_method("get_room_respawn_pos"):
			respawn_pos = lvl.get_room_respawn_pos(impact_pos)
		elif is_instance_valid(lvl) and "latest_checkpoint_pos" in lvl:
			respawn_pos = lvl.latest_checkpoint_pos + Vector3(0.0, 0.3, 0.0)
		p.velocity = Vector3.ZERO
		p.global_position = respawn_pos
		if is_instance_valid(get_parent()):
			DUST_PUFF.spawn(get_parent(), impact_pos + Vector3(0.0, 0.25, 0.0), 4, 1.0)
			DUST_PUFF.spawn(get_parent(), respawn_pos, 4, 1.0)

func _find_temple_level() -> Node:
	var n: Node = get_parent()
	while is_instance_valid(n):
		if n.has_method("get_room_respawn_pos"):
			return n
		n = n.get_parent()
	if is_instance_valid(get_tree()) and is_instance_valid(get_tree().current_scene):
		return get_tree().current_scene
	return null
