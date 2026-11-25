extends GPUParticles3D
class_name TempleDustMotes
## Subtle floating sunlit dust motes attached to CoopCamera so every chamber has atmospheric depth.

func _ready() -> void:
	amount = 56
	lifetime = 5.5
	preprocess = 2.0
	randomness = 0.4
	visibility_aabb = AABB(Vector3(-18, -6, -18), Vector3(36, 16, 36))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(13.0, 4.5, 13.0)
	proc.direction = Vector3(0.3, 0.25, 0.2)
	proc.spread = 180.0
	proc.initial_velocity_min = 0.08
	proc.initial_velocity_max = 0.26
	proc.gravity = Vector3(0.0, 0.03, 0.0)
	proc.scale_min = 0.65
	proc.scale_max = 1.45

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.90, 0.62, 0.0),
		Color(1.0, 0.90, 0.62, 0.42),
		Color(1.0, 0.84, 0.50, 0.36),
		Color(1.0, 0.80, 0.45, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	proc.color_ramp = ramp
	process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.92, 0.68, 0.85)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	quad.material = mat
	draw_pass_1 = quad
	emitting = true
