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
		stream.loop_end = int(stream.data.size() / 2) if stream.format == AudioStreamWAV.FORMAT_16_BITS else stream.data.size()

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
			wav.loop_end = int(wav.data.size() / 2)
			return wav
		&"brazier_ignite":
			return _build_wav(0.32, func(t: float) -> float:
				var whoosh = (randf() * 2.0 - 1.0) * sin(clampf(t / 0.32, 0.0, 1.0) * PI) * 0.65
				var flare = sin(t * (220.0 + t * 300.0) * TAU) * exp(-t * 9.0) * 0.35
				return whoosh + flare
			)
		&"scarab_pickup":
			return _build_wav(0.36, func(t: float) -> float:
				var n1 := sin(t * 880.0 * TAU) * exp(-t * 14.0) * minf(1.0, t * 80.0)
				var t2 := maxf(0.0, t - 0.08)
				var n2 := (sin(t2 * 1108.73 * TAU) * exp(-t2 * 12.0) * minf(1.0, t2 * 80.0)) if t >= 0.08 else 0.0
				var t3 := maxf(0.0, t - 0.16)
				var n3 := (sin(t3 * 1318.51 * TAU) * exp(-t3 * 10.0) * minf(1.0, t3 * 80.0)) if t >= 0.16 else 0.0
				return (n1 * 0.35 + n2 * 0.35 + n3 * 0.45) * 0.45
			)
		&"coop_ping":
			return _build_wav(0.28, func(t: float) -> float:
				var c1 := sin(t * 1046.5 * TAU) * exp(-t * 16.0) * minf(1.0, t * 120.0)
				var t2 := maxf(0.0, t - 0.065)
				var c2 := (sin(t2 * 1567.98 * TAU) * exp(-t2 * 11.0) * minf(1.0, t2 * 120.0)) if t >= 0.065 else 0.0
				return (c1 * 0.45 + c2 * 0.55) * 0.5
			)
		&"urn_shatter":
			return _build_wav(0.28, func(t: float) -> float:
				var env := exp(-t * 14.0)
				var ring1 := sin(t * 980.0 * TAU) * 0.32
				var ring2 := sin(t * 1480.0 * TAU) * 0.24
				var ring3 := sin(t * 2120.0 * TAU) * exp(-t * 24.0) * 0.18
				var grit := (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.50
				return (ring1 + ring2 + ring3 + grit) * env * 0.85
			)
		&"heart_pickup":
			return _build_wav(0.40, func(t: float) -> float:
				var a := sin(t * 587.33 * TAU) * exp(-t * 10.0)
				var t2 := maxf(0.0, t - 0.09)
				var b := (sin(t2 * 880.0 * TAU) * exp(-t2 * 9.0)) if t >= 0.09 else 0.0
				var t3 := maxf(0.0, t - 0.18)
				var c := (sin(t3 * 1174.66 * TAU) * exp(-t3 * 7.5)) if t >= 0.18 else 0.0
				return (a * 0.35 + b * 0.38 + c * 0.48) * 0.5
			)
		&"victory_fanfare":
			return _build_wav(0.85, func(t: float) -> float:
				var n1 := (sin(t * 523.25 * TAU) + 0.3 * sin(t * 1046.5 * TAU)) * exp(-t * 8.0)
				var t2 := maxf(0.0, t - 0.13)
				var n2 := ((sin(t2 * 659.25 * TAU) + 0.3 * sin(t2 * 1318.5 * TAU)) * exp(-t2 * 7.5)) if t >= 0.13 else 0.0
				var t3 := maxf(0.0, t - 0.26)
				var n3 := ((sin(t3 * 783.99 * TAU) + 0.3 * sin(t3 * 1568.0 * TAU)) * exp(-t3 * 6.5)) if t >= 0.26 else 0.0
				var t4 := maxf(0.0, t - 0.40)
				var n4 := ((sin(t4 * 1046.5 * TAU) + 0.35 * sin(t4 * 1568.0 * TAU)) * exp(-t4 * 3.8)) if t >= 0.40 else 0.0
				return (n1 * 0.28 + n2 * 0.28 + n3 * 0.30 + n4 * 0.42) * 0.55
			)
		&"game_over_toll":
			return _build_wav(0.90, func(t: float) -> float:
				var bell := sin(t * 146.83 * TAU) * 0.55 + sin(t * 220.0 * TAU) * 0.25 + sin(t * 293.66 * TAU) * 0.15
				var sub := sin(t * 73.42 * TAU) * 0.35
				return (bell + sub) * exp(-t * 3.2) * 0.65
			)
		&"phase_solar":
			return _build_wav(0.45, func(t: float) -> float:
				var fade_in := smoothstep(0.0, 0.06, t)
				var fade_out := exp(-t * 6.2)
				var env := fade_in * fade_out
				# Warm, mellow low-register fifth (A3 220 Hz + E4 329.6 Hz, zero piercing highs)
				var warm_root := sin(t * 220.0 * TAU) * 0.55
				var warm_fifth := sin(t * 329.63 * TAU) * 0.28
				var sub := sin(t * 110.0 * TAU) * 0.22
				return (warm_root + warm_fifth + sub) * env * 0.42
			)
		&"phase_lunar":
			return _build_wav(0.45, func(t: float) -> float:
				var fade_in := smoothstep(0.0, 0.06, t)
				var fade_out := exp(-t * 6.2)
				var env := fade_in * fade_out
				# Soft, deep nocturnal fourth/fifth (G3 196 Hz + D4 293.7 Hz)
				var warm_root := sin(t * 196.0 * TAU) * 0.55
				var warm_fifth := sin(t * 293.66 * TAU) * 0.26
				var sub := sin(t * 98.0 * TAU) * 0.24
				return (warm_root + warm_fifth + sub) * env * 0.42
			)
		&"temple_ambient":
			var wav := _build_wav(4.0, func(t: float) -> float:
				# Seamless low-frequency temple room tone (integer cycles in 4.0s)
				var swell := 0.75 + 0.25 * sin(t * 0.25 * TAU)
				var drone := (sin(t * 55.0 * TAU) * 0.06 + sin(t * 82.5 * TAU) * 0.035 + sin(t * 110.0 * TAU) * 0.015) * swell
				# Soft distant water droplet mid-loop (no seam wrap)
				var drip := 0.0
				if t >= 1.6 and t < 1.9:
					var dt := t - 1.6
					drip = sin(dt * (900.0 + dt * 600.0) * TAU) * exp(-dt * 28.0) * minf(1.0, dt * 120.0) * 0.08
				return drone + drip
			)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.data.size() / 2)
			return wav
	return null

func _build_wav(duration: float, sample_fn: Callable, sample_rate: int = 22050) -> AudioStreamWAV:
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var sample := clampf(float(sample_fn.call(t)), -1.0, 1.0)
		var pcm := int(clampi(int(round(sample * 32767.0)), -32767, 32767))
		data.encode_s16(i * 2, pcm)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
