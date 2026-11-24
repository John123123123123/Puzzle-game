extends StaticBody3D
class_name MirrorPillar

signal rotated(new_angle: float)

@export var current_step: int = 0 # 0=North (0°), 1=East (90°), 2=South (180°), 3=West (270°)
@export var is_rotatable: bool = true

@onready var pillar_top: Node3D = $PillarTop
@onready var mirror_mesh: MeshInstance3D = $PillarTop/MirrorFrame/MirrorDisc
@onready var beam_root: Node3D = $PillarTop/BeamPivot
@onready var core_mesh_inst: MeshInstance3D = $PillarTop/BeamPivot/CoreBeam
@onready var aura_mesh_inst: MeshInstance3D = $PillarTop/BeamPivot/AuraBeam
@onready var impact_light: OmniLight3D = $PillarTop/BeamPivot/ImpactLight
@onready var impact_flare: MeshInstance3D = $PillarTop/BeamPivot/ImpactFlare
@onready var mirror_light: OmniLight3D = $PillarTop/MirrorLight

var is_illuminated: bool = false
var is_turning: bool = false
var target_rot_y: float = 0.0
var _last_beam_length: float = -1.0
var _ray_query: PhysicsRayQueryParameters3D = null

func _ready() -> void:
	add_to_group("mirror")
	add_to_group("interactable")

	# Duplicate cylinder meshes and mirror material so each instance is independent
	if is_instance_valid(core_mesh_inst) and core_mesh_inst.mesh:
		core_mesh_inst.mesh = core_mesh_inst.mesh.duplicate()
	if is_instance_valid(aura_mesh_inst) and aura_mesh_inst.mesh:
		aura_mesh_inst.mesh = aura_mesh_inst.mesh.duplicate()
	if is_instance_valid(mirror_mesh):
		var mat = mirror_mesh.get_active_material(0)
		if mat:
			mirror_mesh.material_override = mat.duplicate()

	# Initial angle: 0=North (-Z), 1=East (+X, -90°), 2=South (+Z, -180°), 3=West (-X, -270°)
	target_rot_y = -float(current_step) * (PI / 2.0)
	if is_instance_valid(pillar_top):
		pillar_top.rotation.y = target_rot_y

	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1
	_ray_query.collide_with_areas = false
	_ray_query.collide_with_bodies = true
	if self is CollisionObject3D:
		_ray_query.exclude = [get_rid()]

	set_beam_active(false)

func get_interact_prompt() -> String:
	return "Rotate Mirror"

func interact(player: Player) -> void:
	if not is_rotatable or is_turning:
		return
	rotate_pillar()

func on_whipped(_player: Player) -> void:
	if not is_rotatable or is_turning:
		return
	rotate_pillar()

func rotate_pillar() -> void:
	is_turning = true
	current_step = (current_step + 1) % 4
	target_rot_y -= PI / 2.0 # Smooth clockwise rotation

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"mirror_turn", global_position, 0.96, 1.04, 0.0, 25.0, 5.0)

	var tween = create_tween()
	tween.tween_property(pillar_top, "rotation:y", target_rot_y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	is_turning = false
	rotated.emit(target_rot_y)

## Casts a dynamic 3D ray along the mirror's facing direction to find walls, blocks, mirrors, or sun receivers.
func trace_beam(max_distance: float = 30.0) -> Dictionary:
	var result_data := {
		"length": max_distance,
		"hit_mirror": null,
		"hit_receiver": null
	}
	if not is_instance_valid(beam_root) or not is_inside_tree():
		return result_data

	var origin: Vector3 = beam_root.global_position
	var dir: Vector3 = -beam_root.global_basis.z.normalized()
	var space_state := get_world_3d().direct_space_state

	_ray_query.from = origin
	_ray_query.to = origin + dir * max_distance

	var hit := space_state.intersect_ray(_ray_query)
	var closest_dist: float = max_distance
	if hit:
		closest_dist = origin.distance_to(hit.position)
		if hit.collider is MirrorPillar:
			result_data["hit_mirror"] = hit.collider

	# Check SunReceivers along the ray segment (before any physics wall hit)
	for node in get_tree().get_nodes_in_group("sun_receiver"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var to_node: Vector3 = node.global_position - origin
		var proj: float = to_node.dot(dir)
		if proj > 0.2 and proj <= closest_dist + 0.35:
			var perp_dist: float = (to_node - dir * proj).length()
			if perp_dist <= 0.65:
				closest_dist = proj
				result_data["hit_mirror"] = null
				result_data["hit_receiver"] = node

	result_data["length"] = closest_dist
	return result_data

func set_beam_active(active: bool, length: float = 8.0) -> void:
	if is_illuminated == active and (not active or absf(_last_beam_length - length) < 0.005):
		return
	is_illuminated = active
	_last_beam_length = length if active else -1.0

	if not is_instance_valid(beam_root):
		return

	beam_root.visible = active
	if is_instance_valid(mirror_light):
		mirror_light.visible = active

	if active:
		if is_instance_valid(core_mesh_inst):
			var c_mesh = core_mesh_inst.mesh as CylinderMesh
			if c_mesh:
				c_mesh.height = length
			core_mesh_inst.position.z = -length * 0.5

		if is_instance_valid(aura_mesh_inst):
			var a_mesh = aura_mesh_inst.mesh as CylinderMesh
			if a_mesh:
				a_mesh.height = length
			aura_mesh_inst.position.z = -length * 0.5

		if is_instance_valid(impact_light):
			impact_light.position.z = -length
		if is_instance_valid(impact_flare):
			impact_flare.position.z = -length

		# Mirror reflection highlight
		if is_instance_valid(mirror_mesh):
			var mat = mirror_mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.92, 0.6)
				mat.emission_energy_multiplier = 1.8
	else:
		if is_instance_valid(mirror_mesh):
			var mat = mirror_mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.emission_enabled = false
