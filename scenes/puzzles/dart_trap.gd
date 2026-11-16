extends Node3D
class_name DartTrap

@export var shoot_interval: float = 1.8
@export var dart_speed: float = 14.0
@export var dart_range: float = 10.0
@export var is_active: bool = true
@export var trigger_delay: float = 0.10

var _cooldown_timer: float = 0.0
var _is_triggering: bool = false
var _players_in_range: Array[Player] = []

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var trigger_area: Area3D = $TriggerArea

var audio_player: AudioStreamPlayer3D = null
var click_sound: AudioStreamWAV = null
var launch_sound: AudioStreamWAV = null

func _ready() -> void:
	_setup_audio()
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
		trigger_area.body_exited.connect(_on_trigger_body_exited)

func _setup_audio() -> void:
	click_sound = _create_click_sound()
	launch_sound = _create_launch_sound()

	audio_player = AudioStreamPlayer3D.new()
	audio_player.max_distance = 20.0
	audio_player.unit_size = 5.0
	audio_player.bus = "Master"
	add_child(audio_player)

func _process(delta: float) -> void:
	if not is_active:
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# If a player remains standing in the firing line after cooldown, shoot again
	if _cooldown_timer <= 0.0 and not _is_triggering and not _players_in_range.is_empty():
		_evaluate_and_fire()

func _on_trigger_body_entered(body: Node3D) -> void:
	if body is Player and not _players_in_range.has(body):
		_players_in_range.append(body)
		if _cooldown_timer <= 0.0 and not _is_triggering and is_active:
			_evaluate_and_fire()

func _on_trigger_body_exited(body: Node3D) -> void:
	if body is Player:
		_players_in_range.erase(body)

func _has_line_of_sight(player: Player) -> bool:
	if not is_instance_valid(player) or player.current_health <= 0:
		return false

	var space_state = get_world_3d().direct_space_state
	var start_pos = spawn_point.global_position
	var target_pos = player.global_position + Vector3(0, 0.7, 0)

	# Raycast to ensure no walls or pushable crates block the shot
	var query = PhysicsRayQueryParameters3D.create(start_pos, target_pos)
	query.collision_mask = 1 | 2 # Layer 1 = Environment/Crates, Layer 2 = Player
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
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
	if is_instance_valid(audio_player) and click_sound:
		audio_player.stream = click_sound
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()

	if trigger_delay > 0.0:
		await get_tree().create_timer(trigger_delay).timeout

	# 2. Fire the dart
	if is_active:
		_shoot_dart()

	_is_triggering = false

func _shoot_dart() -> void:
	# Launch sound
	if is_instance_valid(audio_player) and launch_sound:
		audio_player.stream = launch_sound
		audio_player.pitch_scale = randf_range(0.96, 1.05)
		audio_player.play()

	# Spawn projectile
	var dart = preload("res://scenes/puzzles/dart_projectile.tscn").instantiate() as DartProjectile
	get_parent().add_child(dart)
	dart.global_position = spawn_point.global_position
	dart.global_rotation = global_rotation
	dart.speed = dart_speed
	dart.max_distance = dart_range

func register_trigger_activated() -> void:
	is_active = false

func register_trigger_deactivated() -> void:
	is_active = true

func toggle() -> void:
	is_active = !is_active

# ---------------------------------------------------------------------------
# Procedural Audio Generators
# ---------------------------------------------------------------------------

func _create_click_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.06
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Sharp stone pressure click (high pitch with rapid decay)
		var freq = 1800.0 - t * 20000.0
		var click = sin(t * max(200.0, freq) * TAU) * exp(-t * 120.0)
		var noise = (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.35
		var sample = clampf(click * 0.75 + noise * 0.25, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.8 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _create_launch_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.16
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Pneumatic hiss / string release THWIP
		var air_noise = (randf() * 2.0 - 1.0) * exp(-t * 22.0)
		var pitch_sweep = sin(t * (700.0 - t * 3000.0) * TAU) * exp(-t * 26.0)
		var sample = clampf(air_noise * 0.55 + pitch_sweep * 0.45, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.8 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
