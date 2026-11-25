extends Node
## Built-in Online / LAN Co-op Manager using Godot 4 ENetMultiplayerPeer.
## Supports 1-4 players with Room Codes, raw IPv4 / VPN IPs (Tailscale/Radmin), and mid-game drop-in/drop-out.

signal lobby_updated()
signal connection_succeeded_msg()
signal connection_failed_msg(reason: String)
signal session_ended_msg(reason: String)
signal slot_joined_midgame(slot_id: int, peer_id: int)
signal slot_left_midgame(slot_id: int, peer_id: int)

const DEFAULT_PORT: int = 7777
const MAX_PEERS: int = 4

var is_online: bool = false
var is_host: bool = false
var active_port: int = DEFAULT_PORT
var local_player_name: String = "Raider"
var lobby_selected_level: int = 1

# Authoritative roster synced to all peers
var peer_to_slot: Dictionary = {} # peer_id (int) -> slot_id (1..4)
var slot_to_peer: Dictionary = {} # slot_id (1..4) -> peer_id (int)
var peer_names: Dictionary = {}   # peer_id (int) -> String

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT, host_name: String = "Host Raider") -> Error:
	disconnect_session(true)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS - 1)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = true
	active_port = port
	local_player_name = host_name.strip_edges() if not host_name.strip_edges().is_empty() else "Host Raider"

	peer_to_slot = {1: 1}
	slot_to_peer = {1: 1}
	peer_names = {1: local_player_name}
	lobby_updated.emit()
	return OK

func join_game(raw_target: String, fallback_port: int = DEFAULT_PORT, client_name: String = "Raider") -> Error:
	disconnect_session(true)
	var parsed := parse_join_target(raw_target, fallback_port)
	var address: String = parsed["ip"]
	var port: int = int(parsed["port"])
	if address.is_empty():
		return ERR_INVALID_PARAMETER

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = false
	active_port = port
	local_player_name = client_name.strip_edges() if not client_name.strip_edges().is_empty() else "Raider"
	return OK

func disconnect_session(silent: bool = false) -> void:
	var was_online := is_online
	is_online = false
	is_host = false
	peer_to_slot.clear()
	slot_to_peer.clear()
	peer_names.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if was_online and not silent:
		lobby_updated.emit()

func get_local_peer_id() -> int:
	if not is_online or multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()

func get_local_slot() -> int:
	if not is_online:
		return 1
	return int(peer_to_slot.get(get_local_peer_id(), 1))

func get_peer_for_slot(slot_id: int) -> int:
	return int(slot_to_peer.get(slot_id, 0))

func is_slot_local(slot_id: int) -> bool:
	if not is_online:
		return true
	return get_peer_for_slot(slot_id) == get_local_peer_id()

func get_online_player_count() -> int:
	return maxi(1, slot_to_peer.size())

# ---------------------------------------------------------------------------
# Room Code & LAN IP Helpers
# ---------------------------------------------------------------------------

