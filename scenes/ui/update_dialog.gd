extends CanvasLayer
class_name UpdateDialog

signal closed

var _mode_value: Label = null
var _local_value: Label = null
var _remote_value: Label = null
var _commit_msg_label: Label = null
var _status_label: Label = null
var _progress_bar: ProgressBar = null
var _log_box: RichTextLabel = null

var _check_btn: Button = null
var _update_btn: Button = null
var _stash_update_btn: Button = null
var _restart_btn: Button = null
var _github_btn: Button = null
var _close_btn: Button = null

func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	if is_instance_valid(UpdateManager):
		UpdateManager.state_changed.connect(_refresh_ui)
		UpdateManager.log_appended.connect(_on_log_appended)
		for line in UpdateManager.log_lines:
			_log_box.append_text(line + "\n")
		if UpdateManager.remote_sha.is_empty() and not UpdateManager.is_busy:
			UpdateManager.check_for_updates(true)

	_refresh_ui()
	if is_instance_valid(_update_btn) and not _update_btn.disabled:
		_update_btn.grab_focus()
	elif is_instance_valid(_close_btn):
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
	panel.custom_minimum_size = Vector2(760, 510)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.07, 0.11, 0.97), Color(0.92, 0.74, 0.25, 0.95), 3, 14))
	center.add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_right", 26)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	pad.add_child(root)

	var title := Label.new()
	title.text = "⬇ GAME UPDATER (GITHUB MAIN)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(1.0, 0.86, 0.28)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Check and install the newest levels, visuals, and features pushed to main"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = Color(0.82, 0.80, 0.75)
	root.add_child(sub)

	# Version Info Card
	var info_card := PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", _make_style(Color(0.12, 0.11, 0.16, 0.95), Color(0.45, 0.40, 0.28, 0.8), 1, 10))
	root.add_child(info_card)

	var info_pad := MarginContainer.new()
	info_pad.add_theme_constant_override("margin_left", 16)
	info_pad.add_theme_constant_override("margin_right", 16)
	info_pad.add_theme_constant_override("margin_top", 12)
	info_pad.add_theme_constant_override("margin_bottom", 12)
	info_card.add_child(info_pad)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	info_pad.add_child(info_vbox)

	_mode_value = _add_kv_row(info_vbox, "Update Method:")
	_local_value = _add_kv_row(info_vbox, "Installed Version:")
	_remote_value = _add_kv_row(info_vbox, "Latest on main:")

	_commit_msg_label = Label.new()
	_commit_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commit_msg_label.add_theme_font_size_override("font_size", 13)
	_commit_msg_label.modulate = Color(0.95, 0.88, 0.65)
	_commit_msg_label.text = "Latest Commit: Checking..."
	info_vbox.add_child(_commit_msg_label)

	# Status + Progress Bar
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	root.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = true
	root.add_child(_progress_bar)

	# Log Output Box
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.custom_minimum_size = Vector2(0, 125)
	log_panel.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.05, 0.07, 0.95), Color(0.28, 0.28, 0.34, 0.85), 1, 8))
	root.add_child(log_panel)

	var log_pad := MarginContainer.new()
	log_pad.add_theme_constant_override("margin_left", 10)
	log_pad.add_theme_constant_override("margin_right", 10)
	log_pad.add_theme_constant_override("margin_top", 8)
	log_pad.add_theme_constant_override("margin_bottom", 8)
	log_panel.add_child(log_pad)

	_log_box = RichTextLabel.new()
	_log_box.scroll_following = true
	_log_box.selection_enabled = true
	_log_box.add_theme_font_size_override("normal_font_size", 12)
	_log_box.modulate = Color(0.82, 0.86, 0.90)
	log_pad.add_child(_log_box)

	# Action Buttons Row 1 (Primary Update / Stash / Restart)
	var primary_row := HBoxContainer.new()
	primary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_row.add_theme_constant_override("separation", 12)
	root.add_child(primary_row)

	_check_btn = Button.new()
	_check_btn.text = "🔄 Check for Updates"
	_check_btn.custom_minimum_size = Vector2(175, 42)
	_check_btn.pressed.connect(func():
		if is_instance_valid(UpdateManager):
			UpdateManager.check_for_updates(true)
	)
	primary_row.add_child(_check_btn)

	_update_btn = Button.new()
	_update_btn.text = "⬇ Update to Latest main"
	_update_btn.custom_minimum_size = Vector2(215, 42)
	_update_btn.modulate = Color(0.55, 1.0, 0.65)
	_update_btn.pressed.connect(func():
		if is_instance_valid(UpdateManager):
			UpdateManager.start_update(false)
	)
	primary_row.add_child(_update_btn)

	_stash_update_btn = Button.new()
	_stash_update_btn.text = "📦 Stash Local Edits & Update"
	_stash_update_btn.custom_minimum_size = Vector2(235, 42)
	_stash_update_btn.modulate = Color(1.0, 0.85, 0.40)
	_stash_update_btn.visible = false
	_stash_update_btn.pressed.connect(func():
		if is_instance_valid(UpdateManager):
			UpdateManager.start_update(true)
	)
	primary_row.add_child(_stash_update_btn)

	_restart_btn = Button.new()
	_restart_btn.text = "🚀 Restart Game Now"
	_restart_btn.custom_minimum_size = Vector2(205, 42)
	_restart_btn.modulate = Color(0.45, 1.0, 0.55)
	_restart_btn.visible = false
	_restart_btn.pressed.connect(func():
		if is_instance_valid(UpdateManager):
			UpdateManager.restart_game()
	)
	primary_row.add_child(_restart_btn)

	# Action Buttons Row 2 (GitHub + Close)
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	root.add_child(bottom_row)

	_github_btn = Button.new()
	_github_btn.text = "🌐 View Repository on GitHub"
	_github_btn.custom_minimum_size = Vector2(220, 36)
	_github_btn.pressed.connect(func():
		if is_instance_valid(UpdateManager):
			UpdateManager.open_github_page()
	)
	bottom_row.add_child(_github_btn)

	_close_btn = Button.new()
	_close_btn.text = "Back to Main Menu"
	_close_btn.custom_minimum_size = Vector2(180, 36)
	_close_btn.pressed.connect(_close)
	bottom_row.add_child(_close_btn)

