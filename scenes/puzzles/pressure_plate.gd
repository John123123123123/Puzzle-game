extends Node3D
class_name PressurePlate

signal state_changed(is_pressed: bool)

@export var required_target_name: String = "" # Empty means any player or block
@export var is_permanent: bool = false # Stays pressed once activated

var is_pressed: bool = false
var occupying_bodies: Array[Node3D] = []

@onready var plate_mesh: MeshInstance3D = $PlateMesh
@onready var trigger_area: Area3D = $TriggerArea
@onready var rune_light: OmniLight3D = $RuneLight
@onready var rune_glyph: MeshInstance3D = $PlateMesh/RuneGlyph

var audio_player: AudioStreamPlayer3D = null

var initial_y: float = 0.08
var pressed_y: float = 0.015

func _ready() -> void:
	add_to_group("pressure_plate")
	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)
	plate_mesh.position.y = initial_y

	# Setup audio player with procedural stone click
	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = _create_click_sound()
	audio_player.unit_size = 6.0
	audio_player.max_distance = 25.0
	add_child(audio_player)

	# Initial visuals
	_update_visuals(false, false)

func _is_valid_body(body: Node3D) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return false

	# Must not be static environment (e.g. floors, walls, rims)
	if body is StaticBody3D:
		return false

	# If a specific target name is required
	if not required_target_name.is_empty():
		return body.name == required_target_name or body.is_in_group(required_target_name)

	# Valid bodies: Players or Pushable Blocks
	if body is Player or body.is_in_group("player"):
		return true
	if body is PushableBlock or body.is_in_group("pushable") or body.is_in_group("block"):
		return true

	return false

func _on_body_entered(body: Node3D) -> void:
	if not _is_valid_body(body):
		return

	if not occupying_bodies.has(body):
		occupying_bodies.append(body)
	_update_state()

func _on_body_exited(body: Node3D) -> void:
	occupying_bodies.erase(body)
	_update_state()

func _update_state() -> void:
	# Clean up any destroyed or invalid bodies
	occupying_bodies = occupying_bodies.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())

	var should_press = occupying_bodies.size() > 0

	if is_permanent and is_pressed:
		return

	if should_press != is_pressed:
		is_pressed = should_press
		_animate_plate(is_pressed)
		_update_visuals(is_pressed, true)
		if is_pressed and is_instance_valid(audio_player):
			audio_player.play()
		state_changed.emit(is_pressed)

func _animate_plate(pressed: bool) -> void:
	var target_y = pressed_y if pressed else initial_y
	var tween = create_tween()
	tween.tween_property(plate_mesh, "position:y", target_y, 0.12) \
		.set_trans(Tween.TRANS_BACK if pressed else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)

func _update_visuals(pressed: bool, animate: bool) -> void:
	var target_energy = 2.8 if pressed else 0.4
	var target_color = Color(1.0, 0.9, 0.3) if pressed else Color(0.7, 0.55, 0.2)

	if rune_light:
		if animate:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(rune_light, "light_energy", target_energy, 0.2)
			tween.tween_property(rune_light, "light_color", target_color, 0.2)
		else:
			rune_light.light_energy = target_energy
			rune_light.light_color = target_color

	if rune_glyph:
		var mat = rune_glyph.get_active_material(0) as ShaderMaterial
		if not mat and rune_glyph.material_override:
			mat = rune_glyph.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("emission_energy", 4.5 if pressed else 1.2)

func _create_click_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.08
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Mechanical heavy stone click: sharp transient + decaying thud
		var click = sin(t * 1400.0 * TAU) * exp(-t * 100.0)
		var thud = sin(t * 85.0 * TAU) * exp(-t * 30.0)
		var sample = clampf(click * 0.4 + thud * 0.6, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.7 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
