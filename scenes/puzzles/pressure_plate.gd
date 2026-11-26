extends Node3D
class_name PressurePlate

signal state_changed(is_pressed: bool)

@export var required_target_name: String = "" # Empty means any player or block
@export var is_permanent: bool = false # Stays pressed once activated
@export var player_only: bool = false # Co-op Guardian Seal: only living players can press
@export var min_players: int = 1

var is_pressed: bool = false
var occupying_bodies: Array[Node3D] = []
var _coop_enabled: bool = true

@onready var plate_mesh: MeshInstance3D = $PlateMesh
@onready var trigger_area: Area3D = $TriggerArea
@onready var rune_light: OmniLight3D = $RuneLight
@onready var rune_glyph: MeshInstance3D = $PlateMesh/RuneGlyph

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")

var initial_y: float = 0.08
var pressed_y: float = 0.015
var _corner_gem_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("pressure_plate")
	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)
	plate_mesh.position.y = initial_y

	var first_gem := get_node_or_null("BaseRim/GemNW") as MeshInstance3D
	if is_instance_valid(first_gem):
		var gm := first_gem.get_active_material(0) as StandardMaterial3D
		if gm:
			_corner_gem_mat = gm.duplicate() as StandardMaterial3D
			for g_name in ["BaseRim/GemNW", "BaseRim/GemNE", "BaseRim/GemSW", "BaseRim/GemSE"]:
				var g_node := get_node_or_null(g_name) as MeshInstance3D
				if is_instance_valid(g_node):
					g_node.material_override = _corner_gem_mat

	if is_instance_valid(rune_glyph):
		var mat = rune_glyph.get_active_material(0)
		if mat:
			var dup = mat.duplicate()
			if player_only and dup is ShaderMaterial:
				dup.set_shader_parameter("rune_glow_color", Color(0.28, 0.88, 1.0, 1.0))
			rune_glyph.material_override = dup

	# Initial visuals
	_update_visuals(false, false)

func apply_coop_difficulty(player_count: int) -> void:
	_coop_enabled = player_count >= min_players
	visible = _coop_enabled
	if is_instance_valid(trigger_area):
		trigger_area.set_deferred("monitoring", _coop_enabled)
	if not _coop_enabled:
		occupying_bodies.clear()
		if is_pressed:
			is_pressed = false
			state_changed.emit(false)

func _is_valid_body(body: Node3D) -> bool:
	if not _coop_enabled or not is_instance_valid(body) or not body.is_inside_tree():
		return false

	# Must not be static environment (e.g. floors, walls, rims)
	if body is StaticBody3D:
		return false

	# If a specific target name is required
	if not required_target_name.is_empty():
		return body.name == required_target_name or body.is_in_group(required_target_name)

	# Valid bodies: Players (and Pushable Blocks unless player_only is set)
	if body is Player or body.is_in_group("player"):
		return not ("current_health" in body and body.current_health <= 0)
	if not player_only and (body is PushableBlock or body.is_in_group("pushable") or body.is_in_group("block")):
		return true

	return false

func _on_body_entered(body: Node3D) -> void:
	if not _is_valid_body(body):
		return

	if not occupying_bodies.has(body):
		occupying_bodies.append(body)
	_update_state()

func _on_body_exited(body: Node3D) -> void:
	occupying_bodies.erase(body)
	_update_state()

func _update_state() -> void:
	# Clean up any destroyed, exited, or dead bodies
	occupying_bodies = occupying_bodies.filter(func(b): return _is_valid_body(b))

	var should_press = occupying_bodies.size() > 0

	if is_permanent and is_pressed:
		return

	if should_press != is_pressed:
		is_pressed = should_press
		_animate_plate(is_pressed)
		_update_visuals(is_pressed, true)
		if is_pressed and is_instance_valid(AudioManager):
			AudioManager.play_sfx_3d(&"plate_click", global_position, 0.96, 1.04, 0.0, 25.0, 6.0)
		if is_pressed:
			_spawn_press_burst()
		state_changed.emit(is_pressed)

func _animate_plate(pressed: bool) -> void:
	var target_y = pressed_y if pressed else initial_y
	var tween = create_tween()
	tween.tween_property(plate_mesh, "position:y", target_y, 0.12) \
		.set_trans(Tween.TRANS_BACK if pressed else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)

func _update_visuals(pressed: bool, animate: bool) -> void:
	var target_energy = 2.8 if pressed else 0.4
	var active_col := Color(0.28, 0.92, 1.0) if player_only else Color(1.0, 0.9, 0.3)
	var idle_col := Color(0.18, 0.52, 0.72) if player_only else Color(0.7, 0.55, 0.2)
	var target_color = active_col if pressed else idle_col

	if rune_light:
		if animate:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(rune_light, "light_energy", target_energy, 0.2)
			tween.tween_property(rune_light, "light_color", target_color, 0.2)
		else:
			rune_light.light_energy = target_energy
			rune_light.light_color = target_color

	if rune_glyph:
		var mat = rune_glyph.get_active_material(0) as ShaderMaterial
		if not mat and rune_glyph.material_override:
			mat = rune_glyph.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("emission_energy", 4.5 if pressed else 1.2)
			mat.set_shader_parameter("pressed_ratio", 1.0 if pressed else 0.0)

	if _corner_gem_mat:
		_corner_gem_mat.albedo_color = target_color
		_corner_gem_mat.emission = target_color
		_corner_gem_mat.emission_energy_multiplier = 2.8 if pressed else 0.6

func _spawn_press_burst() -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	DUST_PUFF.spawn(parent_node, global_position + Vector3(0.0, 0.05, 0.0), 4, 0.95)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.62
	torus.rings = 24
	torus.ring_segments = 6
	var r_mat := StandardMaterial3D.new()
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var c := Color(0.28, 0.92, 1.0, 0.85) if player_only else Color(1.0, 0.88, 0.28, 0.85)
	r_mat.albedo_color = c
	torus.material = r_mat
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent_node.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.12, 0.0)
	ring.scale = Vector3(0.65, 1.0, 0.65)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.55, 1.0, 1.55), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(r_mat, "albedo_color:a", 0.0, 0.30)
	tw.chain().tween_callback(ring.queue_free)