func _add_kv_row(parent: VBoxContainer, key_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var k := Label.new()
	k.custom_minimum_size = Vector2(155, 0)
	k.text = key_text
	k.add_theme_font_size_override("font_size", 14)
	k.modulate = Color(0.75, 0.75, 0.78)
	row.add_child(k)

	var v := Label.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_theme_font_size_override("font_size", 14)
	row.add_child(v)
	return v

func _on_log_appended(line: String) -> void:
	if is_instance_valid(_log_box):
		_log_box.append_text(line + "\n")

func _refresh_ui() -> void:
	if not is_instance_valid(UpdateManager):
		return

	_mode_value.text = UpdateManager.get_install_mode_label()
	if UpdateManager.install_mode == UpdateManager.InstallMode.STANDALONE_EXPORT:
		_mode_value.text += "  (Note: binary/engine/config updates require downloading a new GitHub build)"

	var local_txt := UpdateManager.get_display_version()
	if UpdateManager.has_local_changes:
		local_txt += "  (has uncommitted local edits)"
	_local_value.text = local_txt
	_local_value.modulate = Color(0.92, 0.92, 0.95)

	if UpdateManager.remote_sha.is_empty():
		_remote_value.text = "Checking..." if UpdateManager.is_busy else "Not checked yet"
		_remote_value.modulate = Color(0.8, 0.8, 0.8)
	else:
		var date_suffix := ("  •  " + UpdateManager.remote_date) if not UpdateManager.remote_date.is_empty() else ""
		var author_suffix := ("  by " + UpdateManager.remote_author) if not UpdateManager.remote_author.is_empty() else ""
		_remote_value.text = "%s%s%s" % [UpdateManager.short_sha(UpdateManager.remote_sha), date_suffix, author_suffix]
		_remote_value.modulate = Color(0.45, 1.0, 0.60) if UpdateManager.update_available else Color(0.85, 0.92, 1.0)

	if not UpdateManager.remote_message.is_empty():
		_commit_msg_label.text = "Latest on main: \"%s\"" % UpdateManager.remote_message
	else:
		_commit_msg_label.text = "Latest on main: —"

	_status_label.text = UpdateManager.status_text
	if UpdateManager.restart_recommended:
		_status_label.modulate = Color(0.45, 1.0, 0.55)
	elif UpdateManager.needs_stash_confirmation:
		_status_label.modulate = Color(1.0, 0.82, 0.35)
	elif UpdateManager.update_available:
		_status_label.modulate = Color(1.0, 0.92, 0.38)
	else:
		_status_label.modulate = Color(0.82, 0.95, 0.86)

	_progress_bar.value = clampf(UpdateManager.progress_ratio * 100.0, 0.0, 100.0)

	var busy := UpdateManager.is_busy
	_check_btn.disabled = busy
	_update_btn.disabled = busy
	if UpdateManager.update_available:
		_update_btn.text = "⬇ Update Now (%s)" % UpdateManager.short_sha(UpdateManager.remote_sha)
		_update_btn.modulate = Color(0.45, 1.0, 0.58)
	else:
		_update_btn.text = "⬇ Re-Sync with main"
		_update_btn.modulate = Color(0.82, 0.86, 0.90)

	_stash_update_btn.visible = UpdateManager.needs_stash_confirmation
	_stash_update_btn.disabled = busy

	_restart_btn.visible = UpdateManager.restart_recommended
	_restart_btn.disabled = busy

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
