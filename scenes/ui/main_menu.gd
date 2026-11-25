extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var player_count_label: Label = $VBoxContainer/CountSelector/PlayerCountLabel
@onready var btn_minus: Button = $VBoxContainer/CountSelector/BtnMinus
@onready var btn_plus: Button = $VBoxContainer/CountSelector/BtnPlus
@onready var start_button: Button = $VBoxContainer/StartButton

# Player cards
@onready var card_1: PanelContainer = $VBoxContainer/CardsContainer/Card1
@onready var card_2: PanelContainer = $VBoxContainer/CardsContainer/Card2
@onready var card_3: PanelContainer = $VBoxContainer/CardsContainer/Card3
@onready var card_4: PanelContainer = $VBoxContainer/CardsContainer/Card4

# Level selector buttons
@onready var btn_lvl1: Button = $VBoxContainer/LevelSelector/BtnLvl1
@onready var btn_lvl2: Button = $VBoxContainer/LevelSelector/BtnLvl2
@onready var btn_lvl3: Button = $VBoxContainer/LevelSelector/BtnLvl3
@onready var btn_lvl4: Button = $VBoxContainer/LevelSelector/BtnLvl4

var selected_count: int = 1
var selected_level: int = 1
var player_cards: Array[PanelContainer] = []
var level_buttons: Array[Button] = []
var _base_level_labels: Array[String] = []
var _settings_open: bool = false
var _title_pulse: float = 0.0
var _btn_update: Button = null
var _version_label: Label = null
var _campaign_summary_label: Label = null

func _process(delta: float) -> void:
	_title_pulse += delta * 2.2
	if is_instance_valid(title_label):
		var glow := 0.92 + sin(_title_pulse) * 0.08
		title_label.modulate = Color(1.0, glow, 0.72 + sin(_title_pulse) * 0.14)
	if is_instance_valid(_btn_update) and is_instance_valid(UpdateManager) and UpdateManager.update_available:
		var pulse := 0.86 + sin(_title_pulse * 2.0) * 0.14
		_btn_update.modulate = Color(0.45 * pulse + 0.15, 1.0, 0.52 * pulse + 0.1)

func _ready() -> void:
	player_cards = [card_1, card_2, card_3, card_4]
	level_buttons = [btn_lvl1, btn_lvl2, btn_lvl3, btn_lvl4]
	for btn in level_buttons:
		_base_level_labels.append(btn.text)

	btn_minus.pressed.connect(_on_minus_pressed)
	btn_plus.pressed.connect(_on_plus_pressed)
	start_button.pressed.connect(_on_start_pressed)

	btn_lvl1.pressed.connect(func(): set_selected_level(1))
	btn_lvl2.pressed.connect(func(): set_selected_level(2))
	btn_lvl3.pressed.connect(func(): set_selected_level(3))
	btn_lvl4.pressed.connect(func(): set_selected_level(4))

	set_player_count(1)
	set_selected_level(1)
	_populate_level_progress()
	if is_instance_valid(SettingsManager):
		SettingsManager.settings_changed.connect(_populate_level_progress)

	var vbox := get_node_or_null("VBoxContainer")
	if vbox:
		_campaign_summary_label = Label.new()
		_campaign_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_campaign_summary_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(_campaign_summary_label)

		var action_row := HBoxContainer.new()
		action_row.alignment = BoxContainer.ALIGNMENT_CENTER
		action_row.add_theme_constant_override("separation", 16)

		var btn_online := Button.new()
		btn_online.text = "🌐 Online / LAN Co-op"
		btn_online.custom_minimum_size = Vector2(220, 44)
		btn_online.modulate = Color(0.55, 0.95, 1.0)
		btn_online.pressed.connect(func(): _open_online_lobby(btn_online))
		action_row.add_child(btn_online)

		var update_group := HBoxContainer.new()
		update_group.alignment = BoxContainer.ALIGNMENT_CENTER
		update_group.add_theme_constant_override("separation", 8)

		_btn_update = Button.new()
		_btn_update.text = "⬇ Update Game"
		_btn_update.custom_minimum_size = Vector2(185, 44)
		_btn_update.modulate = Color(0.95, 0.88, 0.62)
		_btn_update.pressed.connect(func(): _open_updater(_btn_update))
		update_group.add_child(_btn_update)

		var ver_badge := PanelContainer.new()
		var ver_sb := StyleBoxFlat.new()
		ver_sb.bg_color = Color(0.12, 0.11, 0.16, 0.92)
		ver_sb.border_color = Color(0.75, 0.62, 0.25, 0.75)
		ver_sb.border_width_left = 1
		ver_sb.border_width_top = 1
		ver_sb.border_width_right = 1
		ver_sb.border_width_bottom = 1
		ver_sb.corner_radius_top_left = 8
		ver_sb.corner_radius_top_right = 8
		ver_sb.corner_radius_bottom_left = 8
		ver_sb.corner_radius_bottom_right = 8
		ver_sb.content_margin_left = 10
		ver_sb.content_margin_right = 10
		ver_sb.content_margin_top = 6
		ver_sb.content_margin_bottom = 6
		ver_badge.add_theme_stylebox_override("panel", ver_sb)

		_version_label = Label.new()
		_version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_version_label.add_theme_font_size_override("font_size", 13)
		_version_label.modulate = Color(0.90, 0.85, 0.68)
		_version_label.text = UpdateManager.get_display_version() if is_instance_valid(UpdateManager) else "v1.5.0"
		ver_badge.add_child(_version_label)
		update_group.add_child(ver_badge)

		action_row.add_child(update_group)

		var btn_settings := Button.new()
		btn_settings.text = "Settings"
		btn_settings.custom_minimum_size = Vector2(150, 44)
		btn_settings.pressed.connect(func(): _open_settings(btn_settings))
		action_row.add_child(btn_settings)

		var btn_exit := Button.new()
		btn_exit.text = "Exit Game"
		btn_exit.custom_minimum_size = Vector2(140, 44)
		btn_exit.modulate = Color(1.0, 0.62, 0.62)
		btn_exit.pressed.connect(func():
			if is_instance_valid(NetworkManager) and NetworkManager.is_online:
				NetworkManager.disconnect_session()
			get_tree().quit()
		)
		action_row.add_child(btn_exit)

		vbox.add_child(action_row)

		if is_instance_valid(UpdateManager):
			UpdateManager.state_changed.connect(_refresh_update_button)
			_refresh_update_button()
			UpdateManager.auto_check_on_menu()
		_populate_level_progress()

		# Re-open lobby automatically if returning to menu while an online session is still connected
		if is_instance_valid(NetworkManager) and NetworkManager.is_online:
			call_deferred("_open_online_lobby", btn_online)

	start_button.grab_focus()

