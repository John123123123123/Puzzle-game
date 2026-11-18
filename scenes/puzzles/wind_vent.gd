extends Node3D
class_name WindVent
## Wall vent that blows periodic or continuous wind gusts along -Z, extinguishing carried Torches unless blocked by a crate.

@export var continuous: bool = false
@export var on_duration: float = 2.4
@export var off_duration: float = 2.0
@export var gust_length: float = 6.5
@export var gust_width: float = 1.6
@export var start_delay: float = 0.0

var is_blowing: bool = true
var _timer: float = 0.0
var _ray_query: PhysicsRayQueryParameters3D

var _gust_mesh: MeshInstance3D
var _gust_mat: StandardMaterial3D
var _rune_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("wind_vent")
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1 # Environment / Crates
	_ray_query.collide_with_areas = false
	_ray_query.collide_with_bodies = true
	_ray_query.exclude = [self]

	_build_visuals()

	if continuous:
		is_blowing = true
	elif start_delay > 0.0:
		is_blowing = false
		_timer = start_delay
	else:
		is_blowing = true
		_timer = on_duration
	_update_visual_state()

func _build_visuals() -> void:
	var housing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.0, 0.45)
	housing.mesh = box
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.36, 0.34, 0.32)
	stone_mat.roughness = 0.85
	housing.material_override = stone_mat
	housing.position = Vector3(0.0, 0.7, 0.0)
	add_child(housing)

	var nozzle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.36
	cyl.bottom_radius = 0.42
	cyl.height = 0.25
	nozzle.mesh = cyl
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.45, 0.85, 1.0)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.35, 0.8, 1.0)
	_rune_mat.emission_energy_multiplier = 0.8
	nozzle.material_override = _rune_mat
	nozzle.rotation.x = deg_to_rad(90.0)
	nozzle.position = Vector3(0.0, 0.7, -0.25)
	add_child(nozzle)

	_gust_mesh = MeshInstance3D.new()
	var gust_box := BoxMesh.new()
	gust_box.size = Vector3(gust_width * 0.7, 0.85, 1.0)
	_gust_mesh.mesh = gust_box
	_gust_mat = StandardMaterial3D.new()
	_gust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gust_mat.albedo_color = Color(0.7, 0.92, 1.0, 0.22)
	_gust_mesh.material_override = _gust_mat
	_gust_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gust_mesh)

func _physics_process(delta: float) -> void:
	if not continuous:
		_timer -= delta
		if _timer <= 0.0:
			is_blowing = not is_blowing
			_timer = on_duration if is_blowing else off_duration
			_update_visual_state()

	if not is_blowing:
		return

	var forward := (-global_basis.z).normalized()
	var origin := global_position + Vector3(0.0, 0.7, 0.0) + forward * 0.35
	var max_dist := gust_length

	_ray_query.from = origin
	_ray_query.to = origin + forward * gust_length
	var space := get_world_3d().direct_space_state
	if space:
		var hit := space.intersect_ray(_ray_query)
		if hit:
			max_dist = origin.distance_to(hit.position)

	if is_instance_valid(_gust_mesh):
		_gust_mesh.visible = max_dist > 0.2
		_gust_mesh.scale = Vector3(1.0, 1.0, maxf(0.1, max_dist))
		_gust_mesh.position = Vector3(0.0, 0.7, -0.35 - max_dist * 0.5)
		_gust_mat.albedo_color.a = 0.16 + 0.08 * sin(Time.get_ticks_msec() * 0.015)

	# Check if any player carrying a lit Torch is inside the unblocked gust
	for p in get_tree().get_nodes_in_group("player"):
		var player := p as Player
		if player == null or player.current_health <= 0:
			continue
		var torch := player.carried_item as Torch
		if torch == null or not torch.is_lit:
			continue
		var rel: Vector3 = player.global_position - origin
		var along: float = rel.dot(forward)
		if along >= -0.2 and along <= max_dist:
			var lateral: Vector3 = rel - forward * along
			lateral.y = 0.0
			if lateral.length() <= gust_width * 0.55:
				torch.extinguish()
				if is_instance_valid(AudioManager):
					AudioManager.play_sfx_3d(&"dart_launch", player.global_position, 0.75, 0.9, -6.0, 18.0, 5.0)

func _update_visual_state() -> void:
	if is_instance_valid(_gust_mesh):
		_gust_mesh.visible = is_blowing
	if is_instance_valid(_rune_mat):
		_rune_mat.emission_energy_multiplier = 1.0 if is_blowing else 0.15
