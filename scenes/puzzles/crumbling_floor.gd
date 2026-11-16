extends StaticBody3D
class_name CrumblingFloor

@export var collapse_delay: float = 0.75
@export var respawn_time: float = 4.0
@export var can_respawn: bool = true

var is_collapsing: bool = false
var original_position: Vector3

@onready var tile_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var trigger_area: Area3D = $TriggerArea

func _ready() -> void:
	original_position = position
	trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_collapsing:
		return
	if body is Player or body is PushableBlock:
		start_collapse()

func start_collapse() -> void:
	is_collapsing = true

	# Shake animation
	var tween = create_tween().set_loops(6)
	tween.tween_property(tile_mesh, "position:x", 0.05, collapse_delay / 12.0)
	tween.tween_property(tile_mesh, "position:x", -0.05, collapse_delay / 12.0)
	await get_tree().create_timer(collapse_delay).timeout

	# Drop down
	collision_shape.set_deferred("disabled", true)
	var fall_tween = create_tween()
	fall_tween.tween_property(self, "position:y", original_position.y - 12.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(tile_mesh, "transparency", 1.0, 0.4)
	await fall_tween.finished

	visible = false

	if can_respawn:
		await get_tree().create_timer(respawn_time).timeout
		respawn_tile()

func respawn_tile() -> void:
	position = original_position
	tile_mesh.position = Vector3.ZERO
	tile_mesh.transparency = 0.0
	visible = true
	collision_shape.set_deferred("disabled", false)
	is_collapsing = false
