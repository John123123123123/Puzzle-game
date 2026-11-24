extends Node3D
class_name Brazier

signal lit_state_changed(is_lit: bool)

@export var is_lit: bool = false
@export var linked_targets: Array[NodePath] = []

@onready var flame_mesh: MeshInstance3D = $FlameMesh
@onready var fire_light: OmniLight3D = $FireLight
@onready var interaction_area: Area3D = $InteractionArea

var _flicker_time: float = 0.0

func _ready() -> void:
	add_to_group("brazier")
	add_to_group("interactable")
	interaction_area.body_entered.connect(_on_body_entered)
	_flicker_time = randf() * 10.0
	_update_visuals(false)

func _process(delta: float) -> void:
	if is_lit and is_instance_valid(fire_light):
		_flicker_time += delta
		fire_light.light_energy = 2.4 + sin(_flicker_time * 11.0) * 0.18 + sin(_flicker_time * 23.0) * 0.1

func get_interact_prompt() -> String:
	return "" if is_lit else "Requires Torch"

func get_interact_prompt_for(player: Player) -> String:
	if is_lit:
		return ""
	if is_instance_valid(player) and player.carried_item is Torch:
		return "Light Brazier"
	return "Requires Torch"

func interact(player: Player) -> void:
	if not is_lit and is_instance_valid(player) and player.carried_item is Torch:
		ignite()

func on_whipped(player: Player) -> void:
	# Whipping with a fiery whip or just interaction can trigger
	pass

func _on_body_entered(body: Node3D) -> void:
	if is_lit:
		return
	if body is Player and body.carried_item is Torch:
		ignite()

func ignite() -> void:
	if is_lit:
		return
	is_lit = true
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"brazier_ignite", global_position, 0.94, 1.06, -1.0, 20.0, 5.0)
	_update_visuals(true)
	lit_state_changed.emit(true)

	for path in linked_targets:
		var node = get_node_or_null(path)
		if node and node.has_method("register_trigger_activated"):
			node.register_trigger_activated()

func _update_visuals(animate: bool) -> void:
	set_process(is_lit)
	flame_mesh.visible = is_lit
	if fire_light:
		if is_lit:
			fire_light.light_energy = 2.5
			if animate:
				var tween = create_tween()
				fire_light.light_energy = 0.0
				tween.tween_property(fire_light, "light_energy", 2.5, 0.4).set_trans(Tween.TRANS_QUAD)
		else:
			fire_light.light_energy = 0.0