const SETTINGS_MENU_SCRIPT := preload("res://scenes/ui/settings_menu.gd")
const ONLINE_LOBBY_SCRIPT := preload("res://scenes/ui/online_lobby.gd")
const UPDATE_DIALOG_SCRIPT := preload("res://scenes/ui/update_dialog.gd")

func _refresh_update_button() -> void:
	if is_instance_valid(_version_label) and is_instance_valid(UpdateManager):
		_version_label.text = UpdateManager.get_display_version()
		_version_label.modulate = Color(1.0, 0.90, 0.42) if UpdateManager.update_available else Color(0.88, 0.86, 0.76)
	if not is_instance_valid(_btn_update) or not is_instance_valid(UpdateManager):
		return
	if UpdateManager.is_installing:
		_btn_update.text = "⏳ Updating..."
		_btn_update.modulate = Color(1.0, 0.85, 0.4)
	elif UpdateManager.restart_recommended:
		_btn_update.text = "🚀 Restart to Finish Update"
		_btn_update.modulate = Color(0.45, 1.0, 0.55)
	elif UpdateManager.update_available:
		_btn_update.text = "⬇ Update Available!" if not UpdateManager.update_building else "⬇ Update Available (newer build pending)"
		_btn_update.modulate = Color(0.45, 1.0, 0.58)
	elif not UpdateManager.remote_sha.is_empty():
		_btn_update.text = "✓ Up to Date"
		_btn_update.modulate = Color(0.80, 0.92, 0.82)
	else:
		_btn_update.text = "⬇ Update Game"
		_btn_update.modulate = Color(0.95, 0.88, 0.62)

func _open_updater(return_focus: Button) -> void:
	if _settings_open:
		return
	_settings_open = true
	var dlg := UPDATE_DIALOG_SCRIPT.new()
	add_child(dlg)
	dlg.closed.connect(func():
		_settings_open = false
		_refresh_update_button()
		if is_instance_valid(return_focus):
			return_focus.grab_focus()
	)

