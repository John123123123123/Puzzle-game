extends StaticBody3D
class_name ConveyorFloor
## Mechanized sandstone gear-belt that smoothly carries both Players and PushableBlocks along belt_direction.

@export var belt_size: Vector3 = Vector3(3.0, 0.22, 6.0)
@export var belt_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var belt_speed: float = 2.2
@export var is_active: bool = true
@export var is_reversed: bool = false

@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var belt_mesh: MeshInstance3D = $BeltMesh
@onready var top_area: Area3D = $CarryArea
@onready var area_shape: CollisionShape3D = $CarryArea/CollisionShape3D

var _belt_mat: ShaderMaterial = null
var _riders: Array[Node3D] = []

func _ready() -> void:
	add_to_group("conveyor_floor")
	_configure_geometry()
	_sync_shader()
	if is_instance_valid(top_area):
		top_area.body_entered.connect(_on_body_entered)
		top_area.body_exited.connect(_on_body_exited)

func _configure_geometry() -> void:
	if is_instance_valid(body_shape):
		var bs := BoxShape3D.new()
		bs.size = belt_size
		body_shape.shape = bs

	if is_instance_valid(belt_mesh):
		var bm := BoxMesh.new()
		bm.size = belt_size
		var orig := belt_mesh.get_active_material(0)
		if orig is ShaderMaterial:
			_belt_mat = orig.duplicate() as ShaderMaterial
			bm.material = _belt_mat
		belt_mesh.mesh = bm

	if is_instance_valid(area_shape):
		var ashp := BoxShape3D.new()
		ashp.size = Vector3(maxf(0.4, belt_size.x - 0.15), 0.9, maxf(0.4, belt_size.z - 0.15))
		area_shape.shape = ashp
		area_shape.position = Vector3(0.0, belt_size.y * 0.5 + 0.35, 0.0)

func _get_active_dir() -> Vector3:
	var d := Vector3(belt_direction.x, 0.0, belt_direction.z)
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	else:
		d = d.normalized()
	return -d if is_reversed else d

func _sync_shader() -> void:
	if _belt_mat == null:
		return
	var d := Vector3(belt_direction.x, 0.0, belt_direction.z)
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	else:
		d = d.normalized()
	_belt_mat.set_shader_parameter("scroll_dir", Vector2(d.x, d.z))
	_belt_mat.set_shader_parameter("belt_world_size", Vector2(belt_size.x, belt_size.z))
	var spd := (belt_speed * 0.28) if is_active else 0.0
	if is_reversed:
		spd = -spd
	_belt_mat.set_shader_parameter("scroll_speed", spd)

func register_trigger_activated() -> void:
	is_reversed = true
	_sync_shader()

func register_trigger_deactivated() -> void:
	is_reversed = false
	_sync_shader()

func toggle() -> void:
	is_reversed = not is_reversed
	_sync_shader()

func _on_body_entered(body: Node3D) -> void:
	if (body is Player or body is PushableBlock) and not _riders.has(body):
		_riders.append(body)

func _on_body_exited(body: Node3D) -> void:
	_riders.erase(body)

func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	var push_vel := _get_active_dir() * belt_speed
	for i in range(_riders.size() - 1, -1, -1):
		var r: Node3D = _riders[i]
		if not is_instance_valid(r) or not r.is_inside_tree():
			_riders.remove_at(i)
			continue
		if r is Player:
			(r as Player).apply_environment_effect(1.0, push_vel, 0.0)
		elif r is PushableBlock:
			(r as PushableBlock).apply_conveyor_velocity(push_vel)
