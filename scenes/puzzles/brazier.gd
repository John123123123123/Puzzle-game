extends Node3D
class_name Brazier

signal lit_state_changed(is_lit: bool)

@export var is_lit: bool = false
@export var linked_targets: Array[NodePath] = []

@onready var flame_mesh: MeshInstance3D = $FlameMesh
@onready var fire_light: OmniLight3D = $FireLight
@onready var interaction_area: Area3D = $InteractionArea

func _ready() -> void:
	add_to_group("brazier")
	add_to_group("interactable")
	interaction_area.body_entered.connect(_on_body_entered)
	_update_visuals(false)

func interact(player: Player) -> void:
	# If player is carrying a torch or interacting, light the brazier
	if not is_lit:
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
	_update_visuals(true)
	lit_state_changed.emit(true)

	for path in linked_targets:
		var node = get_node_or_null(path)
		if node and node.has_method("register_trigger_activated"):
			node.register_trigger_activated()

func _update_visuals(animate: bool) -> void:
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
