extends CanvasLayer
class_name GameHUD

signal next_level_pressed
signal menu_pressed

const SETTINGS_MENU_SCRIPT := preload("res://scenes/ui/settings_menu.gd")

@onready var objective_label: Label = $MarginContainer/VBoxContainer/ObjectiveLabel
@onready var players_container: HBoxContainer = $MarginContainer/VBoxContainer/PlayersContainer
@onready var banner_label: Label = $CenterContainer/BannerLabel

var player_labels: Dictionary = {}
var player_prev_health: Dictionary = {}
var player_max_health: Dictionary = {}
var _level_complete_panel: Control = null
var _game_over_panel: Control = null
var _pause_panel: Control = null
var _pause_dim: ColorRect = null
var _damage_vignette: ColorRect = null
var _stats_margin: MarginContainer = null
var _stats_label: Label = null

var elapsed_time: float = 0.0
var _last_displayed_second: int = -1
var scarabs_collected: int = 0
var scarabs_total: int = 0
var party_difficulty_count: int = 1

func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner_label.visible = false
	_setup_stats_hud()
	_setup_damage_vignette()
	if is_instance_valid(SettingsManager):
		SettingsManager.settings_changed.connect(_apply_hud_settings)
		_apply_hud_settings()

func _apply_hud_settings() -> void:
	if is_instance_valid(_stats_margin) and is_instance_valid(SettingsManager):
		_stats_margin.visible = SettingsManager.show_timer

func _process(delta: float) -> void:
	if not get_tree().paused and _level_complete_panel == null and _game_over_panel == null:
		elapsed_time += delta
		var current_sec := int(elapsed_time)
		if current_sec != _last_displayed_second:
			_last_displayed_second = current_sec
			_update_stats_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func _make_temple_style(bg_col: Color = Color(0.09, 0.08, 0.12, 0.90), border_col: Color = Color(0.85, 0.68, 0.24, 0.92), border_w: int = 2, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

func _setup_stats_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_temple_style(Color(0.08, 0.07, 0.11, 0.86), Color(0.82, 0.66, 0.24, 0.85), 2, 8))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.modulate = Color(1.0, 0.94, 0.78)
	pad.add_child(_stats_label)
	panel.add_child(pad)
	margin.add_child(panel)
	add_child(margin)
	_stats_margin = margin
	_update_stats_label()

func _setup_damage_vignette() -> void:
	_damage_vignette = ColorRect.new()
	_damage_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
	add_child(_damage_vignette)

func flash_damage_vignette() -> void:
	if not is_instance_valid(_damage_vignette):
		return
	_damage_vignette.color.a = 0.32
	var tween := create_tween()
	tween.tween_property(_damage_vignette, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_scarab_total(total: int) -> void:
	scarabs_total = total
	_update_stats_label()

func register_scarab_collected() -> void:
	scarabs_collected += 1
	_update_stats_label()

func set_party_difficulty(party_size: int) -> void:
	party_difficulty_count = clampi(party_size, 1, 4)
	_update_stats_label()

func _get_difficulty_badge() -> String:
	match party_difficulty_count:
		1: return "⚔ Normal (1P)"
		2: return "⚔⚔ Hard (2P)"
		3: return "⚔⚔⚔ Ruthless (3P)"
		_: return "💀 Cursed (4P)"

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func _update_stats_label() -> void:
	if not is_instance_valid(_stats_label):
		return
	var time_str := "⏱ %s" % _format_time(elapsed_time)
	var diff_str := _get_difficulty_badge()
	if scarabs_total > 0:
		_stats_label.text = "%s   |   🪲 %d/%d   |   %s" % [time_str, scarabs_collected, scarabs_total, diff_str]
	else:
		_stats_label.text = "%s   |   %s" % [time_str, diff_str]

func register_player(id: int, initial_health: int) -> void:
	if player_labels.has(id):
		return

	var p_col := GameManager.get_player_color(id)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_temple_style(Color(0.08, 0.07, 0.11, 0.86), Color(p_col.r, p_col.g, p_col.b, 0.85), 2, 8))
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var name_lbl = Label.new()
	name_lbl.text = "P%d:" % id
	name_lbl.modulate = p_col

	player_max_health[id] = maxi(3, initial_health)
	player_prev_health[id] = initial_health

	var health_lbl = Label.new()
	health_lbl.text = _get_heart_string(initial_health, player_max_health[id])

	hbox.add_child(name_lbl)
	hbox.add_child(health_lbl)
	margin.add_child(hbox)
	panel.add_child(margin)
	players_container.add_child(panel)

	player_labels[id] = health_lbl

