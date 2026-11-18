extends Node3D
class_name WhipHook
## Overhead bronze anchor ring that players can whip to swing across chasms.

@export var hook_height: float = 3.2
@export var swing_landing_distance: float = 2.6

var _ring_mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("whip_hook")
	_build_visuals()
	_build_area()

func _build_visuals() -> void:
	# Overhead stone bracket
	var bracket := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.35, 0.45)
	bracket.mesh = box
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.36, 0.28)
	stone_mat.roughness = 0.85
	bracket.material_override = stone_mat
	bracket.position = Vector3(0.0, hook_height + 0.35, 0.0)
	add_child(bracket)

	# Glowing bronze ring
	_ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.36
	_ring_mesh.mesh = torus
	var bronze_mat := StandardMaterial3D.new()
	bronze_mat.albedo_color = Color(0.95, 0.72, 0.22)
	bronze_mat.metallic = 0.85
	bronze_mat.roughness = 0.25
	bronze_mat.emission_enabled = true
	bronze_mat.emission = Color(1.0, 0.75, 0.2)
	bronze_mat.emission_energy_multiplier = 0.45
	_ring_mesh.material_override = bronze_mat
	_ring_mesh.position = Vector3(0.0, hook_height, 0.0)
	_ring_mesh.rotation.x = deg_to_rad(90.0)
	add_child(_ring_mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.35)
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0.0, hook_height - 0.3, 0.0)
	add_child(light)

func _build_area() -> void:
	var area := Area3D.new()
	area.collision_layer = 4 # Interactables layer (hit by whip raycast)
	area.collision_mask = 0
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.85
	cyl.height = hook_height + 0.6
	col.shape = cyl
	col.position = Vector3(0.0, (hook_height + 0.6) * 0.5, 0.0)
	area.add_child(col)
	add_child(area)

func on_whipped(player: Player) -> void:
	if not is_instance_valid(player) or player.is_swinging:
		return
	var offset_xz := Vector3(global_position.x - player.global_position.x, 0.0, global_position.z - player.global_position.z)
	if offset_xz.length_squared() < 0.04:
		return
	var dir := offset_xz.normalized()
	var dist := clampf(offset_xz.length(), 1.6, swing_landing_distance)
	var landing := Vector3(global_position.x + dir.x * dist, player.global_position.y, global_position.z + dir.z * dist)

	if is_instance_valid(_ring_mesh):
		var t := create_tween()
		t.tween_property(_ring_mesh, "scale", Vector3.ONE * 1.25, 0.08)
		t.tween_property(_ring_mesh, "scale", Vector3.ONE, 0.16)

	player.swing_across(global_position + Vector3(0.0, hook_height, 0.0), landing, 0.42)
