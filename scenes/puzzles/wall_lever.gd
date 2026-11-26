extends Node3D
class_name WallLever

signal toggled(is_on: bool)

@export var is_on: bool = false
@export var is_one_shot: bool = false
@export var targets: Array[NodePath] = []

@onready var handle_pivot: Node3D = $Base/HandlePivot
@onready var light_indicator: OmniLight3D = $LightIndicator
@onready var rune_mesh: MeshInstance3D = get_node_or_null("RuneIndicator")
@onready var rune_channel_l: MeshInstance3D = get_node_or_null("Base/RuneChannelL")
@onready var rune_channel_r: MeshInstance3D = get_node_or_null("Base/RuneChannelR")
@onready var knob_gem: MeshInstance3D = get_node_or_null("Base/HandlePivot/Knob/KnobGem")

var _rune_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("whip_target")
	if is_instance_valid(rune_mesh):
		var mat = rune_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			_rune_mat = mat.duplicate() as StandardMaterial3D
			rune_mesh.material_override = _rune_mat
			for extra in [rune_channel_l, rune_channel_r, knob_gem]:
				if is_instance_valid(extra):
					extra.material_override = _rune_mat
	_update_visuals(false)

func get_interact_prompt() -> String:
	return "Pull Lever" if not is_on else "Reset Lever"

func interact(_player: Player) -> void:
	toggle()

func on_whipped(_player: Player) -> void:
	toggle()

func toggle() -> void:
	if is_one_shot and is_on:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		_rpc_request_toggle.rpc_id(1)
		return
	_apply_toggle_state(not is_on)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_toggle.rpc(is_on)

@rpc("any_peer", "reliable")
func _rpc_request_toggle() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_host:
		toggle()

@rpc("authority", "reliable")
func _rpc_sync_toggle(new_state: bool) -> void:
	if is_on != new_state:
		_apply_toggle_state(new_state)

func _apply_toggle_state(new_state: bool) -> void:
	is_on = new_state
	_update_visuals(true)
	toggled.emit(is_on)

	# Trigger any directly linked objects (like doors or traps)
	for path in targets:
		var node = get_node_or_null(path)
		if node:
			if is_on and node.has_method("register_trigger_activated"):
				node.register_trigger_activated()
			elif not is_on and node.has_method("register_trigger_deactivated"):
				node.register_trigger_deactivated()
			elif node.has_method("toggle"):
				node.toggle()

func _update_visuals(animate: bool) -> void:
	# Unpulled (UP): 16° tilted out from wall into room
	# Pulled (DOWN): 116° pulled down into locked lower notch
	var target_rot_x = deg_to_rad(116.0) if is_on else deg_to_rad(16.0)
	var target_color = Color(0.2, 1.0, 0.45) if is_on else Color(0.95, 0.25, 0.15)
	var target_energy = 1.5 if is_on else 0.6

	if animate:
		if is_instance_valid(AudioManager):
			AudioManager.play_sfx_3d(&"lever_clank", global_position, 0.96, 1.04, 0.0, 18.0, 4.0)
		_spawn_axle_sparks(target_color)

		var tween = create_tween().set_parallel(true)
		tween.tween_property(handle_pivot, "rotation:x", target_rot_x, 0.28)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		if light_indicator:
			tween.tween_property(light_indicator, "light_color", target_color, 0.2)
			tween.tween_property(light_indicator, "light_energy", target_energy, 0.2)

		if _rune_mat != null:
			tween.tween_property(_rune_mat, "albedo_color", target_color, 0.2)
			tween.tween_property(_rune_mat, "emission", target_color, 0.2)
			tween.tween_property(_rune_mat, "emission_energy_multiplier", 3.2 if is_on else 2.2, 0.2)
	else:
		handle_pivot.rotation.x = target_rot_x
		if light_indicator:
			light_indicator.light_color = target_color
			light_indicator.light_energy = target_energy
		if _rune_mat != null:
			_rune_mat.albedo_color = target_color
			_rune_mat.emission = target_color
			_rune_mat.emission_energy_multiplier = 3.2 if is_on else 2.2

func _spawn_axle_sparks(col: Color) -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.95)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	mesh.material = mat
	var origin := handle_pivot.global_position if is_instance_valid(handle_pivot) else global_position + Vector3(0, 0.4, 0.2)
	for _i in range(6):
		var sp := MeshInstance3D.new()
		sp.mesh = mesh
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent_node.add_child(sp)
		sp.global_position = origin
		var vel := Vector3(randf_range(-0.55, 0.55), randf_range(0.15, 0.65), randf_range(-0.55, 0.55))
		var tw := sp.create_tween().set_parallel(true)
		tw.tween_property(sp, "global_position", origin + vel, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.26)
		tw.chain().tween_callback(sp.queue_free)