static func get_best_lan_ip() -> String:
	var addresses := IP.get_local_addresses()
	var fallback_v4 := ""
	for addr in addresses:
		if addr.contains(":") or addr == "127.0.0.1" or addr.begins_with("169.254."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
		if fallback_v4.is_empty():
			fallback_v4 = addr
	return fallback_v4 if not fallback_v4.is_empty() else "127.0.0.1"

static func encode_room_code(ip: String, port: int = DEFAULT_PORT) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ip
	var b0 := clampi(int(parts[0]), 0, 255)
	var b1 := clampi(int(parts[1]), 0, 255)
	var b2 := clampi(int(parts[2]), 0, 255)
	var b3 := clampi(int(parts[3]), 0, 255)
	var code := "%02X%02X-%02X%02X" % [b0, b1, b2, b3]
	if port != DEFAULT_PORT:
		code += "-%04X" % clampi(port, 1, 65535)
	return code

static func parse_join_target(raw: String, fallback_port: int = DEFAULT_PORT) -> Dictionary:
	var clean := raw.strip_edges()
	if clean.is_empty():
		return {"ip": "127.0.0.1", "port": fallback_port}
	if clean.to_lower() == "localhost":
		return {"ip": "127.0.0.1", "port": fallback_port}

	# Check ip:port format
	if clean.contains(":") and not clean.contains(" "):
		var sp := clean.split(":")
		if sp.size() == 2 and sp[1].is_valid_int():
			return {"ip": sp[0].strip_edges(), "port": int(sp[1])}

	# Check hex Room Code (e.g. C0A8-012A or C0A8-012A-1E61)
	var hex_only := clean.replace("-", "").replace(" ", "").to_upper()
	if (hex_only.length() == 8 or hex_only.length() == 12) and hex_only.is_valid_hex_number(false):
		var b0 := hex_only.substr(0, 2).hex_to_int()
		var b1 := hex_only.substr(2, 2).hex_to_int()
		var b2 := hex_only.substr(4, 2).hex_to_int()
		var b3 := hex_only.substr(6, 2).hex_to_int()
		var decoded_port := fallback_port
		if hex_only.length() == 12:
			decoded_port = hex_only.substr(8, 4).hex_to_int()
		return {"ip": "%d.%d.%d.%d" % [b0, b1, b2, b3], "port": decoded_port}

	return {"ip": clean, "port": fallback_port}

# ---------------------------------------------------------------------------
# ENet Peer & Roster Callbacks
# ---------------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	var assigned_slot := _find_free_slot()
	if assigned_slot == 0:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	peer_to_slot[peer_id] = assigned_slot
	slot_to_peer[assigned_slot] = peer_id
	peer_names[peer_id] = "Raider %d" % assigned_slot
	_broadcast_roster()

	# If the host is already inside a gameplay level, instruct the newly joined client to load in!
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene is BaseTempleLevel:
		if is_instance_valid(GameManager):
			GameManager.player_count = get_online_player_count()
			_rpc_load_level.rpc_id(peer_id, GameManager.current_level_index, GameManager.player_count)
		slot_joined_midgame.emit(assigned_slot, peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var old_slot := int(peer_to_slot.get(peer_id, 0))
	peer_to_slot.erase(peer_id)
	peer_names.erase(peer_id)
	if old_slot > 0:
		slot_to_peer.erase(old_slot)

	if is_host:
		_broadcast_roster()
		if is_instance_valid(GameManager):
			GameManager.player_count = get_online_player_count()

	if old_slot > 0:
		slot_left_midgame.emit(old_slot, peer_id)
	lobby_updated.emit()

func _on_connected_to_server() -> void:
	connection_succeeded_msg.emit()
	_rpc_register_client_name.rpc_id(1, local_player_name)

func _on_connection_failed() -> void:
	disconnect_session(true)
	connection_failed_msg.emit("Could not reach host. Check the Room Code / IP and firewall.")

func _on_server_disconnected() -> void:
	disconnect_session(true)
	get_tree().paused = false
	session_ended_msg.emit("Host ended the online session.")
	if is_instance_valid(GameManager):
		get_tree().change_scene_to_file(GameManager.MAIN_MENU_SCENE)

func _find_free_slot() -> int:
	for s in range(1, MAX_PEERS + 1):
		if not slot_to_peer.has(s):
			return s
	return 0

func set_lobby_level(lvl: int) -> void:
	lobby_selected_level = lvl
	if is_online and is_host:
		_broadcast_roster()

func _broadcast_roster() -> void:
	if not is_host:
		return
	_rpc_sync_roster.rpc(peer_to_slot, slot_to_peer, peer_names, lobby_selected_level)

@rpc("any_peer", "reliable")
func _rpc_register_client_name(chosen_name: String) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if peer_to_slot.has(sender):
		var clean := chosen_name.strip_edges().left(18)
		if not clean.is_empty():
			peer_names[sender] = clean
			_broadcast_roster()

@rpc("authority", "call_local", "reliable")
func _rpc_sync_roster(p2s: Dictionary, s2p: Dictionary, pnames: Dictionary, sel_lvl: int) -> void:
	peer_to_slot = p2s.duplicate()
	slot_to_peer = s2p.duplicate()
	peer_names = pnames.duplicate()
	lobby_selected_level = sel_lvl
	lobby_updated.emit()

# ---------------------------------------------------------------------------
# Synchronized Scene Transitions (Host -> All Peers)
# ---------------------------------------------------------------------------

func host_start_adventure(start_level: int) -> void:
	if not is_online or not is_host:
		return
	var p_count := get_online_player_count()
	_rpc_load_level.rpc(start_level, p_count)

func host_load_level(level_num: int) -> void:
	if not is_online or not is_host:
		return
	_rpc_load_level.rpc(level_num, get_online_player_count())

func host_return_to_menu() -> void:
	if not is_online or not is_host:
		return
	_rpc_return_to_menu.rpc()

@rpc("authority", "call_local", "reliable")
func _rpc_load_level(level_num: int, synced_player_count: int) -> void:
	get_tree().paused = false
	if is_instance_valid(GameManager):
		GameManager.player_count = clampi(synced_player_count, 1, 4)
		var all_levels := GameManager.get_levels()
		GameManager.current_level_index = clampi(level_num, 1, all_levels.size())
		get_tree().change_scene_to_file(all_levels[GameManager.current_level_index - 1])

@rpc("authority", "call_local", "reliable")
func _rpc_return_to_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(GameManager):
		get_tree().change_scene_to_file(GameManager.MAIN_MENU_SCENE)
