extends Node3D
class_name WhipEffect

const SEGMENTS: int = 18
const SIDES: int = 6

@onready var mesh: MeshInstance3D = $MeshInstance3D

var _imm_mesh: ImmediateMesh
var _mat: StandardMaterial3D
var _spark: MeshInstance3D
var _spark_mat: StandardMaterial3D

var _local_to: Vector3 = Vector3.FORWARD * 4.0
var _right: Vector3 = Vector3.RIGHT
var _up: Vector3 = Vector3.UP
var _duration: float = 0.22
var _elapsed: float = 0.0
var _active: bool = false
var _spark_triggered: bool = false

func lash(from: Vector3, to: Vector3, duration: float = 0.22) -> void:
	global_position = from
	rotation = Vector3.ZERO
	scale = Vector3.ONE

	_local_to = to - from
	var dist := _local_to.length()
	if dist < 0.05:
		_local_to = Vector3.FORWARD * 0.5
		dist = 0.5

	var dir := _local_to / dist
	_right = dir.cross(Vector3.UP)
	if _right.length_squared() < 0.001:
		_right = dir.cross(Vector3.RIGHT)
	_right = _right.normalized()
	_up = _right.cross(dir).normalized()

	_duration = maxf(0.06, duration)
	_elapsed = 0.0
	_spark_triggered = false
	_active = true

	_imm_mesh = ImmediateMesh.new()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.32, 0.17, 0.08, 1.0)
	_mat.roughness = 0.72
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.transform = Transform3D.IDENTITY
	mesh.mesh = _imm_mesh
	mesh.material_override = _mat

	_setup_spark()
	_rebuild_whip(0.02)

func _setup_spark() -> void:
	_spark = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	_spark.mesh = sphere

	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.albedo_color = Color(1.0, 0.92, 0.6, 0.0)
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark.material_override = _spark_mat
	_spark.position = _local_to
	_spark.visible = false
	add_child(_spark)

func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)

	if not _spark_triggered and progress >= 0.38:
		_spark_triggered = true
		if is_instance_valid(_spark):
			_spark.visible = true
			_spark.scale = Vector3.ONE * 1.25
			_spark_mat.albedo_color.a = 0.95

	if _spark_triggered and is_instance_valid(_spark) and _spark.visible:
		var spark_t := clampf((progress - 0.38) / 0.25, 0.0, 1.0)
		_spark_mat.albedo_color.a = (1.0 - spark_t) * 0.95
		_spark.scale = Vector3.ONE * lerpf(1.25, 0.2, spark_t)
		if spark_t >= 1.0:
			_spark.visible = false

	_rebuild_whip(progress)

	if progress >= 1.0:
		_active = false
		queue_free()

func _rebuild_whip(progress: float) -> void:
	if _imm_mesh == null:
		return
	_imm_mesh.clear_surfaces()

	var extend_raw := clampf(progress / 0.40, 0.0, 1.0)
	var extend := 1.0 - pow(1.0 - extend_raw, 2.0)

	var alpha := 1.0
	if progress > 0.48:
		alpha = clampf(1.0 - (progress - 0.48) / 0.52, 0.0, 1.0)
	_mat.albedo_color.a = alpha

	var points: Array[Vector3] = []
	var radii: Array[float] = []
	points.resize(SEGMENTS + 1)
	radii.resize(SEGMENTS + 1)

	var wave_strength := 1.0 - clampf((progress - 0.35) / 0.65, 0.0, 1.0)
	var sag := clampf((progress - 0.40) / 0.60, 0.0, 1.0)

	for i in range(SEGMENTS + 1):
		var u := float(i) / float(SEGMENTS)
		var base_p := _local_to * (u * extend)
		var env := sin(u * PI)
		var phase := u * 7.5 - progress * 24.0
		var side_offset := _right * (sin(phase) * 0.26 * env * wave_strength)
		var arch_offset := _up * ((cos(phase * 0.85) * 0.16 + 0.10) * env * wave_strength - 0.14 * env * sag)
		points[i] = base_p + side_offset + arch_offset
		radii[i] = lerpf(0.036, 0.006, pow(u, 0.85))

	_imm_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for i in range(SEGMENTS):
		var p0 := points[i]
		var p1 := points[i + 1]
		var r0 := radii[i]
		var r1 := radii[i + 1]

		var seg_dir := (p1 - p0)
		if seg_dir.length_squared() < 0.000001:
			seg_dir = _local_to.normalized()
		else:
			seg_dir = seg_dir.normalized()

		var seg_right := seg_dir.cross(_up)
		if seg_right.length_squared() < 0.0001:
			seg_right = _right
		else:
			seg_right = seg_right.normalized()
		var seg_up := seg_right.cross(seg_dir).normalized()

		for s in range(SIDES):
			var a0 := (float(s) / float(SIDES)) * TAU
			var a1 := (float(s + 1) / float(SIDES)) * TAU
			var n0 := (seg_right * cos(a0) + seg_up * sin(a0)).normalized()
			var n1 := (seg_right * cos(a1) + seg_up * sin(a1)).normalized()

			var v00 := p0 + n0 * r0
			var v01 := p0 + n1 * r0
			var v10 := p1 + n0 * r1
			var v11 := p1 + n1 * r1

			_imm_mesh.surface_set_normal(n0)
			_imm_mesh.surface_add_vertex(v00)
			_imm_mesh.surface_set_normal(n1)
			_imm_mesh.surface_add_vertex(v01)
			_imm_mesh.surface_set_normal(n1)
			_imm_mesh.surface_add_vertex(v11)

			_imm_mesh.surface_set_normal(n0)
			_imm_mesh.surface_add_vertex(v00)
			_imm_mesh.surface_set_normal(n1)
			_imm_mesh.surface_add_vertex(v11)
			_imm_mesh.surface_set_normal(n0)
			_imm_mesh.surface_add_vertex(v10)

	_imm_mesh.surface_end()