func update_player_health(id: int, new_health: int) -> void:
	if player_labels.has(id):
		var lbl = player_labels[id]
		var prev_h: int = int(player_prev_health.get(id, new_health))
		var max_h: int = int(player_max_health.get(id, 3))
		player_prev_health[id] = new_health
		lbl.text = _get_heart_string(new_health, max_h)
		var flash_col := Color(0.35, 1.9, 0.55) if new_health > prev_h else Color(2.0, 0.25, 0.25)
		var tween = create_tween()
		tween.tween_property(lbl, "modulate", flash_col, 0.09)
		tween.tween_property(lbl, "modulate", Color.WHITE, 0.24)

func _get_heart_string(health: int, max_h: int = 3) -> String:
	if health <= 0:
		return "💀 Downed"
	var s := ""
	for i in range(max_h):
		s += "❤️" if i < health else "🖤"
	return s

func show_chapter_banner(level_num: int) -> void:
	const CHAPTER_TITLES := {
		1: ["CHAPTER I", "THE DARK CATACOMBS"],
		2: ["CHAPTER II", "CHAMBER OF MIRRORS"],
		3: ["CHAPTER III", "VAULT OF TWIN MOONS"],
		4: ["FINAL CHAPTER", "THE GOLDEN IDOL"],
	}
	var info: Array = CHAPTER_TITLES.get(level_num, ["CHAPTER %d" % level_num, "ANCIENT SANCTUM"])

	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.add_theme_constant_override("margin_top", 108)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_temple_style(Color(0.06, 0.05, 0.09, 0.84), Color(0.95, 0.78, 0.28, 0.90), 2, 10))
	center.add_child(card)

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	card.add_child(pad)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	pad.add_child(vb)

	var kicker := Label.new()
	kicker.text = str(info[0])
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.modulate = Color(0.90, 0.80, 0.55)
	vb.add_child(kicker)

	var heading := Label.new()
	heading.text = str(info[1])
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.modulate = Color(1.0, 0.88, 0.28)
	vb.add_child(heading)

	add_child(holder)
	holder.modulate.a = 0.0
	var tw := holder.create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.45)
	tw.tween_interval(2.4)
	tw.tween_property(holder, "modulate:a", 0.0, 0.65)
	tw.chain().tween_callback(holder.queue_free)

func set_objective(text: String) -> void:
	objective_label.text = "Objective: " + text

