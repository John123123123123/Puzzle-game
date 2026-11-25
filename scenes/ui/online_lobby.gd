extends CanvasLayer
class_name OnlineLobby

signal closed

const LEVEL_NAMES: Array[String] = [
	"1: The Catacombs",
	"2: Chamber of Mirrors",
	"3: Vault of Twin Moons",
	"4: The Golden Idol",
]

var _name_input: LineEdit = null
var _host_port_input: LineEdit = null
var _join_code_input: LineEdit = null
var _join_port_input: LineEdit = null
var _level_option: OptionButton = null
var _status_label: Label = null
var _room_code_label: Label = null
var _copy_btn: Button = null
var _roster_vbox: VBoxContainer = null
var _start_online_btn: Button = null
var _disconnect_btn: Button = null
var _host_btn: Button = null
var _join_btn: Button = null
var _localhost_btn: Button = null
var _close_btn: Button = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	if is_instance_valid(NetworkManager):
		NetworkManager.lobby_updated.connect(_refresh_ui)
		NetworkManager.connection_succeeded_msg.connect(func():
			_set_status("Connected to host! Waiting in squad lobby...", Color(0.35, 1.0, 0.55))
			_refresh_ui()
		)
		NetworkManager.connection_failed_msg.connect(func(reason: String):
			_set_status(reason, Color(1.0, 0.35, 0.35))
			_refresh_ui()
		)
		NetworkManager.session_ended_msg.connect(func(reason: String):
			_set_status(reason, Color(1.0, 0.75, 0.3))
			_refresh_ui()
		)

	_refresh_ui()
	if is_instance_valid(_close_btn):
		_close_btn.grab_focus()

