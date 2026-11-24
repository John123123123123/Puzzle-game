extends CanvasLayer
class_name SettingsMenu

signal closed

const TABS: Array[String] = ["Audio", "Graphics", "Display", "Game", "Keybinds", "Gamepad"]

var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _active_tab: int = 0
var _rebinding_action: String = ""
var _rebinding_button: Button = null
var _keybind_buttons: Dictionary = {} # action -> Button
var _joy_list_label: Label = null
var _close_button: Button = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_select_tab(0)
	if is_instance_valid(_close_button):
		_close_button.grab_focus()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Header
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(1.0, 0.85, 0.25)
	root_vbox.add_child(title)

	# Tab Bar
	var tab_hbox := HBoxContainer.new()
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tab_hbox)

	for i in range(TABS.size()):
		var btn := Button.new()
		btn.text = TABS[i]
		btn.custom_minimum_size = Vector2(105, 36)
		var tab_idx := i
		btn.pressed.connect(func(): _select_tab(tab_idx))
		tab_hbox.add_child(btn)
		_tab_buttons.append(btn)

	# Scrollable Content Container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var pages_holder := MarginContainer.new()
	pages_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_holder.add_theme_constant_override("margin_left", 8)
	pages_holder.add_theme_constant_override("margin_right", 12)
	pages_holder.add_theme_constant_override("margin_top", 8)
	scroll.add_child(pages_holder)

	_tab_pages.append(_build_audio_tab(pages_holder))
	_tab_pages.append(_build_graphics_tab(pages_holder))
	_tab_pages.append(_build_display_tab(pages_holder))
	_tab_pages.append(_build_game_tab(pages_holder))
	_tab_pages.append(_build_keybinds_tab(pages_holder))
	_tab_pages.append(_build_gamepad_tab(pages_holder))

	# Footer
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	root_vbox.add_child(footer)

	var btn_reset := Button.new()
	btn_reset.text = "Reset Defaults"
	btn_reset.custom_minimum_size = Vector2(150, 40)
	btn_reset.pressed.connect(_on_reset_defaults)
	footer.add_child(btn_reset)

	_close_button = Button.new()
	_close_button.text = "Back"
	_close_button.custom_minimum_size = Vector2(140, 40)
	_close_button.pressed.connect(_close)
	footer.add_child(_close_button)

func _select_tab(idx: int) -> void:
	_active_tab = idx
	_cancel_rebind()
	for i in range(_tab_pages.size()):
		_tab_pages[i].visible = (i == idx)
		_tab_buttons[i].modulate = Color(1.0, 0.9, 0.35) if i == idx else Color(0.75, 0.75, 0.75)
	if idx == 5:
		_refresh_connected_joypads()

