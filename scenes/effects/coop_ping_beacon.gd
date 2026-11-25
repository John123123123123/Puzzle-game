extends Node3D
class_name CoopPingBeacon
## Visual 3D beacon + expanding floor ring + floating callout spawned when a player pings a puzzle or location.

static func spawn(parent: Node, world_pos: Vector3, color: Color, message: String) -> Node3D:
	if not is_instance_valid(parent):
		return null

	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = world_pos

	# 1. Expanding glowing floor ring
	var ring_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.38
	torus.rings = 20
	torus.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.92)
	torus.material = ring_mat
	ring_inst.mesh = torus
	ring_inst.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(ring_inst)

	# 2. Translucent vertical light beam
	var beam_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.16
	cyl.height = 2.8
	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.42)
	cyl.material = beam_mat
	beam_inst.mesh = cyl
	beam_inst.position = Vector3(0.0, 1.4, 0.0)
	root.add_child(beam_inst)

	# 3. Point light flash
	var p_light := OmniLight3D.new()
	p_light.light_color = color.lightened(0.25)
	p_light.light_energy = 2.4
	p_light.omni_range = 4.2
	p_light.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(p_light)

	# 4. Floating callout label
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 34
	lbl.outline_size = 9
	lbl.modulate = color.lightened(0.35)
	lbl.text = message
	lbl.position = Vector3(0.0, 2.25, 0.0)
	root.add_child(lbl)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"coop_ping", world_pos, 0.97, 1.05, -2.0, 35.0, 8.0)

	# Animate ring pulse, bobbing callout, and graceful fade-out over 3.2s
	ring_inst.scale = Vector3(0.35, 1.0, 0.35)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(ring_inst, "scale", Vector3(2.4, 1.0, 2.4), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.18, 0.55)
	tw.tween_property(lbl, "position:y", 2.55, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(beam_mat, "albedo_color:a", 0.0, 3.0).set_delay(0.5)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 2.4).set_delay(0.6)
	tw.tween_property(p_light, "light_energy", 0.0, 2.6).set_delay(0.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(2.55)
	tw.chain().tween_callback(root.queue_free)
	return root
