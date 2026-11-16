extends CanvasLayer
class_name GameHUD

signal next_level_pressed
signal menu_pressed

@onready var objective_label: Label = $MarginContainer/VBoxContainer/ObjectiveLabel
@onready var players_container: HBoxContainer = $MarginContainer/VBoxContainer/PlayersContainer
@onready var banner_label: Label = $CenterContainer/BannerLabel

const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2), # P1 Red
	Color(0.2, 0.5, 0.9),  # P2 Blue
	Color(0.2, 0.75, 0.3), # P3 Green
	Color(0.9, 0.75, 0.15) # P4 Yellow
]

var player_labels: Dictionary = {}
var _level_complete_panel: Control = null
var _game_over_panel: Control = null

func _ready() -> void:
	add_to_group("hud")
	banner_label.visible = false

func register_player(id: int, initial_health: int) -> void:
	if player_labels.has(id):
		return

	var panel = PanelContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var color_idx = clampi(id - 1, 0, PLAYER_COLORS.size() - 1)
	var name_lbl = Label.new()
	name_lbl.text = "P%d:" % id
	name_lbl.modulate = PLAYER_COLORS[color_idx]

	var health_lbl = Label.new()
	health_lbl.text = _get_heart_string(initial_health)

	hbox.add_child(name_lbl)
	hbox.add_child(health_lbl)
	margin.add_child(hbox)
	panel.add_child(margin)
	players_container.add_child(panel)

	player_labels[id] = health_lbl

func update_player_health(id: int, new_health: int) -> void:
	if player_labels.has(id):
		player_labels[id].text = _get_heart_string(new_health)

func _get_heart_string(health: int) -> String:
	var s = ""
	for i in range(max(0, health)):
		s += "❤️"
	if health <= 0:
		s = "💀 Besegrad"
	return s

func set_objective(text: String) -> void:
	objective_label.text = "Uppdrag: " + text

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
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 300)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)

	# Title
	var title = Label.new()
	var total_lvls = GameManager.get_total_levels() if is_instance_valid(GameManager) and GameManager.has_method("get_total_levels") else 3
	var is_final = level_num >= total_lvls
	title.text = "KAMPANJEN KLARAD!" if is_final else "NIVÅ %d KLAR!" % level_num
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48 if is_final else 52)
	title.modulate = Color(1.0, 0.85, 0.2)  # Golden

	# Sub-text
	var sub = Label.new()
	sub.text = "Grattis! Guldidolen är bärgad och äventyret är fullbordat!" if is_final else "Templets hemlighet är avslöjad!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.9, 0.9, 0.85)

	# Next level button
	var btn_next = Button.new()
	btn_next.text = "Slutför Äventyret 🏆" if is_final else "Nästa Nivå  →"
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
	btn_menu.text = "Tillbaka till Menyn"
	btn_menu.custom_minimum_size = Vector2(240, 42)
	btn_menu.pressed.connect(func():
		get_tree().paused = false
		menu_pressed.emit()
		if is_instance_valid(GameManager):
			GameManager.return_to_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

	vbox.add_child(title)
	vbox.add_child(sub)
	vbox.add_child(btn_next)
	vbox.add_child(btn_menu)
	panel.add_child(vbox)
	add_child(panel)

	_level_complete_panel = panel

	# Animate panel sliding in from below
	panel.position.y += 120
	panel.modulate.a = 0.0
	var p_tween = create_tween().set_parallel(true)
	p_tween.tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.3)
	p_tween.tween_property(panel, "position:y", panel.position.y - 120, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)

	# Pause the game tree while the screen is up (optional — keeps input working)
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS  # HUD still runs while paused

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
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 320)

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
	sub.text = "Alla äventyrare har fallit i templet..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.85, 0.8, 0.8)

	# Retry button
	var btn_retry = Button.new()
	btn_retry.text = "Försök Igen  ↺"
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
	btn_menu.text = "Tillbaka till Menyn"
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

	# Animate panel sliding down from above
	panel.position.y -= 100
	panel.modulate.a = 0.0
	var p_tween = create_tween().set_parallel(true)
	p_tween.tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.2)
	p_tween.tween_property(panel, "position:y", panel.position.y + 100, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)

	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_retry.grab_focus()