func show_victory(text: String) -> void:
	banner_label.text = text
	banner_label.visible = true
	var tween = create_tween()
	banner_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(banner_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Shows a full-screen "Level Complete" overlay with next-level and menu buttons.
func show_level_complete(level_num: int) -> void:
	if _level_complete_panel:
		return  # Already showing

	# --- Dim background ---
	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var dim_tween = create_tween()
	dim_tween.tween_property(dim, "color", Color(0.0, 0.0, 0.0, 0.65), 0.6)

	# --- Center panel ---
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 340)
	panel.add_theme_stylebox_override("panel", _make_temple_style(Color(0.08, 0.07, 0.11, 0.95), Color(0.95, 0.78, 0.24, 1.0), 3, 14))
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var pad_win := MarginContainer.new()
	pad_win.add_theme_constant_override("margin_left", 28)
	pad_win.add_theme_constant_override("margin_right", 28)
	pad_win.add_theme_constant_override("margin_top", 24)
	pad_win.add_theme_constant_override("margin_bottom", 24)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)

	# Title
	var title = Label.new()
	var total_lvls = GameManager.get_total_levels() if is_instance_valid(GameManager) and GameManager.has_method("get_total_levels") else 3
	var is_final = level_num >= total_lvls
	title.text = "CAMPAIGN COMPLETED!" if is_final else "LEVEL %d COMPLETE!" % level_num
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48 if is_final else 52)
	title.modulate = Color(1.0, 0.85, 0.2)  # Golden

	# Sub-text
	var sub = Label.new()
	sub.text = "Congratulations! The Golden Idol has been secured and the adventure is complete!" if is_final else "The temple's secret has been unveiled!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.9, 0.9, 0.85)

	# Run summary (Time + Scarabs) + Save Progression
	var is_new_record := false
	if is_instance_valid(GameManager) and GameManager.has_method("record_level_clear"):
		is_new_record = GameManager.record_level_clear(level_num, elapsed_time, scarabs_collected, scarabs_total)

	var show_prog := is_instance_valid(SettingsManager) and SettingsManager.show_progression_indicators
	var show_new_record := show_prog and is_new_record

	var stats = Label.new()
	var stats_text := "Clear Time: %s" % _format_time(elapsed_time)
	if scarabs_total > 0:
		stats_text += "   •   Scarabs: %d/%d" % [scarabs_collected, scarabs_total]
	if show_new_record:
		stats_text += "   ★ NEW BEST!"
	stats.text = stats_text
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.modulate = Color(1.0, 0.9, 0.35) if show_new_record else Color(0.75, 0.92, 1.0)

	# Next level button
	var btn_next = Button.new()
	btn_next.text = "Complete Adventure 🏆" if is_final else "Next Level  →"
	btn_next.custom_minimum_size = Vector2(240, 54)
	btn_next.pressed.connect(func():
		get_tree().paused = false
		next_level_pressed.emit()
		if is_instance_valid(GameManager):
			GameManager.next_level()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

	# Menu button
	var btn_menu = Button.new()
	btn_menu.text = "Back to Menu"
	btn_menu.custom_minimum_size = Vector2(240, 42)
	btn_menu.pressed.connect(func():
		get_tree().paused = false
		menu_pressed.emit()
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

	var rank_lbl := Label.new()
	if scarabs_total > 0 and scarabs_collected >= scarabs_total:
		rank_lbl.text = "★★★  MASTER RAIDER"
		rank_lbl.modulate = Color(1.0, 0.88, 0.25)
	elif scarabs_collected >= 1:
		rank_lbl.text = "★★☆  TEMPLE EXPLORER"
		rank_lbl.modulate = Color(0.85, 0.92, 1.0)
	else:
		rank_lbl.text = "★☆☆  SURVIVOR"
		rank_lbl.modulate = Color(0.82, 0.78, 0.70)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 22)

	vbox.add_child(title)
	vbox.add_child(rank_lbl)
	vbox.add_child(sub)
	vbox.add_child(stats)
	vbox.add_child(btn_next)
	vbox.add_child(btn_menu)
	pad_win.add_child(vbox)
	panel.add_child(pad_win)
	add_child(panel)

	_level_complete_panel = panel
	process_mode = Node.PROCESS_MODE_ALWAYS  # HUD still runs while paused

	# Animate panel sliding in from below
	panel.position.y += 120
	panel.modulate.a = 0.0
	var p_tween = create_tween().set_parallel(true)
	p_tween.tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.3)
	p_tween.tween_property(panel, "position:y", panel.position.y - 120, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)

	get_tree().paused = true
	btn_next.grab_focus()

## Shows a full-screen Game Over overlay when all players have perished.
func show_game_over() -> void:
	if _game_over_panel or _level_complete_panel:
		return

	# Dark red vignette dimmer
	var dim = ColorRect.new()
	dim.color = Color(0.1, 0.0, 0.0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var dim_tween = create_tween()
	dim_tween.tween_property(dim, "color", Color(0.15, 0.02, 0.02, 0.8), 0.5)

	# Panel container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 320)
	panel.add_theme_stylebox_override("panel", _make_temple_style(Color(0.11, 0.05, 0.06, 0.95), Color(0.88, 0.22, 0.20, 0.95), 3, 14))
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)

	# Title
	var title = Label.new()
	title.text = "💀 GAME OVER 💀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color(0.95, 0.2, 0.2)

	# Subtitle
	var sub = Label.new()
	sub.text = "All adventurers have perished in the temple..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.85, 0.8, 0.8)

	# Retry button
	var btn_retry = Button.new()
	btn_retry.text = "Try Again  ↺"
	btn_retry.custom_minimum_size = Vector2(240, 52)
	btn_retry.pressed.connect(func():
		get_tree().paused = false
		if is_instance_valid(GameManager):
			GameManager.restart_current_level()
		else:
			get_tree().reload_current_scene()
	)

	# Menu button
	var btn_menu = Button.new()
	btn_menu.text = "Back to Menu"
	btn_menu.custom_minimum_size = Vector2(240, 42)
	btn_menu.pressed.connect(func():
		get_tree().paused = false
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

	vbox.add_child(title)
	vbox.add_child(sub)
	vbox.add_child(btn_retry)
	vbox.add_child(btn_menu)
	panel.add_child(vbox)
	add_child(panel)

	_game_over_panel = panel
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Animate panel sliding down from above
	panel.position.y -= 100
	panel.modulate.a = 0.0
	var p_tween = create_tween().set_parallel(true)
	p_tween.tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.2)
	p_tween.tween_property(panel, "position:y", panel.position.y + 100, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)

	get_tree().paused = true
	btn_retry.grab_focus()

