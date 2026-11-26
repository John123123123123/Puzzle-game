extends Node3D
class_name CoopCamera

@export var follow_speed: float = 5.0
@export var min_zoom_distance: float = 14.0
@export var max_zoom_distance: float = 30.0
@export var zoom_margin: float = 6.0
@export var rotation_speed: float = 8.0
@export var mouse_sensitivity: float = 0.006
@export var dynamic_splitscreen_enabled: bool = true
@export var split_start_distance: float = 10.5
@export var split_threshold_zoom: float = 17.5
@export var split_camera_distance: float = 16.2
@export var split_direction_smooth: float = 5.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

var targets: Array[Node3D] = []
var target_yaw: float = deg_to_rad(45.0)
var shake_offset: Vector3 = Vector3.ZERO
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var occluded_meshes: Dictionary = {} # MeshInstance3D -> original transparency
var _occlusion_ray_query: PhysicsRayQueryParameters3D = null
var _hit_meshes_buf: Array[MeshInstance3D] = []
var _to_remove_buf: Array[MeshInstance3D] = []

const TEMPLE_DUST_MOTES := preload("res://scenes/effects/temple_dust_motes.gd")
const SPLITSCREEN_SHADER := preload("res://shaders/dynamic_splitscreen.gdshader")

var _split_layer: CanvasLayer = null
var _split_rect: ColorRect = null
var _split_mat: ShaderMaterial = null
var _vp1: SubViewport = null
var _vp2: SubViewport = null
var _cam1: Camera3D = null
var _cam2: Camera3D = null
var _cam1_focus: Vector3 = Vector3.ZERO
var _cam2_focus: Vector3 = Vector3.ZERO
var _split_focus_initialized: bool = false
var _smooth_world_dir_xz: Vector2 = Vector2(1.0, 0.0)
var _has_world_dir: bool = false
var _split_alpha: float = 0.0
var _split_warmup_frames: int = 0
var _split_players: Array[Node3D] = []

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
	_setup_dynamic_splitscreen()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_inside_tree() and get_tree() != null and is_instance_valid(get_tree().root):
		if get_tree().root.size_changed.is_connected(_sync_split_viewports):
			get_tree().root.size_changed.disconnect(_sync_split_viewports)
	if is_instance_valid(SettingsManager) and SettingsManager.settings_changed.is_connected(_sync_split_viewports):
		SettingsManager.settings_changed.disconnect(_sync_split_viewports)

func _setup_dynamic_splitscreen() -> void:
	var pair1 := _create_split_viewport("SplitViewportP1")
	_vp1 = pair1[0] as SubViewport
	_cam1 = pair1[1] as Camera3D

	var pair2 := _create_split_viewport("SplitViewportP2")
	_vp2 = pair2[0] as SubViewport
	_cam2 = pair2[1] as Camera3D

	_split_layer = CanvasLayer.new()
	_split_layer.name = "SplitscreenLayer"
	_split_layer.layer = 0
	add_child(_split_layer)

	_split_mat = ShaderMaterial.new()
	_split_mat.shader = SPLITSCREEN_SHADER
	_split_mat.set_shader_parameter("viewport_p1", _vp1.get_texture())
	_split_mat.set_shader_parameter("viewport_p2", _vp2.get_texture())

	_split_rect = ColorRect.new()
	_split_rect.name = "SplitscreenRect"
	_split_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_split_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_rect.material = _split_mat
	_split_rect.visible = false
	_split_layer.add_child(_split_rect)

	if get_tree() != null and is_instance_valid(get_tree().root):
		get_tree().root.size_changed.connect(_sync_split_viewports)
	if is_instance_valid(SettingsManager):
		SettingsManager.settings_changed.connect(_sync_split_viewports)
	_sync_split_viewports()

func _create_split_viewport(vp_name: String) -> Array:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.own_world_3d = false
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.audio_listener_enable_3d = false
	vp.audio_listener_enable_2d = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)

	var cam := Camera3D.new()
	cam.name = "SplitCamera"
	if is_instance_valid(camera):
		cam.fov = camera.fov
		cam.near = camera.near
		cam.far = camera.far
		cam.cull_mask = camera.cull_mask
		cam.attributes = camera.attributes
		cam.environment = camera.environment
	cam.current = true
	vp.add_child(cam)
	return [vp, cam]

