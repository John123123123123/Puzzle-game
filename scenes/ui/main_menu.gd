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

# Quick select buttons
@onready var btn_1p: Button = $VBoxContainer/QuickButtons/Btn1P
@onready var btn_2p: Button = $VBoxContainer/QuickButtons/Btn2P
@onready var btn_3p: Button = $VBoxContainer/QuickButtons/Btn3P
@onready var btn_4p: Button = $VBoxContainer/QuickButtons/Btn4P

# Level selector buttons
@onready var btn_lvl1: Button = $VBoxContainer/LevelSelector/BtnLvl1
@onready var btn_lvl2: Button = $VBoxContainer/LevelSelector/BtnLvl2
@onready var btn_lvl3: Button = $VBoxContainer/LevelSelector/BtnLvl3

var selected_count: int = 1
var selected_level: int = 1
var player_cards: Array[PanelContainer] = []
var level_buttons: Array[Button] = []

func _ready() -> void:
	player_cards = [card_1, card_2, card_3, card_4]
	level_buttons = [btn_lvl1, btn_lvl2, btn_lvl3]

	btn_minus.pressed.connect(_on_minus_pressed)
	btn_plus.pressed.connect(_on_plus_pressed)
	start_button.pressed.connect(_on_start_pressed)

	btn_1p.pressed.connect(func(): set_player_count(1))
	btn_2p.pressed.connect(func(): set_player_count(2))
	btn_3p.pressed.connect(func(): set_player_count(3))
	btn_4p.pressed.connect(func(): set_player_count(4))

	btn_lvl1.pressed.connect(func(): set_selected_level(1))
	btn_lvl2.pressed.connect(func(): set_selected_level(2))
	btn_lvl3.pressed.connect(func(): set_selected_level(3))

	set_player_count(1)
	set_selected_level(1)

	var vbox := get_node_or_null("VBoxContainer")
	if vbox:
		var btn_settings := Button.new()
		btn_settings.text = "Settings"
		btn_settings.custom_minimum_size = Vector2(220, 44)
		btn_settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_settings.pressed.connect(func(): _open_settings(btn_settings))
		vbox.add_child(btn_settings)

	start_button.grab_focus()

const SETTINGS_MENU_SCRIPT := preload("res://scenes/ui/settings_menu.gd")

func _open_settings(return_focus: Button) -> void:
	var settings := SETTINGS_MENU_SCRIPT.new()
	add_child(settings)
	settings.closed.connect(func():
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
	selected_level = clampi(lvl, 1, 3)
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
	if is_instance_valid(GameManager):
		GameManager.start_game(selected_count, selected_level)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p2_interact") and selected_count < 2:
		set_player_count(2)
	elif event.is_action_pressed("p3_interact") and selected_count < 3:
		set_player_count(3)
	elif event.is_action_pressed("p4_interact") and selected_count < 4:
		set_player_count(4)

	if event.is_action_pressed("ui_accept") and not start_button.has_focus():
		_on_start_pressed()
