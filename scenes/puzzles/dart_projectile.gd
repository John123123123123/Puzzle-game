extends Area3D
class_name DartProjectile

var speed: float = 12.0
var max_distance: float = 12.0
var traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var move_vec = -global_basis.z * speed * delta
	global_position += move_vec
	traveled += move_vec.length()

	if traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.take_damage(1)
		queue_free()
	elif not (body is Area3D):
		# Hit wall or block
		queue_free()