func _sync_split_viewports() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var root_vp := get_tree().root
	if not is_instance_valid(root_vp):
		return
	var vp_size := Vector2i(maxi(320, root_vp.size.x), maxi(180, root_vp.size.y))
	for vp in [_vp1, _vp2]:
		if is_instance_valid(vp):
			vp.size = vp_size
			vp.msaa_3d = root_vp.msaa_3d
			vp.screen_space_aa = root_vp.screen_space_aa
			vp.positional_shadow_atlas_size = root_vp.positional_shadow_atlas_size
	if _split_mat != null:
		_split_mat.set_shader_parameter("aspect", float(vp_size.x) / maxf(1.0, float(vp_size.y)))

func is_splitscreen_active() -> bool:
	return _split_alpha > 0.02 and is_instance_valid(_split_rect) and _split_rect.visible

func is_target_in_splitscreen(target: Node3D) -> bool:
	return is_splitscreen_active() and _split_players.has(target)

func _is_gameplay_mouse_allowed() -> bool:
	if get_tree().paused:
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("is_ui_blocking_gameplay") and hud.is_ui_blocking_gameplay():
		return false
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_inside_tree() and _is_gameplay_mouse_allowed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	if not _is_gameplay_mouse_allowed():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_yaw -= deg_to_rad(15.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_yaw += deg_to_rad(15.0)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := SettingsManager.camera_sensitivity if is_instance_valid(SettingsManager) else 1.0
		var inv := -1.0 if (is_instance_valid(SettingsManager) and SettingsManager.invert_camera_x) else 1.0
		target_yaw -= (event as InputEventMouseMotion).relative.x * mouse_sensitivity * sens * inv

	# Snap rotation steps
	if event.is_action_pressed("cam_rotate_left"):
		target_yaw -= deg_to_rad(45.0)
	elif event.is_action_pressed("cam_rotate_right"):
		target_yaw += deg_to_rad(45.0)

func _physics_process(delta: float) -> void:
	_handle_input_held(delta)
	_update_shake(delta)
	_update_rotation(delta)
	_update_tracking(delta)
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

	# Track living explorers (smoothly spectate living teammates if local explorer dies)
	var active_list: Array[Node3D] = []
	for t in targets:
		if not ("current_health" in t) or t.current_health > 0:
			active_list.append(t)
	if active_list.is_empty():
		if is_instance_valid(NetworkManager) and NetworkManager.is_online:
			for p in get_tree().get_nodes_in_group("player"):
				if p is Node3D and is_instance_valid(p) and (not ("current_health" in p) or p.current_health > 0):
					active_list.append(p)
		if active_list.is_empty():
			active_list = targets

	var is_online := is_instance_valid(NetworkManager) and NetworkManager.is_online
	var can_split := dynamic_splitscreen_enabled and not is_online and active_list.size() == 2

	if can_split:
		var p1: Node3D = active_list[0]
		var p2: Node3D = active_list[1]
		if "player_id" in p1 and "player_id" in p2 and int(p1.player_id) > int(p2.player_id):
			var tmp: Node3D = p1
			p1 = p2
			p2 = tmp
		_split_players = [p1, p2]

		var diff_xz := Vector2(p2.global_position.x - p1.global_position.x, p2.global_position.z - p1.global_position.z)
		var dist := diff_xz.length()
		if dist > 0.35:
			var target_angle := diff_xz.angle()
			if not _has_world_dir:
				_smooth_world_dir_xz = diff_xz / dist
				_has_world_dir = true
			else:
				var cur_angle := _smooth_world_dir_xz.angle()
				var next_angle := lerp_angle(cur_angle, target_angle, minf(1.0, split_direction_smooth * delta))
				_smooth_world_dir_xz = Vector2(cos(next_angle), sin(next_angle))

		var mid := (p1.global_position + p2.global_position) * 0.5
		global_position = global_position.lerp(mid + shake_offset, follow_speed * delta)

		var target_distance: float
		if dist <= split_start_distance:
			var z_t := clampf((dist - zoom_margin) / maxf(0.1, split_start_distance - zoom_margin), 0.0, 1.0)
			target_distance = lerpf(min_zoom_distance, split_threshold_zoom, z_t)
		else:
			var s_t := clampf((dist - split_start_distance) / 4.5, 0.0, 1.0)
			target_distance = lerpf(split_threshold_zoom, split_camera_distance, s_t)
		camera.position.z = lerpf(camera.position.z, target_distance, follow_speed * delta)

		var target1 := mid + shake_offset
		var target2 := mid + shake_offset
		if dist > split_start_distance:
			var split_excess := dist - split_start_distance
			var actual_dir3 := Vector3(diff_xz.x, 0.0, diff_xz.y) / maxf(0.001, dist)
			var smooth_dir3 := Vector3(_smooth_world_dir_xz.x, 0.0, _smooth_world_dir_xz.y)
			var blend_dir := actual_dir3.lerp(smooth_dir3, clampf(split_excess / 2.5, 0.0, 1.0)).normalized()
			var y_t := clampf(split_excess / 4.0, 0.0, 1.0)
			target1 = mid - blend_dir * (split_excess * 0.5) + shake_offset
			target2 = mid + blend_dir * (split_excess * 0.5) + shake_offset
			target1.y = lerpf(mid.y, p1.global_position.y, y_t) + shake_offset.y
			target2.y = lerpf(mid.y, p2.global_position.y, y_t) + shake_offset.y

		if not _split_focus_initialized:
			_cam1_focus = global_position
			_cam2_focus = global_position
			_split_focus_initialized = true
		else:
			_cam1_focus = _cam1_focus.lerp(target1, follow_speed * delta)
			_cam2_focus = _cam2_focus.lerp(target2, follow_speed * delta)

		var cam_sep := _cam1_focus.distance_to(_cam2_focus)
		var needs_vp := dist >= (split_start_distance - 1.5) or cam_sep > 0.04 or _split_alpha > 0.004
		_apply_split_render_state(delta, needs_vp, cam_sep, true)
	else:
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

		if _split_alpha > 0.004 or (_split_focus_initialized and _cam1_focus.distance_to(_cam2_focus) > 0.04):
			_cam1_focus = _cam1_focus.lerp(global_position, follow_speed * delta)
			_cam2_focus = _cam2_focus.lerp(global_position, follow_speed * delta)
			_apply_split_render_state(delta, true, _cam1_focus.distance_to(_cam2_focus), false)
		else:
			_split_players.clear()
			_split_focus_initialized = false
			_apply_split_render_state(delta, false, 0.0, false)

func _apply_split_render_state(delta: float, active_vp: bool, cam_sep: float, allow_grow: bool) -> void:
	if not is_instance_valid(_vp1) or not is_instance_valid(_vp2) or not is_instance_valid(_split_rect):
		return
	if active_vp:
		_vp1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_split_warmup_frames = mini(_split_warmup_frames + 1, 10)

		var cam_basis := camera.global_transform.basis
		var cam_dist := camera.position.z
		_cam1.global_transform = Transform3D(cam_basis, _cam1_focus + cam_basis.z * cam_dist)
		_cam2.global_transform = Transform3D(cam_basis, _cam2_focus + cam_basis.z * cam_dist)

		var dir3 := Vector3(_smooth_world_dir_xz.x, 0.0, _smooth_world_dir_xz.y)
		var screen_dir := Vector2(dir3.dot(cam_basis.x), -dir3.dot(cam_basis.y))
		if screen_dir.length_squared() < 0.0001:
			screen_dir = Vector2(1.0, 0.0)
		else:
			screen_dir = screen_dir.normalized()

		var target_alpha := clampf(cam_sep / 2.4, 0.0, 1.0)
		if not allow_grow:
			target_alpha = minf(target_alpha, 0.0 if cam_sep < 0.15 else clampf(cam_sep / 2.4, 0.0, 1.0))
		_split_alpha = lerpf(_split_alpha, target_alpha, minf(1.0, 6.5 * delta))
		if cam_sep < 0.03 and target_alpha <= 0.001 and _split_alpha < 0.008:
			_split_alpha = 0.0

		if _split_mat != null:
			_split_mat.set_shader_parameter("split_normal", screen_dir)
			_split_mat.set_shader_parameter("split_alpha", _split_alpha)

		_split_rect.visible = (_split_alpha > 0.004 and _split_warmup_frames >= 2)
		if not allow_grow and cam_sep <= 0.04 and _split_alpha <= 0.004:
			_vp1.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_split_warmup_frames = 0
			_split_rect.visible = false
			_split_players.clear()
			_split_focus_initialized = false
	else:
		_split_alpha = 0.0
		_split_warmup_frames = 0
		_split_rect.visible = false
		_vp1.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _update_rotation(delta: float) -> void:
	yaw_pivot.rotation.y = lerp_angle(yaw_pivot.rotation.y, target_yaw, rotation_speed * delta)

func _update_wall_occlusion() -> void:
	if targets.is_empty():
		return

	var space_state = get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	var use_split_cams := is_splitscreen_active() and _split_players.size() == 2 and is_instance_valid(_cam1) and is_instance_valid(_cam2)
	_hit_meshes_buf.clear()

	for t in targets:
		if use_split_cams:
			if t == _split_players[0]:
				_occlusion_ray_query.from = _cam1.global_position
			elif t == _split_players[1]:
				_occlusion_ray_query.from = _cam2.global_position
			else:
				_occlusion_ray_query.from = cam_pos
		else:
			_occlusion_ray_query.from = cam_pos
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
