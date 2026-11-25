extends Area3D
class_name EmeraldHeartPickup
## Physical glowing Emerald Heart relic dropped from smashed Ancient Urns when explorers are injured.
## Any injured teammate can walk over it to restore +1 HP!

var is_consumed: bool = false
var _bob_time: float = 0.0
var _visual_root: Node3D = null
var _glow_light: OmniLight3D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.72
	col.shape = sphere
	col.position = Vector3(0.0, 0.45, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.position = Vector3(0.0, 0.48, 0.0)
	add_child(_visual_root)

	# Glowing faceted emerald crystal heart (two angled capsules + gold band)
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.20, 0.95, 0.52, 0.95)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.18, 1.0, 0.48)
	gem_mat.emission_energy_multiplier = 2.2
	gem_mat.roughness = 0.15
	gem_mat.metallic = 0.35

	var lobe_mesh := CapsuleMesh.new()
	lobe_mesh.radius = 0.11
	lobe_mesh.height = 0.34
	lobe_mesh.material = gem_mat

	var lobe_l := MeshInstance3D.new()
	lobe_l.mesh = lobe_mesh
	lobe_l.position = Vector3(-0.065, 0.0, 0.0)
	lobe_l.rotation.z = deg_to_rad(32.0)
	_visual_root.add_child(lobe_l)

	var lobe_r := MeshInstance3D.new()
	lobe_r.mesh = lobe_mesh
	lobe_r.position = Vector3(0.065, 0.0, 0.0)
	lobe_r.rotation.z = deg_to_rad(-32.0)
	_visual_root.add_child(lobe_r)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.78, 0.22)
	ring_mat.metallic = 0.9
	ring_mat.roughness = 0.22
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.20
	halo_mesh.outer_radius = 0.235
	halo_mesh.material = ring_mat
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.rotation.x = deg_to_rad(90.0)
	_visual_root.add_child(halo)

	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(0.25, 1.0, 0.55)
	_glow_light.light_energy = 1.9
	_glow_light.omni_range = 3.2
	_glow_light.position = Vector3(0.0, 0.5, 0.0)
	add_child(_glow_light)

	# Pop-up arc animation on spawn
	_visual_root.scale = Vector3(0.2, 0.2, 0.2)
	var pop := create_tween().set_parallel(true)
	pop.tween_property(_visual_root, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_visual_root, "position:y", 0.78, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.chain().tween_property(_visual_root, "position:y", 0.48, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_consumed or not is_instance_valid(_visual_root):
		return
	_bob_time += delta * 3.0
	_visual_root.rotation.y += delta * 2.1
	if _bob_time > 1.2:
		_visual_root.position.y = 0.48 + sin(_bob_time) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if is_consumed or not (body is Player):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	var player := body as Player
	if player.current_health <= 0 or player.current_health >= player.max_health:
		return

	player.heal(1)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_consume.rpc()
	else:
		_do_consume()

@rpc("authority", "call_local", "reliable")
func _rpc_consume() -> void:
	_do_consume()

func _do_consume() -> void:
	if is_consumed:
		return
	is_consumed = true
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"heart_pickup", global_position, 0.97, 1.04, -2.0, 24.0, 5.5)

	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var lbl := Label3D.new()
		lbl.text = "+1 ❤️ RESTORED!"
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 38
		lbl.outline_size = 9
		lbl.modulate = Color(0.35, 1.0, 0.58)
		parent_node.add_child(lbl)
		lbl.global_position = global_position + Vector3(0.0, 1.05, 0.0)
		var tw := lbl.create_tween().set_parallel(true)
		tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 0.85, 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.70).set_delay(0.2)
		tw.chain().tween_callback(lbl.queue_free)

	queue_free()
