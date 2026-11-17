extends Node
## Centralized audio manager with procedural fallbacks, node pooling, and easy asset overrides.
##
## To replace any procedural sound with a real audio file (.wav/.ogg),
## either assign it in `sfx_overrides` in the Inspector or call:
##   AudioManager.register_override(&"whip_crack", preload("res://audio/whip.wav"))

@export var sfx_overrides: Dictionary = {} # StringName -> AudioStream
@export var master_sfx_volume_db: float = 0.0
@export var ambient_volume_db: float = -16.0

const POOL_SIZE_3D: int = 16
const POOL_SIZE_2D: int = 6

var _stream_cache: Dictionary = {} # StringName -> AudioStream
var _ambient_player: AudioStreamPlayer = null
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d_idx: int = 0
var _pool_2d_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE_3D):
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "Master"
		add_child(p3)
		_pool_3d.append(p3)
	for i in range(POOL_SIZE_2D):
		var p2 := AudioStreamPlayer.new()
		p2.bus = "Master"
		add_child(p2)
		_pool_2d.append(p2)

## Registers or replaces a sound at runtime.
func register_override(sound_id: StringName, stream: AudioStream) -> void:
	sfx_overrides[sound_id] = stream

## Returns the AudioStream for `sound_id`, preferring overrides over procedural defaults.
func get_stream(sound_id: StringName) -> AudioStream:
	if sfx_overrides.has(sound_id) and sfx_overrides[sound_id] is AudioStream:
		return sfx_overrides[sound_id]

	if _stream_cache.has(sound_id):
		return _stream_cache[sound_id]

	var generated := _generate_procedural_stream(sound_id)
	if generated:
		_stream_cache[sound_id] = generated
	return generated

## Plays a pooled one-shot 3D positional sound effect.
func play_sfx_3d(
	sound_id: StringName,
	world_pos: Vector3,
	pitch_min: float = 0.95,
	pitch_max: float = 1.05,
	volume_db: float = 0.0,
	max_distance: float = 25.0,
	unit_size: float = 5.0
) -> void:
	var stream := get_stream(sound_id)
	if stream == null or _pool_3d.is_empty():
		return

	var player: AudioStreamPlayer3D = null
	for p in _pool_3d:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool_3d[_pool_3d_idx]
		_pool_3d_idx = (_pool_3d_idx + 1) % _pool_3d.size()

	player.stream = stream
	player.global_position = world_pos
	player.volume_db = volume_db + master_sfx_volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.max_distance = max_distance
	player.unit_size = unit_size
	player.play()

## Plays a pooled one-shot non-positional (2D/UI) sound effect.
func play_sfx_2d(
	sound_id: StringName,
	pitch_min: float = 0.98,
	pitch_max: float = 1.02,
	volume_db: float = 0.0
) -> void:
	var stream := get_stream(sound_id)
	if stream == null or _pool_2d.is_empty():
		return

	var player: AudioStreamPlayer = null
	for p in _pool_2d:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool_2d[_pool_2d_idx]
		_pool_2d_idx = (_pool_2d_idx + 1) % _pool_2d.size()

	player.stream = stream
	player.volume_db = volume_db + master_sfx_volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()

## Creates an attached 3D AudioStreamPlayer3D preloaded with `sound_id` (useful for loops).
func create_player_3d(
	sound_id: StringName,
	parent: Node3D,
	volume_db: float = 0.0,
	max_distance: float = 25.0,
	unit_size: float = 5.0
) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = get_stream(sound_id)
	player.volume_db = volume_db + master_sfx_volume_db
	player.max_distance = max_distance
	player.unit_size = unit_size
	player.bus = "Master"
	parent.add_child(player)
	return player

## Starts the subtle looping temple ambiance if not already playing.
func start_ambient_temple() -> void:
	if is_instance_valid(_ambient_player) and _ambient_player.playing:
		return
	var stream := get_stream(&"temple_ambient")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()

	if not is_instance_valid(_ambient_player):
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.bus = "Master"
		add_child(_ambient_player)
	_ambient_player.stream = stream
	_ambient_player.volume_db = ambient_volume_db
	_ambient_player.play()

func stop_ambient() -> void:
	if is_instance_valid(_ambient_player):
		_ambient_player.stop()

# ---------------------------------------------------------------------------
# Procedural WAV Fallbacks
# ---------------------------------------------------------------------------

