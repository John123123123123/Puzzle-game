extends StaticBody3D
class_name Brazier

signal lit_state_changed(is_lit: bool)

@export var is_lit: bool = false
@export var linked_targets: Array[NodePath] = []

@onready var flame_mesh: Node3D = $FlameMesh
@onready var fire_light: OmniLight3D = $FireLight
@onready var interaction_area: Area3D = $InteractionArea
@onready var coal_bed: MeshInstance3D = get_node_or_null("CoalBed")
@onready var rune_collar: MeshInstance3D = get_node_or_null("RuneCollar")

var _flicker_time: float = 0.0
var _coal_mat: StandardMaterial3D = null
var _collar_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("brazier")
	add_to_group("interactable")
	interaction_area.body_entered.connect(_on_body_entered)
	_flicker_time = randf() * 10.0

	if is_instance_valid(coal_bed):
		var cm := coal_bed.get_active_material(0) as StandardMaterial3D
		if cm:
			_coal_mat = cm.duplicate() as StandardMaterial3D
			coal_bed.material_override = _coal_mat

	if is_instance_valid(rune_collar):
		var rm := rune_collar.get_active_material(0) as StandardMaterial3D
		if rm:
			_collar_mat = rm.duplicate() as StandardMaterial3D
			rune_collar.material_override = _collar_mat

	_update_visuals(false)

func _process(delta: float) -> void:
	if is_lit:
		_flicker_time += delta
		var pulse := sin(_flicker_time * 11.0) * 0.18 + sin(_flicker_time * 23.0) * 0.10
		if is_instance_valid(fire_light):
			fire_light.light_energy = 2.65 + pulse
		if _coal_mat:
			_coal_mat.emission_energy_multiplier = 2.2 + pulse * 1.4

func get_interact_prompt() -> String:
	return "" if is_lit else "Requires Torch"

func get_interact_prompt_for(player: Player) -> String:
	if is_lit:
		return ""
	if is_instance_valid(player) and player.carried_item is Torch:
		return "Light Brazier"
	return "Requires Torch"

func interact(player: Player) -> void:
	if not is_lit and is_instance_valid(player) and player.carried_item is Torch and _has_clear_los_to(player):
		ignite()

func on_whipped(_player: Player) -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	if is_lit:
		return
	if body is Player and body.carried_item is Torch and _has_clear_los_to(body):
		ignite()

func _has_clear_los_to(player: Player) -> bool:
	if not is_instance_valid(player):
		return false
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return true
	var from_pos := player.global_position + Vector3(0.0, 0.85, 0.0)
	var to_pos := global_position + Vector3(0.0, 0.85, 0.0)
	var rq := PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
	rq.collide_with_areas = false
	rq.collide_with_bodies = true
	rq.exclude = [get_rid(), player.get_rid()]
	return space_state.intersect_ray(rq).is_empty()

func ignite() -> void:
	if is_lit:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		_rpc_request_ignite.rpc_id(1)
		return
	_do_ignite()
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_ignite.rpc()

@rpc("any_peer", "reliable")
func _rpc_request_ignite() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_host:
		ignite()

@rpc("authority", "reliable")
func _rpc_sync_ignite() -> void:
	_do_ignite()

func _do_ignite() -> void:
	if is_lit:
		return
	is_lit = true
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"brazier_ignite", global_position, 0.94, 1.06, -1.0, 20.0, 5.0)
	_update_visuals(true)
	lit_state_changed.emit(true)

	for path in linked_targets:
		var node = get_node_or_null(path)
		if node and node.has_method("register_trigger_activated"):
			node.register_trigger_activated()

func _update_visuals(animate: bool) -> void:
	set_process(is_lit)
	if is_instance_valid(flame_mesh):
		flame_mesh.visible = is_lit
		var particles := flame_mesh.get_node_or_null("FireParticles") as CPUParticles3D
		if is_instance_valid(particles):
			particles.emitting = is_lit
		if is_lit and animate:
			flame_mesh.scale = Vector3(0.35, 0.2, 0.35)
			var f_tw := create_tween()
			f_tw.tween_property(flame_mesh, "scale", Vector3(1.25, 1.35, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			f_tw.tween_property(flame_mesh, "scale", Vector3.ONE, 0.22)

	if _coal_mat:
		_coal_mat.albedo_color = Color(0.24, 0.11, 0.06) if is_lit else Color(0.11, 0.10, 0.10)
		_coal_mat.emission_enabled = true
		_coal_mat.emission = Color(1.0, 0.36, 0.06) if is_lit else Color(0.25, 0.12, 0.05)
		_coal_mat.emission_energy_multiplier = 2.2 if is_lit else 0.04

	if _collar_mat:
		_collar_mat.emission_enabled = true
		_collar_mat.emission = Color(1.0, 0.72, 0.20) if is_lit else Color(0.35, 0.26, 0.10)
		_collar_mat.emission_energy_multiplier = 0.85 if is_lit else 0.08

	if fire_light:
		if is_lit:
			fire_light.light_energy = 2.65
			if animate:
				var tween = create_tween()
				fire_light.light_energy = 5.2
				tween.tween_property(fire_light, "light_energy", 2.65, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			fire_light.light_energy = 0.0
