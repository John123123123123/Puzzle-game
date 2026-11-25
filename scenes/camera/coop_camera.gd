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
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var occluded_meshes: Dictionary = {} # MeshInstance3D -> original transparency
var _occlusion_ray_query: PhysicsRayQueryParameters3D = null
var _hit_meshes_buf: Array[MeshInstance3D] = []
var _to_remove_buf: Array[MeshInstance3D] = []

const TEMPLE_DUST_MOTES := preload("res://scenes/effects/temple_dust_motes.gd")

func _ready() -> void:
	add_to_group("coop_camera")
	target_yaw = yaw_pivot.rotation.y
	_occlusion_ray_query = PhysicsRayQueryParameters3D.new()
	_occlusion_ray_query.collision_mask = 1 # Environment / Walls
	_occlusion_ray_query.collide_with_areas = false
	_occlusion_ray_query.collide_with_bodies = true
	var motes := TEMPLE_DUST_MOTES.new()
	motes.position = Vector3(0.0, 2.2, 0.0)
	add_child(motes)

func trigger_shake(intensity: float, duration: float = 0.15) -> void:
	if is_instance_valid(SettingsManager) and not SettingsManager.camera_shake:
		return
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)

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
		var sens := SettingsManager.camera_sensitivity if is_instance_valid(SettingsManager) else 1.0
		var inv := -1.0 if (is_instance_valid(SettingsManager) and SettingsManager.invert_camera_x) else 1.0
		target_yaw -= event.relative.x * mouse_sensitivity * sens * inv

	# Snap rotation steps
	if event.is_action_pressed("cam_rotate_left"):
		target_yaw -= deg_to_rad(45.0)
	elif event.is_action_pressed("cam_rotate_right"):
		target_yaw += deg_to_rad(45.0)

func _physics_process(delta: float) -> void:
	_handle_input_held(delta)
	_update_shake(delta)
	_update_tracking(delta)
	_update_rotation(delta)
	_update_wall_occlusion()

func _update_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		shake_offset = Vector3(
			randf_range(-1.0, 1.0) * _shake_intensity,
			randf_range(-1.0, 1.0) * _shake_intensity,
			0.0
		)
		if _shake_timer <= 0.0:
			_shake_intensity = 0.0
	else:
		shake_offset = shake_offset.lerp(Vector3.ZERO, 15.0 * delta)

func _handle_input_held(delta: float) -> void:
	# Gamepad Right Stick smooth rotation
	var deadzone := SettingsManager.gamepad_deadzone if is_instance_valid(SettingsManager) else 0.2
	var sens := SettingsManager.camera_sensitivity if is_instance_valid(SettingsManager) else 1.0
	var inv := -1.0 if (is_instance_valid(SettingsManager) and SettingsManager.invert_camera_x) else 1.0
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if abs(joy_x) > deadzone:
		target_yaw += joy_x * delta * 2.8 * sens * inv

	# Keyboard continuous rotation if held
	if Input.is_action_pressed("cam_rotate_left") and not Input.is_action_just_pressed("cam_rotate_left"):
		target_yaw -= delta * 2.0
	if Input.is_action_pressed("cam_rotate_right") and not Input.is_action_just_pressed("cam_rotate_right"):
		target_yaw += delta * 2.0

func _update_tracking(delta: float) -> void:
	for i in range(targets.size() - 1, -1, -1):
		var t := targets[i]
		if not is_instance_valid(t) or not t.is_inside_tree():
			targets.remove_at(i)

	if targets.is_empty():
		return

	# In online co-op, if our local explorer is downed, smoothly spectate living teammates
	var active_list: Array[Node3D] = targets
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		var has_living_local := false
		for t in targets:
			if not ("current_health" in t) or t.current_health > 0:
				has_living_local = true
				break
		if not has_living_local:
			var living_allies: Array[Node3D] = []
			for p in get_tree().get_nodes_in_group("player"):
				if p is Node3D and is_instance_valid(p) and (not ("current_health" in p) or p.current_health > 0):
					living_allies.append(p)
			if not living_allies.is_empty():
				active_list = living_allies

	var min_pos: Vector3 = active_list[0].global_position
	var max_pos: Vector3 = active_list[0].global_position

	for t in active_list:
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
	_hit_meshes_buf.clear()
	_occlusion_ray_query.from = cam_pos

	for t in targets:
		_occlusion_ray_query.to = t.global_position + Vector3(0, 0.8, 0)
		var hit = space_state.intersect_ray(_occlusion_ray_query)
		if hit:
			var collider = hit.collider
			if collider and collider.is_in_group("wall"):
				for child in collider.get_children():
					if child is MeshInstance3D and not _hit_meshes_buf.has(child):
						_hit_meshes_buf.append(child)
						break

	# Fade in newly occluded meshes
	for mesh in _hit_meshes_buf:
		if not occluded_meshes.has(mesh):
			occluded_meshes[mesh] = mesh.transparency
		mesh.transparency = lerpf(mesh.transparency, 0.72, 0.2)
		mesh.set_instance_shader_parameter("occlusion_fade", mesh.transparency)

	# Restore transparency for unoccluded meshes
	_to_remove_buf.clear()
	for mesh in occluded_meshes.keys():
		if not _hit_meshes_buf.has(mesh):
			if is_instance_valid(mesh):
				mesh.transparency = lerpf(mesh.transparency, 0.0, 0.2)
				if mesh.transparency < 0.02:
					mesh.transparency = 0.0
					mesh.set_instance_shader_parameter("occlusion_fade", 0.0)
					_to_remove_buf.append(mesh)
				else:
					mesh.set_instance_shader_parameter("occlusion_fade", mesh.transparency)
			else:
				_to_remove_buf.append(mesh)

	for m in _to_remove_buf:
		occluded_meshes.erase(m)
