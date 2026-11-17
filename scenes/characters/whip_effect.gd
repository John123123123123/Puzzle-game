extends Node3D
class_name WhipEffect

@onready var mesh: MeshInstance3D = $MeshInstance3D

func lash(from: Vector3, to: Vector3, duration: float = 0.25) -> void:
	global_position = from
	look_at(to, Vector3.UP)
	var dist = from.distance_to(to)
	scale = Vector3(1, 1, dist)

	var tween = create_tween()
	mesh.transparency = 0.0
	tween.tween_property(mesh, "transparency", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(self):
		queue_free()
