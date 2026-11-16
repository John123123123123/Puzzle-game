extends Area3D
class_name LevelExit

signal level_completed()

@export var prompt_text: String = "NIVÅ KLARAD!\nPORTEN TILL NÄSTA KAMMARE ÄR ÖPPEN!"
@export var is_unlocked: bool = true

var triggered: bool = false
@onready var light: OmniLight3D = $OmniLight3D
@onready var portal_mesh: MeshInstance3D = $PortalMesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()

func unlock() -> void:
	is_unlocked = true
	_update_visuals()

func _update_visuals() -> void:
	if light:
		light.light_energy = 2.0 if is_unlocked else 0.2
		light.light_color = Color(0.2, 0.9, 1.0) if is_unlocked else Color(0.8, 0.3, 0.1)

func _on_body_entered(body: Node3D) -> void:
	if not is_unlocked or triggered:
		return

	if body is Player:
		triggered = true
		level_completed.emit()

		# Notify HUD if present
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
