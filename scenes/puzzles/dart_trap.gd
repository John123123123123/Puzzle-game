extends Node3D
class_name DartTrap

@export var shoot_interval: float = 2.5
@export var dart_speed: float = 12.0
@export var dart_range: float = 10.0
@export var is_active: bool = true

var timer: float = 0.0

@onready var spawn_point: Marker3D = $SpawnPoint

func _process(delta: float) -> void:
	if not is_active:
		return

	timer += delta
	if timer >= shoot_interval:
		timer = 0.0
		_shoot_dart()

func _shoot_dart() -> void:
	var dart = preload("res://scenes/puzzles/dart_projectile.tscn").instantiate()
	get_parent().add_child(dart)
	dart.global_position = spawn_point.global_position
	dart.global_rotation = global_rotation
	dart.speed = dart_speed
	dart.max_distance = dart_range
