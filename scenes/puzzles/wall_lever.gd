extends Node3D
class_name WallLever

signal toggled(is_on: bool)

@export var is_on: bool = false
@export var is_one_shot: bool = false
@export var targets: Array[NodePath] = []

@onready var handle_pivot: Node3D = $Base/HandlePivot
@onready var light_indicator: OmniLight3D = $LightIndicator
@onready var rune_mesh: MeshInstance3D = get_node_or_null("RuneIndicator")

var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("whip_target")
	_setup_audio()
	_update_visuals(false)

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = _create_lever_sound()
	audio_player.max_distance = 18.0
	audio_player.unit_size = 4.0
	audio_player.bus = "Master"
	add_child(audio_player)

func interact(_player: Player) -> void:
	toggle()

func on_whipped(_player: Player) -> void:
	toggle()

func toggle() -> void:
	if is_one_shot and is_on:
		return

	is_on = !is_on
	_update_visuals(true)
	toggled.emit(is_on)

	# Trigger any directly linked objects (like doors or traps)
	for path in targets:
		var node = get_node_or_null(path)
		if node:
			if is_on and node.has_method("register_trigger_activated"):
				node.register_trigger_activated()
			elif not is_on and node.has_method("register_trigger_deactivated"):
				node.register_trigger_deactivated()
			elif node.has_method("toggle"):
				node.toggle()

func _update_visuals(animate: bool) -> void:
	# Unpulled (UP): 16° tilted out from wall into room
	# Pulled (DOWN): 116° pulled down into locked lower notch
	var target_rot_x = deg_to_rad(116.0) if is_on else deg_to_rad(16.0)
	var target_color = Color(0.2, 1.0, 0.45) if is_on else Color(0.95, 0.25, 0.15)
	var target_energy = 1.5 if is_on else 0.6

	if animate:
		if is_instance_valid(audio_player):
			audio_player.pitch_scale = randf_range(0.96, 1.04)
			audio_player.play()

		var tween = create_tween().set_parallel(true)
		tween.tween_property(handle_pivot, "rotation:x", target_rot_x, 0.28)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		if light_indicator:
			tween.tween_property(light_indicator, "light_color", target_color, 0.2)
			tween.tween_property(light_indicator, "light_energy", target_energy, 0.2)

		if rune_mesh:
			var mat = rune_mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				tween.tween_property(mat, "emission", target_color, 0.2)
	else:
		handle_pivot.rotation.x = target_rot_x
		if light_indicator:
			light_indicator.light_color = target_color
			light_indicator.light_energy = target_energy
		if rune_mesh:
			var mat = rune_mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.emission = target_color

func _create_lever_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.28
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Phase 1: Mechanical ratchet gear click at start (t: 0.0 -> 0.08)
		var ratchet = sin(t * 1400.0 * TAU) * exp(-t * 40.0) * (1.0 if t < 0.08 else 0.0)
		# Phase 2: Heavy iron latch locking clank (impact around t = 0.15)
		var impact_t = max(0.0, t - 0.14)
		var thud = sin(impact_t * 95.0 * TAU + sin(impact_t * 45.0 * TAU) * 2.5) * exp(-impact_t * 18.0)
		var metallic = sin(impact_t * 420.0 * TAU) * exp(-impact_t * 28.0) * 0.5
		var sample = clampf(ratchet * 0.4 + thud * 0.65 + metallic * 0.35, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.75 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