func _populate_level_progress() -> void:
	var show_prog := is_instance_valid(SettingsManager) and SettingsManager.show_progression_indicators
	for i in range(level_buttons.size()):
		var btn := level_buttons[i]
		var base_text := _base_level_labels[i] if i < _base_level_labels.size() else btn.text
		if not show_prog or not is_instance_valid(GameManager):
			btn.text = base_text
			continue
		var prog := GameManager.get_level_progress(i + 1)
		if not prog.is_empty() and float(prog.get("best_time", -1.0)) >= 0.0:
			var t_str := GameManager.format_time(float(prog["best_time"]))
			var s_got := int(prog.get("best_scarabs", 0))
			var s_tot := int(prog.get("total_scarabs", 3))
			btn.text = "%s\n⏱ %s   🪲 %d/%d" % [base_text, t_str, s_got, s_tot]
		else:
			btn.text = base_text

	if is_instance_valid(_campaign_summary_label):
		if not show_prog or not is_instance_valid(GameManager) or not GameManager.has_method("get_campaign_summary"):
			_campaign_summary_label.visible = false
		else:
			var sum: Dictionary = GameManager.get_campaign_summary()
			var clr := int(sum.get("cleared", 0))
			var tot_l := int(sum.get("total_levels", 4))
			var sc := int(sum.get("scarabs", 0))
			var max_sc := int(sum.get("max_scarabs", 20))
			_campaign_summary_label.visible = (clr > 0 or sc > 0)
			if clr >= tot_l and sc >= max_sc:
				_campaign_summary_label.text = "🏆 GRAND MASTER OF THE LOST TEMPLE   •   %d/%d Chambers   •   🪲 %d/%d Scarabs" % [clr, tot_l, sc, max_sc]
				_campaign_summary_label.modulate = Color(1.0, 0.88, 0.28)
			else:
				_campaign_summary_label.text = "🏛️ Expedition Record: %d/%d Chambers Cleared   •   🪲 %d/%d Golden Scarabs" % [clr, tot_l, sc, max_sc]
				_campaign_summary_label.modulate = Color(0.85, 0.90, 0.96)

func _open_online_lobby(return_focus: Button) -> void:
	if _settings_open:
		return
	if is_instance_valid(UpdateManager) and UpdateManager.is_installing:
		return
	_settings_open = true
	var lobby := ONLINE_LOBBY_SCRIPT.new()
	add_child(lobby)
	lobby.closed.connect(func():
		_settings_open = false
		if is_instance_valid(return_focus):
			return_focus.grab_focus()
	)

func _open_settings(return_focus: Button) -> void:
	if _settings_open:
		return
	_settings_open = true
	var settings := SETTINGS_MENU_SCRIPT.new()
	add_child(settings)
	settings.closed.connect(func():
		_settings_open = false
		if is_instance_valid(return_focus):
			return_focus.grab_focus()
	)

func set_player_count(count: int) -> void:
	selected_count = clampi(count, 1, 4)
	player_count_label.text = "%d Player" % selected_count if selected_count == 1 else "%d Players" % selected_count

	for i in range(player_cards.size()):
		var is_active = (i + 1) <= selected_count
		var card = player_cards[i]
		if is_active:
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
			var status = card.get_node_or_null("VBox/StatusLabel")
			if status:
				status.text = "READY"
				status.modulate = Color(0.3, 1.0, 0.4)
		else:
			card.modulate = Color(0.4, 0.4, 0.4, 0.5)
			var status = card.get_node_or_null("VBox/StatusLabel")
			if status:
				status.text = "INACTIVE"
				status.modulate = Color(0.7, 0.7, 0.7)

func set_selected_level(lvl: int) -> void:
	selected_level = clampi(lvl, 1, level_buttons.size())
	for i in range(level_buttons.size()):
		var btn = level_buttons[i]
		if (i + 1) == selected_level:
			btn.modulate = Color(1.0, 0.9, 0.3)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)

func _on_minus_pressed() -> void:
	set_player_count(selected_count - 1)

func _on_plus_pressed() -> void:
	set_player_count(selected_count + 1)

func _on_start_pressed() -> void:
	if is_instance_valid(UpdateManager) and UpdateManager.is_installing:
		return
	# Starting from main button runs Local Couch Co-op (close any stale online peer first)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		NetworkManager.disconnect_session()
	if is_instance_valid(GameManager):
		GameManager.start_game(selected_count, selected_level)

func _unhandled_input(event: InputEvent) -> void:
	if _settings_open:
		return
	if event.is_action_pressed("p2_interact") and selected_count < 2:
		set_player_count(2)
	elif event.is_action_pressed("p3_interact") and selected_count < 3:
		set_player_count(3)
	elif event.is_action_pressed("p4_interact") and selected_count < 4:
		set_player_count(4)

	if event.is_action_pressed("ui_accept") and get_viewport().gui_get_focus_owner() == null:
		_on_start_pressed()
