extends AnimatableBody3D
class_name SlidingBridge
## Stone bridge slab that extends/retracts over chasms via trigger or automatic cycle.

@export var bridge_size: Vector3 = Vector3(2.4, 0.4, 4.0)
@export var auto_cycle: bool = false
@export var start_extended: bool = false
@export var extended_time: float = 3.2
@export var retracted_time: float = 2.4
@export var retracted_offset: Vector3 = Vector3(0.0, -3.5, 0.0)

var is_extended: bool = false
var _extended_pos: Vector3
var _timer: float = 0.0
var _col_shape: CollisionShape3D
var _mesh: MeshInstance3D
var _tween: Tween

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false

	_extended_pos = position
	_build_geometry()

	is_extended = start_extended
	if is_extended:
		position = _extended_pos
		_col_shape.disabled = false
	else:
		position = _extended_pos + retracted_offset
		_col_shape.disabled = true

	_timer = extended_time if is_extended else retracted_time

func _build_geometry() -> void:
	_col_shape = CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = bridge_size
	_col_shape.shape = box_col
	add_child(_col_shape)

	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = bridge_size
	_mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.41, 0.31)
	mat.roughness = 0.82
	_mesh.material_override = mat
	add_child(_mesh)

	# Decorative gold trim strips on sides
	for side in [-1.0, 1.0]:
		var trim := MeshInstance3D.new()
		var t_box := BoxMesh.new()
		t_box.size = Vector3(0.12, 0.14, bridge_size.z - 0.1)
		trim.mesh = t_box
		var t_mat := StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.82, 0.66, 0.25)
		t_mat.metallic = 0.65
		t_mat.roughness = 0.35
		trim.material_override = t_mat
		trim.position = Vector3(side * (bridge_size.x * 0.5 - 0.08), bridge_size.y * 0.5 + 0.02, 0.0)
		add_child(trim)

func _physics_process(delta: float) -> void:
	if not auto_cycle:
		return
	_timer -= delta
	if _timer <= 0.0:
		set_extended(not is_extended)
		_timer = extended_time if is_extended else retracted_time

func set_extended(extended: bool) -> void:
	if is_extended == extended:
		return
	is_extended = extended
	if _tween and _tween.is_valid():
		_tween.kill()

	var target := _extended_pos if extended else (_extended_pos + retracted_offset)
	if extended:
		_col_shape.set_deferred("disabled", false)

	_tween = create_tween()
	_tween.tween_property(self, "position", target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not extended:
		_tween.tween_callback(func():
			if is_instance_valid(_col_shape) and not is_extended:
				_col_shape.disabled = true
		)

func register_trigger_activated() -> void:
	set_extended(true)

func register_trigger_deactivated() -> void:
	set_extended(false)

func toggle() -> void:
	set_extended(not is_extended)