func _generate_procedural_stream(sound_id: StringName) -> AudioStreamWAV:
	match sound_id:
		&"player_hurt":
			return _build_wav(0.25, func(t: float) -> float:
				var thud = sin(t * 115.0 * TAU) * exp(-t * 16.0)
				var punch = (sin(t * 1800.0 * TAU) if t < 0.02 else 0.0) * 0.5
				var pitch = 380.0 - t * 450.0
				var vocal = sin(t * pitch * TAU + sin(t * 65.0 * TAU) * 1.5) * exp(-t * 10.0) * 0.6
				return (thud * 0.5 + punch + vocal) * 0.9
			)
		&"player_death":
			return _build_wav(0.55, func(t: float) -> float:
				var pitch = 280.0 - t * 240.0
				var groan = sin(t * pitch * TAU + sin(t * 40.0 * TAU) * 2.0) * exp(-t * 5.0) * 0.6
				var thud = sin(t * 65.0 * TAU) * exp(-t * 8.0) * 0.4
				return groan + thud
			)
		&"footstep":
			return _build_wav(0.07, func(t: float) -> float:
				var grit = (randf() * 2.0 - 1.0) * exp(-t * 65.0) * 0.45
				var tap = sin(t * (160.0 - t * 800.0) * TAU) * exp(-t * 55.0) * 0.55
				return (grit + tap) * 0.65
			)
		&"whip_crack":
			return _build_wav(0.18, func(t: float) -> float:
				var whoosh = (randf() * 2.0 - 1.0) * exp(-absf(t - 0.05) * 35.0) * 0.4
				var crack_t = maxf(0.0, t - 0.07)
				var crack = (randf() * 2.0 - 1.0) * exp(-crack_t * 95.0) * (1.0 if t >= 0.07 else 0.0)
				var snap = sin(crack_t * 2400.0 * TAU) * exp(-crack_t * 120.0) * (0.6 if t >= 0.07 else 0.0)
				return (whoosh + crack * 0.9 + snap) * 0.9
			)
		&"door_rumble":
			return _build_wav(1.2, func(t: float) -> float:
				var sub = sin(t * 42.0 * TAU + sin(t * 18.0 * TAU) * 3.0) * 0.5
				var grind = sin(t * 135.0 * TAU + sin(t * 60.0 * TAU) * 2.0) * 0.35
				var gravel = sin(t * 310.0 * TAU) * sin(t * 73.0 * TAU) * 0.2
				var env = sin(clampf(t / 1.2, 0.0, 1.0) * PI)
				return (sub + grind + gravel) * env * 0.85
			)
		&"plate_click":
			return _build_wav(0.08, func(t: float) -> float:
				var click = sin(t * 1400.0 * TAU) * exp(-t * 100.0)
				var thud = sin(t * 85.0 * TAU) * exp(-t * 30.0)
				return click * 0.4 + thud * 0.6
			)
		&"lever_clank":
			return _build_wav(0.28, func(t: float) -> float:
				var ratchet = sin(t * 1400.0 * TAU) * exp(-t * 40.0) * (1.0 if t < 0.08 else 0.0)
				var impact_t = maxf(0.0, t - 0.14)
				var thud = sin(impact_t * 95.0 * TAU + sin(impact_t * 45.0 * TAU) * 2.5) * exp(-impact_t * 18.0)
				var metallic = sin(impact_t * 420.0 * TAU) * exp(-impact_t * 28.0) * 0.5
				return ratchet * 0.4 + thud * 0.65 + metallic * 0.35
			)
		&"dart_click":
			return _build_wav(0.06, func(t: float) -> float:
				var freq = 1800.0 - t * 20000.0
				var click = sin(t * maxf(200.0, freq) * TAU) * exp(-t * 120.0)
				var noise = (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.35
				return click * 0.75 + noise * 0.25
			)
		&"dart_launch":
			return _build_wav(0.16, func(t: float) -> float:
				var air_noise = (randf() * 2.0 - 1.0) * exp(-t * 22.0)
				var pitch_sweep = sin(t * (700.0 - t * 3000.0) * TAU) * exp(-t * 26.0)
				return air_noise * 0.55 + pitch_sweep * 0.45
			)
		&"mirror_turn":
			return _build_wav(0.24, func(t: float) -> float:
				var rumble = sin(t * 110.0 * TAU + sin(t * 45.0 * TAU) * 2.0) * exp(-t * 9.0)
				var ratchet = sin(t * 820.0 * TAU) * exp(-absf(t - 0.20) * 55.0)
				return rumble * 0.65 + ratchet * 0.35
			)
		&"spike_thrust":
			return _build_wav(0.14, func(t: float) -> float:
				var clank = sin(t * 920.0 * TAU) * exp(-t * 36.0) * 0.5
				var scrape = (randf() * 2.0 - 1.0) * exp(-t * 28.0) * 0.4
				var thump = sin(t * 140.0 * TAU) * exp(-t * 24.0) * 0.5
				return clank + scrape + thump
			)
		&"boulder_rumble":
			var wav := _build_wav(1.0, func(t: float) -> float:
				var low = sin(t * 38.0 * TAU + sin(t * 12.0 * TAU) * 1.5) * 0.55
				var mid = sin(t * 76.0 * TAU + sin(t * 27.0 * TAU) * 1.8) * 0.3
				var grit = (randf() * 2.0 - 1.0) * 0.2
				return low + mid + grit
			)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = wav.data.size()
			return wav
		&"brazier_ignite":
			return _build_wav(0.32, func(t: float) -> float:
				var whoosh = (randf() * 2.0 - 1.0) * sin(clampf(t / 0.32, 0.0, 1.0) * PI) * 0.65
				var flare = sin(t * (220.0 + t * 300.0) * TAU) * exp(-t * 9.0) * 0.35
				return whoosh + flare
			)
		&"scarab_pickup":
			return _build_wav(0.35, func(t: float) -> float:
				var f1 = 660.0 if t < 0.09 else (880.0 if t < 0.18 else 1320.0)
				var tone = sin(t * f1 * TAU) * exp(-t * 5.5) * 0.55
				var shimmer = sin(t * f1 * 2.0 * TAU) * exp(-t * 8.0) * 0.25
				return tone + shimmer
			)
		&"temple_ambient":
			var wav := _build_wav(3.0, func(t: float) -> float:
				var wind = sin(t * 0.66 * TAU) * 0.12 * (randf() * 2.0 - 1.0)
				var drone = sin(t * 55.0 * TAU) * 0.08 + sin(t * 82.5 * TAU) * 0.05
				var drip_t = fmod(t + 0.4, 3.0)
				var drip = sin(drip_t * (1100.0 + drip_t * 900.0) * TAU) * exp(-drip_t * 38.0) * 0.22
				return wind + drone + drip
			)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = wav.data.size()
			return wav
	return null

func _build_wav(duration: float, sample_fn: Callable, sample_rate: int = 22050) -> AudioStreamWAV:
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var sample := clampf(float(sample_fn.call(t)), -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.7 + 0.5) * 255.0), 0, 255))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
