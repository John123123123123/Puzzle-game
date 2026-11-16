extends Area3D
class_name DartProjectile

@export var speed: float = 14.0
@export var max_distance: float = 12.0
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
		_spawn_impact(true)
		queue_free()
	elif not (body is Area3D):
		# Hit wall or pushable block
		_spawn_impact(false)
		queue_free()

func _spawn_impact(hit_player: bool) -> void:
	# Create a brief visual impact spark/chip
	var spark = OmniLight3D.new()
	spark.light_color = Color(1.0, 0.2, 0.1) if hit_player else Color(0.3, 1.0, 0.4)
	spark.light_energy = 2.0
	spark.omni_range = 1.5
	get_parent().add_child(spark)
	spark.global_position = global_position

	var tween = spark.create_tween()
	tween.tween_property(spark, "light_energy", 0.0, 0.15)
	tween.chain().tween_callback(spark.queue_free)
