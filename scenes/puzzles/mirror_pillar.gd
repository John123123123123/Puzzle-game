extends Node3D
class_name MirrorPillar

signal rotated(new_angle: float)

@export var current_step: int = 0 # 0=North (0°), 1=East (90°), 2=South (180°), 3=West (270°)
@export var is_rotatable: bool = true

@onready var pillar_top: Node3D = $PillarTop
@onready var mirror_mesh: MeshInstance3D = $PillarTop/MirrorFrame/MirrorDisc
@onready var beam_root: Node3D = $PillarTop/BeamPivot
@onready var core_mesh_inst: MeshInstance3D = $PillarTop/BeamPivot/CoreBeam
@onready var aura_mesh_inst: MeshInstance3D = $PillarTop/BeamPivot/AuraBeam
@onready var impact_light: OmniLight3D = $PillarTop/BeamPivot/ImpactLight
@onready var impact_flare: MeshInstance3D = $PillarTop/BeamPivot/ImpactFlare
@onready var mirror_light: OmniLight3D = $PillarTop/MirrorLight

var is_illuminated: bool = false
var is_turning: bool = false
var target_rot_y: float = 0.0
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("mirror")
	add_to_group("interactable")

	# Duplicate cylinder meshes so each mirror instance can have its own beam length
	if is_instance_valid(core_mesh_inst) and core_mesh_inst.mesh:
		core_mesh_inst.mesh = core_mesh_inst.mesh.duplicate()
	if is_instance_valid(aura_mesh_inst) and aura_mesh_inst.mesh:
		aura_mesh_inst.mesh = aura_mesh_inst.mesh.duplicate()

	# Create procedural stone turning sound
	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = _create_stone_turn_sound()
	audio_player.unit_size = 5.0
	audio_player.max_distance = 25.0
	add_child(audio_player)

	# Initial angle: 0=North (-Z), 1=East (+X, -90°), 2=South (+Z, -180°), 3=West (-X, -270°)
	target_rot_y = -float(current_step) * (PI / 2.0)
	if is_instance_valid(pillar_top):
		pillar_top.rotation.y = target_rot_y

	set_beam_active(false)

func interact(player: Player) -> void:
	if not is_rotatable or is_turning:
		return
	rotate_pillar()

func rotate_pillar() -> void:
	is_turning = true
	current_step = (current_step + 1) % 4
	target_rot_y -= PI / 2.0 # Smooth clockwise rotation

	if is_instance_valid(audio_player):
		audio_player.pitch_scale = randf_range(0.96, 1.04)
		audio_player.play()

	var tween = create_tween()
	tween.tween_property(pillar_top, "rotation:y", target_rot_y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	is_turning = false
	rotated.emit(target_rot_y)

func set_beam_active(active: bool, length: float = 8.0) -> void:
	is_illuminated = active

	if not is_instance_valid(beam_root):
		return

	beam_root.visible = active
	if is_instance_valid(mirror_light):
		mirror_light.visible = active

	if active:
		if is_instance_valid(core_mesh_inst):
			var c_mesh = core_mesh_inst.mesh as CylinderMesh
			if c_mesh:
				c_mesh.height = length
			core_mesh_inst.position.z = -length * 0.5

		if is_instance_valid(aura_mesh_inst):
			var a_mesh = aura_mesh_inst.mesh as CylinderMesh
			if a_mesh:
				a_mesh.height = length
			aura_mesh_inst.position.z = -length * 0.5

		if is_instance_valid(impact_light):
			impact_light.position.z = -length
		if is_instance_valid(impact_flare):
			impact_flare.position.z = -length

		# Mirror reflection highlight
		if is_instance_valid(mirror_mesh):
			var mat = mirror_mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.92, 0.6)
				mat.emission_energy_multiplier = 1.8
	else:
		if is_instance_valid(mirror_mesh):
			var mat = mirror_mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.emission_enabled = false

func _create_stone_turn_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.24
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Heavy grinding stone ratchet: friction rumble + metallic gear lock
		var rumble = sin(t * 110.0 * TAU + sin(t * 45.0 * TAU) * 2.0) * exp(-t * 9.0)
		var ratchet = sin(t * 820.0 * TAU) * exp(-abs(t - 0.20) * 55.0)
		var sample = clampf(rumble * 0.65 + ratchet * 0.35, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.7 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
