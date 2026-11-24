extends Node3D
class_name DartTrap

@export var shoot_interval: float = 1.8
@export var dart_speed: float = 9.5
@export var dart_range: float = 10.0
@export var is_active: bool = true
@export var trigger_delay: float = 0.28

var _cooldown_timer: float = 0.0
var _is_triggering: bool = false
var _players_in_range: Array[Player] = []
var _los_query: PhysicsRayQueryParameters3D = null

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var trigger_area: Area3D = $TriggerArea

func _ready() -> void:
	_los_query = PhysicsRayQueryParameters3D.new()
	_los_query.collision_mask = 1 | 2 # Layer 1 = Environment/Crates, Layer 2 = Player
	_los_query.exclude = [self]
	set_process(false)
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
		trigger_area.body_exited.connect(_on_trigger_body_exited)

func _process(delta: float) -> void:
	if not is_active:
		if _cooldown_timer <= 0.0:
			set_process(false)
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# If a player remains standing in the firing line after cooldown, shoot again
	if _cooldown_timer <= 0.0 and not _is_triggering and not _players_in_range.is_empty():
		_evaluate_and_fire()
	elif _cooldown_timer <= 0.0 and _players_in_range.is_empty():
		set_process(false)

func _on_trigger_body_entered(body: Node3D) -> void:
	if body is Player and not _players_in_range.has(body):
		_players_in_range.append(body)
		set_process(true)
		if _cooldown_timer <= 0.0 and not _is_triggering and is_active:
			_evaluate_and_fire()

func _on_trigger_body_exited(body: Node3D) -> void:
	if body is Player:
		_players_in_range.erase(body)

func _has_line_of_sight(player: Player) -> bool:
	if not is_instance_valid(player) or player.current_health <= 0:
		return false

	var space_state = get_world_3d().direct_space_state
	_los_query.from = spawn_point.global_position
	_los_query.to = player.global_position + Vector3(0, 0.7, 0)

	var result = space_state.intersect_ray(_los_query)
	if result:
		var hit_collider = result.collider
		# Direct hit on player = clear shot
		if hit_collider == player:
			return true
		# Hit wall or crate = blocked
		return false

	return true

func _evaluate_and_fire() -> void:
	if not is_active or _is_triggering:
		return

	var has_target = false
	for p in _players_in_range:
		if _has_line_of_sight(p):
			has_target = true
			break

	if has_target:
		_trigger_sequence()

func _trigger_sequence() -> void:
	_is_triggering = true
	_cooldown_timer = shoot_interval

	# 1. Subtle hair-trigger click (gives player a split second of tension)
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"dart_click", global_position, 0.95, 1.05, 0.0, 20.0, 5.0)

	if trigger_delay > 0.0:
		await get_tree().create_timer(trigger_delay).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return

	# 2. Fire the dart
	if is_active:
		_shoot_dart()

	_is_triggering = false

func _shoot_dart() -> void:
	# Launch sound
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"dart_launch", global_position, 0.96, 1.05, 0.0, 20.0, 5.0)

	# Spawn projectile oriented along SpawnPoint (+Z out from the wall)
	var dart = preload("res://scenes/puzzles/dart_projectile.tscn").instantiate() as DartProjectile
	get_parent().add_child(dart)
	dart.global_transform = spawn_point.global_transform
	dart.speed = dart_speed
	dart.max_distance = dart_range

func register_trigger_activated() -> void:
	is_active = false

func register_trigger_deactivated() -> void:
	is_active = true

func toggle() -> void:
	is_active = !is_active
