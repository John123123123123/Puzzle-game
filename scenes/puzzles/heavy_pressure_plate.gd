extends Node3D
class_name HeavyPressurePlate
## Large co-op pressure plate requiring multiple weight units (players + crates) with 1/2 -> 2/2 visual pips.

signal activated
signal deactivated

@export var required_weight: int = 2
@export var linked_targets: Array[NodePath] = []
@export var stay_pressed: bool = false

var current_weight: int = 0
var is_pressed: bool = false
var _bodies_on_plate: Array[Node3D] = []

var _plate_mesh: MeshInstance3D
var _pip_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("heavy_pressure_plate")
	_build_visuals()
	_build_area()
	_update_visuals()

func _build_visuals() -> void:
	var frame := MeshInstance3D.new()
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(2.4, 0.12, 2.4)
	frame.mesh = frame_box
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.28, 0.24, 0.2)
	frame_mat.roughness = 0.9
	frame.material_override = frame_mat
	frame.position = Vector3(0.0, 0.06, 0.0)
	add_child(frame)

	_plate_mesh = MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(2.1, 0.14, 2.1)
	_plate_mesh.mesh = pad_box
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.55, 0.45, 0.32)
	pad_mat.roughness = 0.75
	_plate_mesh.material_override = pad_mat
	_plate_mesh.position = Vector3(0.0, 0.14, 0.0)
	add_child(_plate_mesh)

	for i in range(2):
		var pip := MeshInstance3D.new()
		var pip_box := BoxMesh.new()
		pip_box.size = Vector3(0.32, 0.06, 0.32)
		pip.mesh = pip_box
		var pip_mat := StandardMaterial3D.new()
		pip_mat.albedo_color = Color(0.25, 0.22, 0.18)
		pip_mat.emission_enabled = true
		pip_mat.emission = Color(1.0, 0.78, 0.2)
		pip_mat.emission_energy_multiplier = 0.0
		pip.material_override = pip_mat
		pip.position = Vector3(-0.45 + float(i) * 0.9, 0.10, 0.0)
		_plate_mesh.add_child(pip)
		_pip_mats.append(pip_mat)

func _build_area() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 3 # Layer 1 (PushableBlock) + Layer 2 (Player)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 0.8, 2.1)
	col.shape = box
	col.position = Vector3(0.0, 0.45, 0.0)
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node3D) -> void:
	if (body is Player or body is PushableBlock) and not _bodies_on_plate.has(body):
		_bodies_on_plate.append(body)
		_recalculate_weight()

func _on_body_exited(body: Node3D) -> void:
	if _bodies_on_plate.has(body):
		_bodies_on_plate.erase(body)
		_recalculate_weight()

func _recalculate_weight() -> void:
	var valid: Array[Node3D] = []
	for b in _bodies_on_plate:
		if is_instance_valid(b):
			if b is Player and b.current_health <= 0:
				continue
			valid.append(b)
	_bodies_on_plate = valid
	current_weight = _bodies_on_plate.size()

	var should_press := current_weight >= required_weight
	if should_press and not is_pressed:
		is_pressed = true
		if is_instance_valid(AudioManager):
			AudioManager.play_sfx_3d(&"plate_click", global_position, 0.92, 1.04, 0.0, 20.0, 5.0)
		activated.emit()
		for path in linked_targets:
			var node := get_node_or_null(path)
			if node and node.has_method("register_trigger_activated"):
				node.register_trigger_activated()
	elif not should_press and is_pressed and not stay_pressed:
		is_pressed = false
		deactivated.emit()
		for path in linked_targets:
			var node := get_node_or_null(path)
			if node and node.has_method("register_trigger_deactivated"):
				node.register_trigger_deactivated()

	_update_visuals()

func _update_visuals() -> void:
	if is_instance_valid(_plate_mesh):
		var target_y := 0.05 if is_pressed else (0.10 if current_weight > 0 else 0.14)
		var t := create_tween()
		t.tween_property(_plate_mesh, "position:y", target_y, 0.12)

	for i in range(_pip_mats.size()):
		var lit := current_weight > i
		_pip_mats[i].emission_energy_multiplier = 2.0 if is_pressed else (0.9 if lit else 0.0)
		_pip_mats[i].albedo_color = Color(1.0, 0.85, 0.25) if lit else Color(0.25, 0.22, 0.18)
