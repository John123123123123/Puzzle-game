extends Node3D
class_name CoopCamera

@export var follow_speed: float = 5.0
@export var min_zoom_distance: float = 14.0
@export var max_zoom_distance: float = 30.0
@export var zoom_margin: float = 6.0
@export var rotation_speed: float = 8.0
@export var mouse_sensitivity: float = 0.006

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

var targets: Array[Node3D] = []
var target_yaw: float = deg_to_rad(45.0)
var is_mouse_dragging: bool = false
var shake_offset: Vector3 = Vector3.ZERO
var occluded_meshes: Dictionary = {} # MeshInstance3D -> original transparency

func _ready() -> void:
	add_to_group("coop_camera")
	target_yaw = yaw_pivot.rotation.y

func register_target(target: Node3D) -> void:
	if not targets.has(target):
		targets.append(target)

func unregister_target(target: Node3D) -> void:
	targets.erase(target)

func _unhandled_input(event: InputEvent) -> void:
	# Right mouse button orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_mouse_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_yaw -= deg_to_rad(15.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_yaw += deg_to_rad(15.0)

	elif event is InputEventMouseMotion and is_mouse_dragging:
		target_yaw -= event.relative.x * mouse_sensitivity

	# Snap rotation steps
	if event.is_action_pressed("cam_rotate_left"):
		target_yaw -= deg_to_rad(45.0)
	elif event.is_action_pressed("cam_rotate_right"):
		target_yaw += deg_to_rad(45.0)

func _physics_process(delta: float) -> void:
	_handle_input_held(delta)
	_update_tracking(delta)
	_update_rotation(delta)
	_update_wall_occlusion()

func _handle_input_held(delta: float) -> void:
	# Gamepad Right Stick smooth rotation
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if abs(joy_x) > 0.2:
		target_yaw += joy_x * delta * 2.8

	# Keyboard continuous rotation if held
	if Input.is_action_pressed("cam_rotate_left") and not Input.is_action_just_pressed("cam_rotate_left"):
		target_yaw -= delta * 2.0
	if Input.is_action_pressed("cam_rotate_right") and not Input.is_action_just_pressed("cam_rotate_right"):
		target_yaw += delta * 2.0

func _update_tracking(delta: float) -> void:
	var valid_targets: Array[Node3D] = []
	for t in targets:
		if is_instance_valid(t) and t.is_inside_tree():
			valid_targets.append(t)
	targets = valid_targets

	if targets.is_empty():
		return

	var min_pos: Vector3 = targets[0].global_position
	var max_pos: Vector3 = targets[0].global_position

	for t in targets:
		var pos = t.global_position
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		min_pos.z = min(min_pos.z, pos.z)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		max_pos.z = max(max_pos.z, pos.z)

	var center: Vector3 = (min_pos + max_pos) * 0.5
	global_position = global_position.lerp(center + shake_offset, follow_speed * delta)

	var max_spread = max(abs(max_pos.x - min_pos.x), abs(max_pos.z - min_pos.z))
	var target_distance = clamp(min_zoom_distance + (max_spread - zoom_margin) * 0.9, min_zoom_distance, max_zoom_distance)
	camera.position.z = lerpf(camera.position.z, target_distance, follow_speed * delta)

func _update_rotation(delta: float) -> void:
	yaw_pivot.rotation.y = lerp_angle(yaw_pivot.rotation.y, target_yaw, rotation_speed * delta)

func _update_wall_occlusion() -> void:
	if targets.is_empty():
		return

	var space_state = get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	var target_pos = global_position + Vector3(0, 0.8, 0)

	var query = PhysicsRayQueryParameters3D.create(cam_pos, target_pos)
	query.collision_mask = 1 # Environment / Walls
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit = space_state.intersect_ray(query)
	var currently_hit_mesh: MeshInstance3D = null

	if hit:
		var collider = hit.collider
		if collider and collider.is_in_group("wall"):
			for child in collider.get_children():
				if child is MeshInstance3D:
					currently_hit_mesh = child
					break

	# Fade in newly occluded mesh
	if currently_hit_mesh:
		if not occluded_meshes.has(currently_hit_mesh):
			occluded_meshes[currently_hit_mesh] = currently_hit_mesh.transparency
		currently_hit_mesh.transparency = lerpf(currently_hit_mesh.transparency, 0.72, 0.2)

	# Restore transparency for unoccluded meshes
	var to_remove = []
	for mesh in occluded_meshes.keys():
		if mesh != currently_hit_mesh:
			if is_instance_valid(mesh):
				mesh.transparency = lerpf(mesh.transparency, 0.0, 0.2)
				if mesh.transparency < 0.02:
					mesh.transparency = 0.0
					to_remove.append(mesh)
			else:
				to_remove.append(mesh)

	for m in to_remove:
		occluded_meshes.erase(m)
