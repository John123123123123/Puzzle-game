extends Node3D
class_name DustPuff

static var _shared_mesh: SphereMesh = null

static func spawn(parent: Node, world_pos: Vector3, count: int = 3, scale_mul: float = 1.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.16
		_shared_mesh.height = 0.24
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.76, 0.68, 0.54, 0.55)
		mat.roughness = 1.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_mesh.material = mat

	var puffs: Array[MeshInstance3D] = []
	var tween := parent.create_tween().set_parallel(true)
	for i in range(count):
		var puff := MeshInstance3D.new()
		puff.mesh = _shared_mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.transparency = 0.25
		parent.add_child(puff)
		puff.global_position = world_pos + Vector3(randf_range(-0.22, 0.22), randf_range(0.02, 0.14), randf_range(-0.22, 0.22))
		puff.scale = Vector3.ONE * randf_range(0.6, 1.1) * scale_mul
		puffs.append(puff)

		var drift := Vector3(randf_range(-0.45, 0.45), randf_range(0.25, 0.65), randf_range(-0.45, 0.45))
		tween.tween_property(puff, "global_position", puff.global_position + drift, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", puff.scale * 1.8, 0.42)
		tween.tween_property(puff, "transparency", 1.0, 0.42)
	tween.chain().tween_callback(func():
		for p in puffs:
			if is_instance_valid(p):
				p.queue_free()
	)
