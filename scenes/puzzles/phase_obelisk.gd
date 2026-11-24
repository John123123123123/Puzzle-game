extends StaticBody3D
class_name PhaseObelisk

signal phase_shifted(new_phase: int)

@onready var crystal_pivot: Node3D = $CrystalPivot
@onready var crystal_mesh: MeshInstance3D = $CrystalPivot/CrystalMesh
@onready var ring_mesh: MeshInstance3D = $CrystalPivot/OrbitRing
@onready var beacon_light: OmniLight3D = $BeaconLight

var current_phase: int = 0 # 0 = Solar Gold, 1 = Lunar Cyan
var _crystal_mat: StandardMaterial3D = null
var _ring_mat: StandardMaterial3D = null
var _cooldown: float = 0.0
var _hover_t: float = 0.0
var shift_audio: AudioStreamPlayer3D = null
var solar_sound: AudioStreamWAV = null
var lunar_sound: AudioStreamWAV = null

const SOLAR_COLOR := Color(1.0, 0.82, 0.22)
const LUNAR_COLOR := Color(0.22, 0.88, 1.0)

func _ready() -> void:
	add_to_group("phase_obelisk")
	add_to_group("interactable")
	add_to_group("whip_target")

	if is_instance_valid(crystal_mesh):
		var bm = crystal_mesh.get_active_material(0) as StandardMaterial3D
		if bm:
			_crystal_mat = bm.duplicate() as StandardMaterial3D
			crystal_mesh.material_override = _crystal_mat

	if is_instance_valid(ring_mesh):
		var rm = ring_mesh.get_active_material(0) as StandardMaterial3D
		if rm:
			_ring_mat = rm.duplicate() as StandardMaterial3D
			ring_mesh.material_override = _ring_mat

	solar_sound = _create_phase_sound(true)
	lunar_sound = _create_phase_sound(false)
	shift_audio = AudioStreamPlayer3D.new()
	shift_audio.unit_size = 7.0
	shift_audio.max_distance = 32.0
	add_child(shift_audio)

	_apply_visual_phase(false)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	_hover_t += delta * 2.6
	if is_instance_valid(crystal_pivot):
		crystal_pivot.rotation.y += delta * 1.6
		crystal_pivot.position.y = 1.65 + sin(_hover_t) * 0.07
	if is_instance_valid(ring_mesh):
		ring_mesh.rotation.x = sin(_hover_t * 0.8) * 0.45
		ring_mesh.rotation.z += delta * 1.2

func get_interact_prompt() -> String:
	return "Shift to Moon Phase" if current_phase == 0 else "Shift to Sun Phase"

func interact(_player: Player) -> void:
	trigger_shift()

func on_whipped(_player: Player) -> void:
	trigger_shift()

func trigger_shift() -> void:
	if _cooldown > 0.0:
		return
	var next_phase = 1 - current_phase

	if is_instance_valid(shift_audio):
		shift_audio.stream = solar_sound if next_phase == 0 else lunar_sound
		shift_audio.pitch_scale = randf_range(0.98, 1.03)
		shift_audio.play()

	for cam in get_tree().get_nodes_in_group("coop_camera"):
		if cam.has_method("trigger_shake"):
			cam.trigger_shake(0.08, 0.16)

	for ob in get_tree().get_nodes_in_group("phase_obelisk"):
		if ob is PhaseObelisk:
			ob.set_phase_state(next_phase, true)

	for plat in get_tree().get_nodes_in_group("phase_platform"):
		if plat.has_method("set_world_phase"):
			plat.set_world_phase(next_phase, true)

	phase_shifted.emit(next_phase)

func set_phase_state(new_phase: int, animate: bool) -> void:
	current_phase = new_phase
	_cooldown = 0.28
	_apply_visual_phase(animate)

func _apply_visual_phase(animate: bool) -> void:
	var col = SOLAR_COLOR if current_phase == 0 else LUNAR_COLOR
	if _crystal_mat:
		_crystal_mat.albedo_color = col
		_crystal_mat.emission = col
	if _ring_mat:
		_ring_mat.albedo_color = col
		_ring_mat.emission = col
	if is_instance_valid(beacon_light):
		beacon_light.light_color = col
		if animate:
			beacon_light.light_energy = 4.2
			var tw = create_tween().set_parallel(true)
			tw.tween_property(beacon_light, "light_energy", 2.2, 0.32)
			if is_instance_valid(crystal_pivot):
				crystal_pivot.scale = Vector3(1.35, 1.35, 1.35)
				tw.tween_property(crystal_pivot, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			beacon_light.light_energy = 2.2

func _create_phase_sound(is_solar: bool) -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.36
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 6.5) * sin(minf(1.0, t * 55.0) * PI * 0.5)
		var f1 = 523.25 if is_solar else 440.0
		var f2 = 783.99 if is_solar else 587.33
		var sample = (sin(t * f1 * TAU) * 0.55 + sin(t * f2 * TAU) * 0.40) * env
		data[i] = int(clampi(int((clampf(sample, -1.0, 1.0) * 0.72 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
