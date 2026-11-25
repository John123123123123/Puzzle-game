extends StaticBody3D
class_name AncientUrn

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")
const EMERALD_HEART := preload("res://scenes/props/emerald_heart_pickup.gd")

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
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		_rpc_request_smash.rpc_id(1, by_player.player_id if is_instance_valid(by_player) else 0)
		return

	var drop_kind := _choose_drop_kind()
	var drop_name := "HeartDrop_%s" % name
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_smash.rpc(drop_kind, drop_name)
	_do_smash(by_player, drop_kind, drop_name)

func _choose_drop_kind() -> int:
	# Drop an Emerald Heart pickup whenever any explorer in the party is missing health (or 30% bonus chance)
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.current_health > 0 and p.current_health < p.max_health:
			return 1
	return 1 if randf() < 0.30 else 2

@rpc("any_peer", "reliable")
func _rpc_request_smash(pid: int) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_host or is_smashed:
		return
	var p_node: Player = null
	var lvl := get_tree().current_scene
	if is_instance_valid(lvl) and "players" in lvl and lvl.players.has(pid):
		p_node = lvl.players[pid]
	smash(p_node)

@rpc("authority", "reliable")
func _rpc_sync_smash(drop_kind: int, drop_name: String) -> void:
	_do_smash(null, drop_kind, drop_name)

func _do_smash(by_player: Player = null, drop_kind: int = 2, drop_name: String = "") -> void:
	if is_smashed:
		return
	is_smashed = true

	var parent_node := get_parent()
	var origin := global_position

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"urn_shatter", origin, 0.93, 1.10, -1.0, 24.0, 6.0)

	if is_instance_valid(parent_node):
		DUST_PUFF.spawn(parent_node, origin + Vector3(0, 0.35, 0), 5, 1.1)
		_spawn_clay_shards(parent_node, origin)
		if drop_kind == 1:
			var heart := EMERALD_HEART.new()
			heart.name = drop_name if not drop_name.is_empty() else "HeartDrop"
			parent_node.add_child(heart)
			heart.global_position = origin
		else:
			_spawn_gold_coins(parent_node, origin, is_instance_valid(by_player))

	if drop_kind == 2 and is_instance_valid(by_player) and by_player.current_health > 0:
		if by_player.has_method("grant_speed_boost"):
			by_player.grant_speed_boost(4.0)

	queue_free()

func _spawn_gold_coins(parent_node: Node, origin: Vector3, grant_haste_popup: bool) -> void:
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.84, 0.22)
	gold_mat.metallic = 0.92
	gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.78, 0.18)
	gold_mat.emission_energy_multiplier = 1.4

	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = 0.09
	coin_mesh.bottom_radius = 0.09
	coin_mesh.height = 0.025
	coin_mesh.material = gold_mat

	for i in range(4):
		var coin := MeshInstance3D.new()
		coin.mesh = coin_mesh
		parent_node.add_child(coin)
		coin.global_position = origin + Vector3(0.0, 0.4, 0.0)
		var ang := (TAU / 4.0) * float(i) + 0.4
		var target := origin + Vector3(cos(ang) * 0.55, 0.06, sin(ang) * 0.55)
		var tw := coin.create_tween().set_parallel(true)
		tw.tween_property(coin, "global_position:x", target.x, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "global_position:z", target.z, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "global_position:y", target.y, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "rotation:y", TAU * 2.0, 0.65)
		tw.chain().tween_interval(0.35)
		tw.chain().tween_property(coin, "scale", Vector3.ZERO, 0.2)
		tw.chain().tween_callback(coin.queue_free)

	if grant_haste_popup:
		var lbl := Label3D.new()
		lbl.text = "⚡ +SPEED BLESSING!"
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 34
		lbl.outline_size = 8
		lbl.modulate = Color(1.0, 0.90, 0.32)
		parent_node.add_child(lbl)
		lbl.global_position = origin + Vector3(0.0, 0.95, 0.0)
		var ltw := lbl.create_tween().set_parallel(true)
		ltw.tween_property(lbl, "global_position:y", lbl.global_position.y + 0.80, 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ltw.tween_property(lbl, "modulate:a", 0.0, 0.70).set_delay(0.2)
		ltw.chain().tween_callback(lbl.queue_free)

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
