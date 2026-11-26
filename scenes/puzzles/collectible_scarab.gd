extends Area3D
class_name CollectibleScarab

signal collected(scarab: CollectibleScarab)

var is_collected: bool = false
var _bob_time: float = 0.0
var _base_y: float = 0.0

@onready var mesh_root: Node3D = $MeshRoot
@onready var scarab_body: Node3D = get_node_or_null("MeshRoot/ScarabBody")
@onready var glow_light: OmniLight3D = $OmniLight3D
@onready var wing_l: Node3D = get_node_or_null("MeshRoot/ScarabBody/WingL")
@onready var wing_r: Node3D = get_node_or_null("MeshRoot/ScarabBody/WingR")
@onready var outer_halo: Node3D = get_node_or_null("MeshRoot/OuterHalo")
@onready var inner_halo: Node3D = get_node_or_null("MeshRoot/InnerHalo")
@onready var sun_corona: MeshInstance3D = get_node_or_null("MeshRoot/ScarabBody/SunOrbCorona")
@onready var sparkles: CPUParticles3D = get_node_or_null("SparkleParticles")

func _ready() -> void:
	add_to_group("collectible_scarab")
	_base_y = mesh_root.position.y
	_bob_time = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	_bob_time += delta * 2.8
	if is_instance_valid(mesh_root):
		mesh_root.rotation.y += delta * 1.35
		mesh_root.position.y = _base_y + sin(_bob_time) * 0.11
	if is_instance_valid(scarab_body):
		scarab_body.rotation.x = deg_to_rad(18.0) + sin(_bob_time * 1.3) * 0.06
		scarab_body.rotation.z = cos(_bob_time * 0.9) * 0.05

	var wing_flap := sin(_bob_time * 3.6) * 0.24
	var wing_sweep := cos(_bob_time * 3.6) * 0.09
	if is_instance_valid(wing_l):
		wing_l.rotation.z = 0.22 + wing_flap
		wing_l.rotation.y = wing_sweep
	if is_instance_valid(wing_r):
		wing_r.rotation.z = -0.22 - wing_flap
		wing_r.rotation.y = -wing_sweep

	if is_instance_valid(outer_halo):
		outer_halo.rotation.y -= delta * 0.85
		outer_halo.rotation.x = sin(_bob_time * 0.7) * 0.14
	if is_instance_valid(inner_halo):
		inner_halo.rotation.y += delta * 1.65
		inner_halo.rotation.z = deg_to_rad(28.0) + cos(_bob_time * 0.85) * 0.12

	if is_instance_valid(sun_corona):
		var c_scale := 1.0 + sin(_bob_time * 2.8) * 0.14
		sun_corona.scale = Vector3.ONE * c_scale
	if is_instance_valid(glow_light):
		glow_light.light_energy = 1.85 + sin(_bob_time * 2.2) * 0.35

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not (body is Player):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_collect.rpc()
	else:
		_do_collect()

@rpc("authority", "call_local", "reliable")
func _rpc_collect() -> void:
	_do_collect()

func _do_collect() -> void:
	if is_collected:
		return
	is_collected = true
	collected.emit(self)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_2d(&"scarab_pickup", 0.98, 1.04, -8.0)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_scarab_collected"):
		hud.register_scarab_collected()

	if is_instance_valid(sparkles):
		sparkles.emitting = false

	_spawn_collect_burst()
	_spawn_pickup_popup()

	var tween := create_tween().set_parallel(true)
	if is_instance_valid(mesh_root):
		tween.tween_property(mesh_root, "position:y", _base_y + 1.15, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh_root, "rotation:y", mesh_root.rotation.y + TAU * 1.4, 0.34)
		tween.tween_property(mesh_root, "scale", Vector3.ZERO, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if is_instance_valid(glow_light):
		tween.tween_property(glow_light, "light_energy", 0.0, 0.34)
	tween.chain().tween_callback(queue_free)

func _spawn_collect_burst() -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return

	var burst_root := Node3D.new()
	parent_node.add_child(burst_root)
	burst_root.global_position = global_position + Vector3(0.0, 0.62, 0.0)

	# Expanding additive golden-cyan shockwave ring
	var ring_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.31
	torus.rings = 24
	torus.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.32, 0.94, 1.0, 0.92)
	torus.material = ring_mat
	ring_inst.mesh = torus
	ring_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_inst.scale = Vector3(0.3, 0.3, 0.3)
	burst_root.add_child(ring_inst)

	var ring_tw := ring_inst.create_tween().set_parallel(true)
	ring_tw.tween_property(ring_inst, "scale", Vector3(2.3, 2.3, 2.3), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.42)

	# Burst of 14 alternating gold and turquoise jewel sparks
	var gold_mat := StandardMaterial3D.new()
	gold_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold_mat.albedo_color = Color(1.0, 0.85, 0.25, 1.0)

	var cyan_mat := StandardMaterial3D.new()
	cyan_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyan_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_mat.albedo_color = Color(0.20, 0.96, 1.0, 1.0)

	var gem_mesh_gold := BoxMesh.new()
	gem_mesh_gold.size = Vector3(0.055, 0.055, 0.055)
	gem_mesh_gold.material = gold_mat

	var gem_mesh_cyan := BoxMesh.new()
	gem_mesh_cyan.size = Vector3(0.055, 0.055, 0.055)
	gem_mesh_cyan.material = cyan_mat

	for i in range(14):
		var sp := MeshInstance3D.new()
		sp.mesh = gem_mesh_gold if (i % 2 == 0) else gem_mesh_cyan
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst_root.add_child(sp)
		var angle := (float(i) / 14.0) * TAU + randf_range(-0.2, 0.2)
		var out_dist := randf_range(0.65, 1.15)
		var target_offset := Vector3(cos(angle) * out_dist, randf_range(0.25, 0.95), sin(angle) * out_dist)
		var sp_tw := sp.create_tween().set_parallel(true)
		sp_tw.tween_property(sp, "position", target_offset, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sp_tw.tween_property(sp, "rotation", Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI)), 0.50)
		sp_tw.tween_property(sp, "scale", Vector3.ZERO, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var cleanup_tw := burst_root.create_tween()
	cleanup_tw.tween_interval(0.55)
	cleanup_tw.tween_callback(burst_root.queue_free)

func _spawn_pickup_popup() -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	var lbl := Label3D.new()
	lbl.text = "🪲 +1 SCARAB!"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.modulate = Color(0.35, 0.95, 1.0, 1.0)
	parent_node.add_child(lbl)
	lbl.global_position = global_position + Vector3(0, 1.1, 0)

	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 0.95, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)
