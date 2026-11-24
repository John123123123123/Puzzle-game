extends Node3D
class_name SunReceiver

signal power_changed(is_powered: bool)

@export var required_target: NodePath
@export var is_powered: bool = false

@onready var crystal_mesh: MeshInstance3D = $CrystalMesh
@onready var glow_light: OmniLight3D = $GlowLight
@onready var halo_ring: Node3D = get_node_or_null("HaloRing")

var _pulse_t: float = 0.0

func _ready() -> void:
	add_to_group("sun_receiver")
	if is_instance_valid(crystal_mesh):
		var mat = crystal_mesh.get_active_material(0)
		if mat:
			crystal_mesh.material_override = mat.duplicate()
	_update_visuals()

func _process(delta: float) -> void:
	if not is_powered:
		return
	_pulse_t += delta * 3.2
	if is_instance_valid(crystal_mesh):
		crystal_mesh.rotation.z += delta * 1.4
	if is_instance_valid(halo_ring):
		halo_ring.rotation.z -= delta * 0.8
	if is_instance_valid(glow_light):
		glow_light.light_energy = 2.8 + sin(_pulse_t) * 0.35

func set_powered(powered: bool) -> void:
	if is_powered != powered:
		is_powered = powered
		_update_visuals()
		if is_powered and is_instance_valid(AudioManager):
			AudioManager.play_sfx_3d(&"scarab_pickup", global_position, 0.82, 0.88, -4.0, 24.0, 5.0)
		power_changed.emit(is_powered)

		if required_target:
			var target = get_node_or_null(required_target)
			if target:
				if is_powered and target.has_method("register_trigger_activated"):
					target.register_trigger_activated()
				elif not is_powered and target.has_method("register_trigger_deactivated"):
					target.register_trigger_deactivated()

func _update_visuals() -> void:
	set_process(is_powered)
	if glow_light:
		glow_light.light_energy = 2.8 if is_powered else 0.15
	if crystal_mesh and crystal_mesh.material_override:
		var mat = crystal_mesh.material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.92, 0.42) if is_powered else Color(0.45, 0.35, 0.12)
			mat.emission_energy_multiplier = 2.8 if is_powered else 0.25
