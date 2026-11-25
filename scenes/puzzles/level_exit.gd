extends Area3D
class_name LevelExit

signal level_completed()

@export var prompt_text: String = "LEVEL COMPLETE!\nTHE GATE TO THE NEXT CHAMBER IS OPEN!"
@export var is_unlocked: bool = true

var triggered: bool = false
var _inside_players: Dictionary = {} # player_id -> true
var _warp_countdown: float = -1.0
var _last_synced_sec: int = -1
var _status_label_3d: Label3D = null

@onready var light: OmniLight3D = $OmniLight3D
@onready var portal_mesh: MeshInstance3D = $PortalMesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_status_label_3d = Label3D.new()
	_status_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label_3d.no_depth_test = true
	_status_label_3d.font_size = 34
	_status_label_3d.outline_size = 9
	_status_label_3d.modulate = Color(0.55, 0.98, 1.0)
	_status_label_3d.position = Vector3(0.0, 3.95, 0.0)
	_status_label_3d.visible = false
	add_child(_status_label_3d)

	_update_visuals()

func unlock() -> void:
	is_unlocked = true
	_update_visuals()

func _update_visuals() -> void:
	if light:
		light.light_energy = 2.4 if is_unlocked else 0.2
		light.light_color = Color(0.25, 0.92, 1.0) if is_unlocked else Color(0.8, 0.3, 0.1)

func _process(delta: float) -> void:
	if triggered or not is_unlocked:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	if _warp_countdown > 0.0:
		_warp_countdown -= delta
		var sec_left := ceili(maxf(0.1, _warp_countdown))
		if sec_left != _last_synced_sec:
			_last_synced_sec = sec_left
			_refresh_portal_state()
		if _warp_countdown <= 0.0:
			_trigger_authoritative_exit()

func _on_body_entered(body: Node3D) -> void:
	if not is_unlocked or triggered or not (body is Player):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	var p := body as Player
	if p.current_health <= 0:
		return
	_inside_players[p.player_id] = true
	_evaluate_coop_exit()

func _on_body_exited(body: Node3D) -> void:
	if triggered or not (body is Player):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	var p := body as Player
	_inside_players.erase(p.player_id)
	_evaluate_coop_exit()

func _evaluate_coop_exit() -> void:
	if triggered:
		return
	var living_total: int = 0
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.current_health > 0:
			living_total += 1
		elif node is Player and _inside_players.has(node.player_id):
			_inside_players.erase(node.player_id)

	var ready_count := _inside_players.size()
	if ready_count <= 0:
		_warp_countdown = -1.0
		_last_synced_sec = -1
		_set_portal_banner("")
		return

	if living_total <= 1 or ready_count >= living_total:
		_trigger_authoritative_exit()
		return

	# Partial squad inside portal: start 4.5s grace warp timer so teammates can grab final scarabs or join in
	if _warp_countdown < 0.0:
		_warp_countdown = 4.5
		_last_synced_sec = ceili(_warp_countdown)
		if is_instance_valid(AudioManager):
			AudioManager.play_sfx_3d(&"coop_ping", global_position, 0.92, 0.98, -3.0, 28.0, 6.0)
	_refresh_portal_state()

func _refresh_portal_state() -> void:
	var living_total := 0
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.current_health > 0:
			living_total += 1
	var sec_left := ceili(maxf(1.0, _warp_countdown))
	var msg := "⚡ Portal Charging (%d/%d Raiders) — %ds" % [_inside_players.size(), maxi(1, living_total), sec_left]
	_set_portal_banner(msg)

func _set_portal_banner(msg: String) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_portal_banner.rpc(msg)
	_apply_portal_banner(msg)

@rpc("authority", "reliable")
func _rpc_sync_portal_banner(msg: String) -> void:
	_apply_portal_banner(msg)

func _apply_portal_banner(msg: String) -> void:
	if is_instance_valid(_status_label_3d):
		_status_label_3d.text = msg
		_status_label_3d.visible = not msg.is_empty()

func _trigger_authoritative_exit() -> void:
	if triggered:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_trigger_exit.rpc()
	else:
		_do_trigger_exit()

@rpc("authority", "call_local", "reliable")
func _rpc_trigger_exit() -> void:
	_do_trigger_exit()

func _do_trigger_exit() -> void:
	if triggered:
		return
	triggered = true
	if is_instance_valid(_status_label_3d):
		_status_label_3d.visible = false
	level_completed.emit()

	var hud = get_tree().get_first_node_in_group("hud")
	var current_lvl = 2
	if is_instance_valid(GameManager):
		current_lvl = GameManager.current_level_index

	if hud and hud.has_method("show_level_complete"):
		hud.show_level_complete(current_lvl)
	elif hud and hud.has_method("show_victory"):
		hud.show_victory(prompt_text)
		await get_tree().create_timer(2.2).timeout
		if is_instance_valid(GameManager):
			GameManager.next_level()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