## Toggles the in-game pause menu. Returns true if paused, false if resumed.
func toggle_pause() -> void:
	if _level_complete_panel or _game_over_panel:
		return

	if _pause_panel:
		_close_pause_menu()
	else:
		_open_pause_menu()

func _open_pause_menu() -> void:
	_pause_dim = ColorRect.new()
	_pause_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 340)
	panel.add_theme_stylebox_override("panel", _make_temple_style(Color(0.08, 0.07, 0.11, 0.95), Color(0.90, 0.74, 0.26, 0.95), 3, 14))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.modulate = Color(1.0, 0.85, 0.25)

	var controls_box := Label.new()
	controls_box.text = "P1: WASD + E (Interact) + Space (Whip) + Shift/F (Roll)\nP2: Arrows + Enter (Interact) + R-Shift (Whip) + / (Roll)\nCamera: Q / R or Right-Click Drag"
	controls_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_box.add_theme_font_size_override("font_size", 14)
	controls_box.modulate = Color(0.85, 0.85, 0.8)
	controls_box.visible = false

	var btn_resume := Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(240, 44)
	btn_resume.pressed.connect(_close_pause_menu)

	var btn_restart := Button.new()
	btn_restart.text = "Restart Level"
	btn_restart.custom_minimum_size = Vector2(240, 42)
	btn_restart.pressed.connect(func():
		_close_pause_menu()
		if is_instance_valid(GameManager):
			GameManager.restart_current_level()
		else:
			get_tree().reload_current_scene()
	)

	var btn_controls := Button.new()
	btn_controls.text = "Controls"
	btn_controls.custom_minimum_size = Vector2(240, 42)
	btn_controls.pressed.connect(func():
		controls_box.visible = not controls_box.visible
	)

	var btn_settings := Button.new()
	btn_settings.text = "Settings"
	btn_settings.custom_minimum_size = Vector2(240, 42)
	btn_settings.pressed.connect(func():
		panel.visible = false
		var settings := SETTINGS_MENU_SCRIPT.new()
		add_child(settings)
		settings.closed.connect(func():
			if is_instance_valid(panel):
				panel.visible = true
				btn_settings.grab_focus()
		)
	)

	var btn_menu := Button.new()
	btn_menu.text = "Back to Menu"
	btn_menu.custom_minimum_size = Vector2(240, 42)
	btn_menu.pressed.connect(func():
		_close_pause_menu()
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

	vbox.add_child(title)
	vbox.add_child(btn_resume)
	vbox.add_child(btn_restart)
	vbox.add_child(btn_controls)
	vbox.add_child(controls_box)
	vbox.add_child(btn_settings)
	vbox.add_child(btn_menu)
	margin.add_child(vbox)
	panel.add_child(margin)

	_pause_panel = center
	get_tree().paused = true
	btn_resume.grab_focus()

func _close_pause_menu() -> void:
	if is_instance_valid(_pause_panel):
		_pause_panel.queue_free()
	if is_instance_valid(_pause_dim):
		_pause_dim.queue_free()
	_pause_panel = null
	_pause_dim = null
	get_tree().paused = false

## Displays a brief fading controls hint at the bottom of the screen.
func show_controls_hint(duration: float = 7.5) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_bottom", 26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(pad)

	var interact_key := SettingsManager.get_action_key_label("p1_interact") if is_instance_valid(SettingsManager) else "E"
	var whip_key := SettingsManager.get_action_key_label("p1_action") if is_instance_valid(SettingsManager) else "Space"
	var cam_l := SettingsManager.get_action_key_label("cam_rotate_left") if is_instance_valid(SettingsManager) else "Q"
	var cam_r := SettingsManager.get_action_key_label("cam_rotate_right") if is_instance_valid(SettingsManager) else "R"

	var lbl := Label.new()
	lbl.text = "Move: WASD   •   Interact / Grab: [%s]   •   Whip: [%s]   •   Roll: [Shift]   •   Camera: [%s / %s]" % [interact_key, whip_key, cam_l, cam_r]
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.modulate = Color(1.0, 0.94, 0.78)
	pad.add_child(lbl)

	add_child(margin)
	margin.modulate.a = 0.0
	var tween := margin.create_tween()
	tween.tween_property(margin, "modulate:a", 1.0, 0.4)
	tween.tween_interval(duration)
	tween.tween_property(margin, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(margin.queue_free)
