extends StaticBody3D
class_name PhasePlatform

@export_enum("SolarGold", "LunarCyan") var active_phase: int = 0
@export_enum("Bridge", "ForcefieldGate") var platform_kind: int = 0
@export var box_size: Vector3 = Vector3(2.4, 0.28, 2.4)

@onready var solid_mesh: MeshInstance3D = $SolidMesh
@onready var trim_mesh: MeshInstance3D = $TrimMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var glow_light: OmniLight3D = $GlowLight

var _solid_mat: StandardMaterial3D = null
var _trim_mat: StandardMaterial3D = null
var is_solid: bool = true

const SOLAR_BASE := Color(0.72, 0.54, 0.18)
const SOLAR_GLOW := Color(1.0, 0.84, 0.25)
const LUNAR_BASE := Color(0.16, 0.48, 0.68)
const LUNAR_GLOW := Color(0.25, 0.90, 1.0)

func _ready() -> void:
	add_to_group("phase_platform")
	_configure_geometry()
	set_world_phase(0, false)

func _configure_geometry() -> void:
	if platform_kind == 1 and box_size == Vector3(2.4, 0.28, 2.4):
		box_size = Vector3(3.6, 3.0, 0.32)

	if is_instance_valid(collision_shape):
		var b_shape = BoxShape3D.new()
		b_shape.size = box_size
		collision_shape.shape = b_shape

	if is_instance_valid(solid_mesh):
		var b_mesh = BoxMesh.new()
		b_mesh.size = box_size
		_solid_mat = StandardMaterial3D.new()
		_solid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_solid_mat.metallic = 0.35
		_solid_mat.roughness = 0.45
		_solid_mat.emission_enabled = true
		b_mesh.material = _solid_mat
		solid_mesh.mesh = b_mesh

	if is_instance_valid(trim_mesh):
		var t_mesh = BoxMesh.new()
		t_mesh.size = box_size + Vector3(0.06, -0.04 if platform_kind == 0 else 0.04, 0.06)
		_trim_mat = StandardMaterial3D.new()
		_trim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		t_mesh.material = _trim_mat
		trim_mesh.mesh = t_mesh

func set_world_phase(world_phase: int, animate: bool) -> void:
	is_solid = (world_phase == active_phase)

	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", not is_solid)

	var base_col = SOLAR_BASE if active_phase == 0 else LUNAR_BASE
	var glow_col = SOLAR_GLOW if active_phase == 0 else LUNAR_GLOW

	var target_alpha: float
	if platform_kind == 1:
		target_alpha = 0.72 if is_solid else 0.10
	else:
		target_alpha = 1.0 if is_solid else 0.16

	var trim_alpha = 0.85 if is_solid else 0.24

	if _solid_mat:
		_solid_mat.albedo_color = Color(base_col.r, base_col.g, base_col.b, target_alpha)
		_solid_mat.emission = glow_col
		_solid_mat.emission_energy_multiplier = (1.6 if platform_kind == 1 else 0.65) if is_solid else 0.15

	if _trim_mat:
		_trim_mat.albedo_color = Color(glow_col.r, glow_col.g, glow_col.b, trim_alpha)

	if is_instance_valid(glow_light):
		glow_light.light_color = glow_col
		glow_light.light_energy = 1.4 if is_solid else 0.15

	if animate and is_instance_valid(solid_mesh):
		if is_solid:
			solid_mesh.scale = Vector3(0.88, 0.88, 0.88)
			var tw = create_tween()
			tw.tween_property(solid_mesh, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			solid_mesh.scale = Vector3.ONE