func _make_style(bg: Color, border: Color, bw: int = 2, rad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = bw
	sb.border_width_top = bw
	sb.border_width_right = bw
	sb.border_width_bottom = bw
	sb.corner_radius_top_left = rad
	sb.corner_radius_top_right = rad
	sb.corner_radius_bottom_left = rad
	sb.corner_radius_bottom_right = rad
	return sb

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 560)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.07, 0.11, 0.97), Color(0.92, 0.74, 0.25, 0.95), 3, 14))
	center.add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_right", 26)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	pad.add_child(root)

	# Title
	var title := Label.new()
	title.text = "🌐 ONLINE / LAN CO-OP LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(1.0, 0.86, 0.28)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Play 1–4 Players across separate PCs via Room Code (Wi-Fi / LAN / Radmin / Tailscale) or Direct IP"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = Color(0.82, 0.80, 0.75)
	root.add_child(sub)

	# Explorer Name Row
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 12)
	root.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = "Your Explorer Name:"
	name_row.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.custom_minimum_size = Vector2(220, 34)
	_name_input.max_length = 18
	_name_input.text = NetworkManager.local_player_name if is_instance_valid(NetworkManager) else "Raider"
	name_row.add_child(_name_input)

	# Main Split: Left = Host/Join Setup, Right = Squad Roster
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	root.add_child(split)

	# --- Left Column: Host & Join Cards ---
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 12)
	split.add_child(left_col)

	# Host Card
	var host_card := PanelContainer.new()
	host_card.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.10, 0.15, 0.92), Color(0.85, 0.65, 0.22, 0.7), 2, 10))
	left_col.add_child(host_card)
	var host_pad := MarginContainer.new()
	host_pad.add_theme_constant_override("margin_left", 14)
	host_pad.add_theme_constant_override("margin_right", 14)
	host_pad.add_theme_constant_override("margin_top", 12)
	host_pad.add_theme_constant_override("margin_bottom", 12)
	host_card.add_child(host_pad)
	var host_vb := VBoxContainer.new()
	host_vb.add_theme_constant_override("separation", 8)
	host_pad.add_child(host_vb)

	var host_hdr := Label.new()
	host_hdr.text = "HOST EXPEDITION"
	host_hdr.modulate = Color(1.0, 0.85, 0.3)
	host_hdr.add_theme_font_size_override("font_size", 17)
	host_vb.add_child(host_hdr)

	var h_port_row := HBoxContainer.new()
	h_port_row.add_theme_constant_override("separation", 10)
	host_vb.add_child(h_port_row)
	var h_port_lbl := Label.new()
	h_port_lbl.text = "UDP Port:"
	h_port_row.add_child(h_port_lbl)
	_host_port_input = LineEdit.new()
	_host_port_input.text = str(NetworkManager.DEFAULT_PORT)
	_host_port_input.custom_minimum_size = Vector2(90, 32)
	h_port_row.add_child(_host_port_input)

	_host_btn = Button.new()
	_host_btn.text = "Create Room"
	_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_btn.custom_minimum_size = Vector2(140, 34)
	_host_btn.pressed.connect(_on_host_pressed)
	h_port_row.add_child(_host_btn)

	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 10)
	host_vb.add_child(lvl_row)
	var lvl_lbl := Label.new()
	lvl_lbl.text = "Starting Level:"
	lvl_row.add_child(lvl_lbl)
	_level_option = OptionButton.new()
	_level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ln in LEVEL_NAMES:
		_level_option.add_item(ln)
	_level_option.item_selected.connect(func(idx: int):
		if is_instance_valid(NetworkManager):
			NetworkManager.set_lobby_level(idx + 1)
	)
	lvl_row.add_child(_level_option)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	host_vb.add_child(code_row)
	_room_code_label = Label.new()
	_room_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_code_label.modulate = Color(0.4, 0.95, 1.0)
	_room_code_label.add_theme_font_size_override("font_size", 14)
	_room_code_label.text = "Room Code: (Not hosting)"
	code_row.add_child(_room_code_label)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy Code"
	_copy_btn.custom_minimum_size = Vector2(95, 30)
	_copy_btn.pressed.connect(_on_copy_code_pressed)
	code_row.add_child(_copy_btn)

	# Join Card
	var join_card := PanelContainer.new()
	join_card.add_theme_stylebox_override("panel", _make_style(Color(0.10, 0.12, 0.16, 0.92), Color(0.30, 0.78, 0.95, 0.7), 2, 10))
	left_col.add_child(join_card)
	var join_pad := MarginContainer.new()
	join_pad.add_theme_constant_override("margin_left", 14)
	join_pad.add_theme_constant_override("margin_right", 14)
	join_pad.add_theme_constant_override("margin_top", 12)
	join_pad.add_theme_constant_override("margin_bottom", 12)
	join_card.add_child(join_pad)
	var join_vb := VBoxContainer.new()
	join_vb.add_theme_constant_override("separation", 8)
	join_pad.add_child(join_vb)

	var join_hdr := Label.new()
	join_hdr.text = "JOIN FRIEND'S EXPEDITION"
	join_hdr.modulate = Color(0.35, 0.90, 1.0)
	join_hdr.add_theme_font_size_override("font_size", 17)
	join_vb.add_child(join_hdr)

	var j_addr_row := HBoxContainer.new()
	j_addr_row.add_theme_constant_override("separation", 8)
	join_vb.add_child(j_addr_row)
	_join_code_input = LineEdit.new()
	_join_code_input.placeholder_text = "Room Code (e.g. C0A8-012A) or IP"
	_join_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_code_input.custom_minimum_size = Vector2(200, 34)
	j_addr_row.add_child(_join_code_input)

	_join_port_input = LineEdit.new()
	_join_port_input.text = str(NetworkManager.DEFAULT_PORT)
	_join_port_input.custom_minimum_size = Vector2(75, 34)
	_join_port_input.tooltip_text = "UDP Port"
	j_addr_row.add_child(_join_port_input)

	var j_btn_row := HBoxContainer.new()
	j_btn_row.add_theme_constant_override("separation", 10)
	join_vb.add_child(j_btn_row)

	_join_btn = Button.new()
	_join_btn.text = "Connect to Room"
	_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_btn.custom_minimum_size = Vector2(150, 36)
	_join_btn.pressed.connect(_on_join_pressed)
	j_btn_row.add_child(_join_btn)

	_localhost_btn = Button.new()
	_localhost_btn.text = "Quick Join Local PC"
	_localhost_btn.custom_minimum_size = Vector2(155, 36)
	_localhost_btn.pressed.connect(func():
		_join_code_input.text = "127.0.0.1"
		_on_join_pressed()
	)
	j_btn_row.add_child(_localhost_btn)

	# --- Right Column: Connected Squad Roster ---
	var right_card := PanelContainer.new()
	right_card.custom_minimum_size = Vector2(320, 0)
	right_card.add_theme_stylebox_override("panel", _make_style(Color(0.10, 0.09, 0.14, 0.94), Color(0.75, 0.65, 0.40, 0.75), 2, 10))
	split.add_child(right_card)

	var right_pad := MarginContainer.new()
	right_pad.add_theme_constant_override("margin_left", 16)
	right_pad.add_theme_constant_override("margin_right", 16)
	right_pad.add_theme_constant_override("margin_top", 14)
	right_pad.add_theme_constant_override("margin_bottom", 14)
	right_card.add_child(right_pad)

	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 10)
	right_pad.add_child(right_vb)

	var roster_hdr := Label.new()
	roster_hdr.text = "SQUAD ROSTER (1–4P)"
	roster_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_hdr.add_theme_font_size_override("font_size", 18)
	roster_hdr.modulate = Color(1.0, 0.88, 0.32)
	right_vb.add_child(roster_hdr)

	_roster_vbox = VBoxContainer.new()
	_roster_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_vbox.add_theme_constant_override("separation", 8)
	right_vb.add_child(_roster_vbox)

	_start_online_btn = Button.new()
	_start_online_btn.text = "START ONLINE ADVENTURE  ▶"
	_start_online_btn.custom_minimum_size = Vector2(260, 46)
	_start_online_btn.pressed.connect(_on_start_online_pressed)
	right_vb.add_child(_start_online_btn)

	# Status & Footer
	_status_label = Label.new()
	_status_label.text = "Choose Create Room to host, or enter a friend's Room Code to join."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.modulate = Color(0.9, 0.9, 0.85)
	root.add_child(_status_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	_disconnect_btn = Button.new()
	_disconnect_btn.text = "Disconnect"
	_disconnect_btn.custom_minimum_size = Vector2(140, 38)
	_disconnect_btn.pressed.connect(func():
		if is_instance_valid(NetworkManager):
			NetworkManager.disconnect_session()
		_set_status("Disconnected from online session.", Color(0.9, 0.8, 0.5))
		_refresh_ui()
	)
	footer.add_child(_disconnect_btn)

	_close_btn = Button.new()
	_close_btn.text = "Back to Menu"
	_close_btn.custom_minimum_size = Vector2(150, 38)
	_close_btn.pressed.connect(_close)
	footer.add_child(_close_btn)

func _set_status(msg: String, col: Color) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = msg
		_status_label.modulate = col

func _on_host_pressed() -> void:
	var port := int(_host_port_input.text) if _host_port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	var chosen_name := _name_input.text.strip_edges()
	var err := NetworkManager.host_game(port, chosen_name)
	if err != OK:
		_set_status("Failed to open UDP port %d (Error %d). Try another port." % [port, err], Color(1.0, 0.35, 0.35))
		return
	NetworkManager.set_lobby_level(_level_option.selected + 1)
	var lan_ip := NetworkManager.get_best_lan_ip()
	var code := NetworkManager.encode_room_code(lan_ip, port)
	_set_status("Hosting on %s:%d! Share Room Code %s with friends." % [lan_ip, port, code], Color(0.35, 1.0, 0.55))
	_refresh_ui()

func _on_join_pressed() -> void:
	var port := int(_join_port_input.text) if _join_port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	var chosen_name := _name_input.text.strip_edges()
	var target := _join_code_input.text.strip_edges()
	if target.is_empty():
		target = "127.0.0.1"
	var err := NetworkManager.join_game(target, port, chosen_name)
	if err != OK:
		_set_status("Invalid Room Code or IP address.", Color(1.0, 0.35, 0.35))
		return
	_set_status("Connecting to %s..." % target, Color(0.4, 0.9, 1.0))
	_refresh_ui()

func _on_copy_code_pressed() -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_online:
		return
	var lan_ip := NetworkManager.get_best_lan_ip()
	var code := NetworkManager.encode_room_code(lan_ip, NetworkManager.active_port)
	DisplayServer.clipboard_set(code)
	_set_status("Copied Room Code %s to clipboard!" % code, Color(1.0, 0.9, 0.35))

func _on_start_online_pressed() -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_online or not NetworkManager.is_host:
		return
	NetworkManager.host_start_adventure(NetworkManager.lobby_selected_level)

func _refresh_ui() -> void:
	if not is_instance_valid(_roster_vbox):
		return
	var online := is_instance_valid(NetworkManager) and NetworkManager.is_online
	var host := online and NetworkManager.is_host

	_disconnect_btn.visible = online
	_copy_btn.disabled = not host
	_level_option.disabled = online and not host
	if online and is_instance_valid(NetworkManager):
		_level_option.selected = clampi(NetworkManager.lobby_selected_level - 1, 0, LEVEL_NAMES.size() - 1)

	if host:
		var lan_ip := NetworkManager.get_best_lan_ip()
		var code := NetworkManager.encode_room_code(lan_ip, NetworkManager.active_port)
		_room_code_label.text = "Code: %s   (LAN IP: %s:%d)" % [code, lan_ip, NetworkManager.active_port]
	else:
		_room_code_label.text = "Room Code: (Host a room to generate)"

	_start_online_btn.disabled = not host
	_start_online_btn.text = "START ONLINE ADVENTURE  ▶" if host else ("Waiting for Host..." if online else "Host a Room to Start")

	for ch in _roster_vbox.get_children():
		ch.queue_free()

	for slot in range(1, 5):
		var row := PanelContainer.new()
		var p_col := GameManager.get_player_color(slot)
		var peer_id := NetworkManager.get_peer_for_slot(slot) if online else 0
		var active := peer_id > 0
		row.add_theme_stylebox_override("panel", _make_style(
			Color(0.14, 0.13, 0.18, 0.92) if active else Color(0.08, 0.08, 0.10, 0.55),
			Color(p_col.r, p_col.g, p_col.b, 0.9 if active else 0.25),
			2, 8
		))
		var mp := MarginContainer.new()
		mp.add_theme_constant_override("margin_left", 10)
		mp.add_theme_constant_override("margin_right", 10)
		mp.add_theme_constant_override("margin_top", 6)
		mp.add_theme_constant_override("margin_bottom", 6)
		row.add_child(mp)

		var lbl := Label.new()
		if active:
			var pname: String = str(NetworkManager.peer_names.get(peer_id, "Raider %d" % slot))
			var tags: PackedStringArray = []
			if peer_id == 1:
				tags.append("HOST")
			if peer_id == NetworkManager.get_local_peer_id():
				tags.append("YOU")
			var tag_str := (" [%s]" % ", ".join(tags)) if not tags.is_empty() else ""
			lbl.text = "P%d • %s%s" % [slot, pname, tag_str]
			lbl.modulate = Color(1.0, 0.96, 0.88)
		else:
			lbl.text = "P%d • Open Slot" % slot
			lbl.modulate = Color(0.55, 0.55, 0.58)
		mp.add_child(lbl)
		_roster_vbox.add_child(row)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
