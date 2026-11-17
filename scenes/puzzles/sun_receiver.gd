extends Node3D
class_name SunReceiver

signal power_changed(is_powered: bool)

@export var required_target: NodePath
@export var is_powered: bool = false

@onready var crystal_mesh: MeshInstance3D = $CrystalMesh
@onready var glow_light: OmniLight3D = $GlowLight

func _ready() -> void:
	add_to_group("sun_receiver")
	if is_instance_valid(crystal_mesh):
		var mat = crystal_mesh.get_active_material(0)
		if mat:
			crystal_mesh.material_override = mat.duplicate()
	_update_visuals()

func set_powered(powered: bool) -> void:
	if is_powered != powered:
		is_powered = powered
		_update_visuals()
		power_changed.emit(is_powered)

		if required_target:
			var target = get_node_or_null(required_target)
			if target:
				if is_powered and target.has_method("register_trigger_activated"):
					target.register_trigger_activated()
				elif not is_powered and target.has_method("register_trigger_deactivated"):
					target.register_trigger_deactivated()

func _update_visuals() -> void:
	if glow_light:
		glow_light.light_energy = 2.5 if is_powered else 0.1
	if crystal_mesh and crystal_mesh.material_override:
		var mat = crystal_mesh.material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = is_powered
			mat.emission = Color(1.0, 0.9, 0.4) if is_powered else Color.BLACK
