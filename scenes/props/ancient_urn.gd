extends StaticBody3D
class_name AncientUrn

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")

var is_smashed: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("whip_target")
	add_to_group("smashable_urn")

func get_interact_prompt() -> String:
	return "" if is_smashed else "Smash Urn"

func interact(player: Player) -> void:
	smash(player)

func on_whipped(player: Player) -> void:
	smash(player)

func smash(by_player: Player = null) -> void:
	if is_smashed:
		return
	is_smashed = true

	var parent_node := get_parent()
	var origin := global_position

	if is_instance_valid(parent_node):
		DUST_PUFF.spawn(parent_node, origin + Vector3(0, 0.35, 0), 5, 1.1)
		_spawn_clay_shards(parent_node, origin)
		_play_shatter_sound(parent_node, origin)

	if is_instance_valid(by_player) and by_player.current_health > 0 and by_player.current_health < by_player.max_health:
		if by_player.has_method("heal"):
			by_player.heal(1)

	queue_free()

func _spawn_clay_shards(parent_node: Node, origin: Vector3) -> void:
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.68, 0.38, 0.22)
	shard_mat.roughness = 0.85

	for i in range(7):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(0.09, 0.16), randf_range(0.04, 0.08), randf_range(0.09, 0.16))
		box.material = shard_mat
		shard.mesh = box
		parent_node.add_child(shard)

		var angle := (TAU / 7.0) * float(i) + randf_range(-0.25, 0.25)
		var dist := randf_range(0.45, 0.95)
		shard.global_position = origin + Vector3(0, 0.35, 0)
		shard.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		var target_pos := origin + Vector3(cos(angle) * dist, 0.04, sin(angle) * dist)
		var tw := shard.create_tween().set_parallel(true)
		tw.tween_property(shard, "global_position:x", target_pos.x, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "global_position:z", target_pos.z, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "global_position:y", target_pos.y, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "rotation", shard.rotation + Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), 0.0), 0.34)
		tw.chain().tween_interval(0.55)
		tw.chain().tween_property(shard, "scale", Vector3.ZERO, 0.22)
		tw.chain().tween_callback(shard.queue_free)

func _play_shatter_sound(parent_node: Node, origin: Vector3) -> void:
	var sample_rate := 22050
	var duration := 0.26
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 14.0)
		var ring1 := sin(t * 980.0 * TAU) * 0.35
		var ring2 := sin(t * 1460.0 * TAU) * 0.25
		var noise := rng.randf_range(-1.0, 1.0) * 0.55
		var sample := (ring1 + ring2 + noise) * env
		data[i] = int(clampi(int((clampf(sample, -1.0, 1.0) * 0.65 + 0.5) * 255.0), 0, 255))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data

	var p := AudioStreamPlayer3D.new()
	p.stream = wav
	p.unit_size = 6.0
	p.max_distance = 22.0
	p.pitch_scale = randf_range(0.92, 1.12)
	if AudioServer.get_bus_index("SFX") >= 0:
		p.bus = &"SFX"
	parent_node.add_child(p)
	p.global_position = origin
	p.finished.connect(p.queue_free)
	p.play()