func _make_page(parent: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	vbox.visible = false
	parent.add_child(vbox)
	return vbox

func _add_slider_row(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, step_v: float, initial: float, suffix: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(230, 0)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(220, 24)
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(75, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = _format_slider_value(initial, max_v, suffix)
	hbox.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = _format_slider_value(v, max_v, suffix)
		on_change.call(v)
	)

func _format_slider_value(val: float, max_v: float, suffix: String) -> String:
	if suffix == "%":
		return "%d%%" % int(round(val * 100.0))
	return "%.2f%s" % [val, suffix] if max_v <= 3.0 else "%d%s" % [int(round(val)), suffix]

func _add_toggle_row(parent: VBoxContainer, label_text: String, initial: bool, on_toggle: Callable) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var chk := CheckButton.new()
	chk.button_pressed = initial
	chk.toggled.connect(on_toggle)
	hbox.add_child(chk)

func _add_option_row(parent: VBoxContainer, label_text: String, options: Array[String], initial_idx: int, on_select: Callable) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(220, 32)
	for item in options:
		opt.add_item(item)
	opt.selected = clampi(initial_idx, 0, options.size() - 1)
	opt.item_selected.connect(on_select)
	hbox.add_child(opt)

# ---------------------------------------------------------------------------
# Tab Builders
# ---------------------------------------------------------------------------

func _build_audio_tab(parent: Control) -> Control:
	var page := _make_page(parent)
	_add_slider_row(page, "Master Volume", 0.0, 1.0, 0.05, SettingsManager.master_volume, "%", func(v: float):
		SettingsManager.master_volume = v
		SettingsManager.apply_audio()
		SettingsManager.save_settings()
	)
	_add_slider_row(page, "SFX Volume", 0.0, 1.0, 0.05, SettingsManager.sfx_volume, "%", func(v: float):
		SettingsManager.sfx_volume = v
		SettingsManager.apply_audio()
		SettingsManager.save_settings()
	)
	_add_slider_row(page, "Ambient Volume", 0.0, 1.0, 0.05, SettingsManager.ambient_volume, "%", func(v: float):
		SettingsManager.ambient_volume = v
		SettingsManager.apply_audio()
		SettingsManager.save_settings()
	)
	return page

func _build_graphics_tab(parent: Control) -> Control:
	var page := _make_page(parent)
	_add_option_row(page, "Anti-Aliasing (MSAA 3D)", ["Off", "2x MSAA", "4x MSAA"], SettingsManager.msaa, func(idx: int):
		SettingsManager.msaa = idx
		SettingsManager.apply_graphics()
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Screen-Space AA (FXAA)", SettingsManager.fxaa, func(on: bool):
		SettingsManager.fxaa = on
		SettingsManager.apply_graphics()
		SettingsManager.save_settings()
	)
	_add_option_row(page, "Shadow Quality", ["Low", "Medium", "High"], SettingsManager.shadow_quality, func(idx: int):
		SettingsManager.shadow_quality = idx
		SettingsManager.apply_graphics()
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Ambient Occlusion (SSAO)", SettingsManager.ssao_enabled, func(on: bool):
		SettingsManager.ssao_enabled = on
		SettingsManager.apply_graphics()
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Indirect Lighting (SSIL)", SettingsManager.ssil_enabled, func(on: bool):
		SettingsManager.ssil_enabled = on
		SettingsManager.apply_graphics()
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Glow / Bloom", SettingsManager.glow_enabled, func(on: bool):
		SettingsManager.glow_enabled = on
		SettingsManager.apply_graphics()
		SettingsManager.save_settings()
	)
	return page

func _build_display_tab(parent: Control) -> Control:
	var page := _make_page(parent)
	_add_option_row(page, "Window Mode", ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"], SettingsManager.window_mode, func(idx: int):
		SettingsManager.window_mode = idx
		SettingsManager.apply_display()
		SettingsManager.save_settings()
	)
	var res_labels: Array[String] = []
	for r in SettingsManager.RESOLUTIONS:
		res_labels.append("%d × %d" % [r.x, r.y])
	_add_option_row(page, "Window Resolution", res_labels, SettingsManager.resolution_index, func(idx: int):
		SettingsManager.resolution_index = idx
		SettingsManager.apply_display()
		SettingsManager.save_settings()
	)
	_add_option_row(page, "V-Sync", ["Disabled", "Enabled", "Adaptive"], SettingsManager.vsync, func(idx: int):
		SettingsManager.vsync = idx
		SettingsManager.apply_display()
		SettingsManager.save_settings()
	)
	return page

func _build_game_tab(parent: Control) -> Control:
	var page := _make_page(parent)
	_add_slider_row(page, "Camera Sensitivity", 0.2, 2.5, 0.1, SettingsManager.camera_sensitivity, "x", func(v: float):
		SettingsManager.camera_sensitivity = v
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Camera Shake", SettingsManager.camera_shake, func(on: bool):
		SettingsManager.camera_shake = on
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "World Interaction Prompts", SettingsManager.show_interact_prompts, func(on: bool):
		SettingsManager.show_interact_prompts = on
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Show Level Timer & Scarabs", SettingsManager.show_timer, func(on: bool):
		SettingsManager.show_timer = on
		SettingsManager.settings_changed.emit()
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Show Progression & Best Records", SettingsManager.show_progression_indicators, func(on: bool):
		SettingsManager.show_progression_indicators = on
		SettingsManager.settings_changed.emit()
		SettingsManager.save_settings()
	)
	return page

func _build_keybinds_tab(parent: Control) -> Control:
	var page := _make_page(parent)
	_keybind_buttons.clear()

	for entry in SettingsManager.REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		var hbox := HBoxContainer.new()
		page.add_child(hbox)

		var lbl := Label.new()
		lbl.text = entry["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 32)
		btn.text = SettingsManager.get_action_key_label(action)
		btn.pressed.connect(func(): _start_rebind(action, btn))
		hbox.add_child(btn)
		_keybind_buttons[action] = btn

	var reset_btn := Button.new()
	reset_btn.text = "Reset Keybinds to Default"
	reset_btn.custom_minimum_size = Vector2(220, 36)
	reset_btn.pressed.connect(func():
		SettingsManager.reset_keybinds()
		_refresh_keybind_buttons()
	)
	page.add_child(reset_btn)
	return page

func _build_gamepad_tab(parent: Control) -> Control:
	var page := _make_page(parent)
	_add_slider_row(page, "Stick Deadzone", 0.05, 0.60, 0.05, SettingsManager.gamepad_deadzone, "", func(v: float):
		SettingsManager.gamepad_deadzone = v
		SettingsManager.apply_gamepad()
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Invert Camera Horizontal", SettingsManager.invert_camera_x, func(on: bool):
		SettingsManager.invert_camera_x = on
		SettingsManager.save_settings()
	)
	_add_toggle_row(page, "Controller Rumble", SettingsManager.controller_rumble, func(on: bool):
		SettingsManager.controller_rumble = on
		SettingsManager.save_settings()
	)

	var sep := HSeparator.new()
	page.add_child(sep)

	_joy_list_label = Label.new()
	_joy_list_label.modulate = Color(0.85, 0.85, 0.8)
	page.add_child(_joy_list_label)
	_refresh_connected_joypads()
	return page

# ---------------------------------------------------------------------------
# Keybind Capture & Helpers
# ---------------------------------------------------------------------------

func _start_rebind(action: String, btn: Button) -> void:
	_cancel_rebind()
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "Press a key..."

func _cancel_rebind() -> void:
	if is_instance_valid(_rebinding_button) and not _rebinding_action.is_empty():
		_rebinding_button.text = SettingsManager.get_action_key_label(_rebinding_action)
	_rebinding_action = ""
	_rebinding_button = null

func _refresh_keybind_buttons() -> void:
	for action in _keybind_buttons.keys():
		var btn: Button = _keybind_buttons[action]
		if is_instance_valid(btn):
			btn.text = SettingsManager.get_action_key_label(action)

func _refresh_connected_joypads() -> void:
	if not is_instance_valid(_joy_list_label):
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_joy_list_label.text = "Connected Controllers: None detected"
	else:
		var lines: PackedStringArray = ["Connected Controllers:"]
		for id in pads:
			lines.append("  • Pad %d: %s" % [id + 1, Input.get_joy_name(id)])
		_joy_list_label.text = "\n".join(lines)

func _input(event: InputEvent) -> void:
	if not _rebinding_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				_cancel_rebind()
				return
			var kc: int = event.physical_keycode if event.physical_keycode > 0 else event.keycode
			SettingsManager.set_action_key(_rebinding_action, kc, true)
			_rebinding_button.text = SettingsManager.get_action_key_label(_rebinding_action)
			_rebinding_action = ""
			_rebinding_button = null
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _on_reset_defaults() -> void:
	SettingsManager.reset_to_defaults()
	# Rebuild UI to reflect reset values cleanly
	for child in get_children():
		child.queue_free()
	_tab_buttons.clear()
	_tab_pages.clear()
	_build_ui()
	_select_tab(_active_tab)
	if is_instance_valid(_close_button):
		_close_button.grab_focus()

func _close() -> void:
	closed.emit()
	queue_free()
