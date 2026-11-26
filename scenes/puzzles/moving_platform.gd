extends AnimatableBody3D
class_name MovingPlatform
## Gear-driven sandstone raft that shuttles smoothly between start_pos and start_pos + travel_offset.

@export var platform_size: Vector3 = Vector3(3.2, 0.34, 3.2)
@export var travel_offset: Vector3 = Vector3(8.0, 0.0, 0.0)
@export var travel_duration: float = 3.2
@export var pause_duration: float = 0.9
@export var starts_active: bool = true

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var raft_mesh: MeshInstance3D = $RaftMesh
@onready var trim_group: Node3D = $TrimGroup

var is_active: bool = true
var _start_pos: Vector3 = Vector3.ZERO
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("moving_platform")
	sync_to_physics = true
	is_active = starts_active
	_start_pos = global_position
	_configure_geometry()

func _configure_geometry() -> void:
	if is_instance_valid(collision_shape):
		var bs := BoxShape3D.new()
		bs.size = platform_size
		collision_shape.shape = bs

	if is_instance_valid(raft_mesh):
		var bm := BoxMesh.new()
		bm.size = platform_size
		var orig := raft_mesh.get_active_material(0)
		if orig is ShaderMaterial:
			var sm := orig.duplicate() as ShaderMaterial
			sm.set_shader_parameter("platform_half_size", platform_size * 0.5)
			bm.material = sm
		elif orig != null:
			bm.material = orig
		raft_mesh.mesh = bm

	if is_instance_valid(trim_group):
		for ch in trim_group.get_children():
			ch.queue_free()

		var bronze_mat := StandardMaterial3D.new()
		bronze_mat.albedo_color = Color(0.68, 0.52, 0.24)
		bronze_mat.metallic = 0.86
		bronze_mat.roughness = 0.28

		var chassis_mat := StandardMaterial3D.new()
		chassis_mat.albedo_color = Color(0.22, 0.19, 0.16)
		chassis_mat.metallic = 0.78
		chassis_mat.roughness = 0.44

		var finial_mat := StandardMaterial3D.new()
		finial_mat.albedo_color = Color(1.0, 0.80, 0.36)
		finial_mat.emission_enabled = true
		finial_mat.emission = Color(1.0, 0.76, 0.30)
		finial_mat.emission_energy_multiplier = 0.85

		# 1. Dark cast-bronze undercarriage chassis
		var chassis_mesh := BoxMesh.new()
		chassis_mesh.size = Vector3(maxf(0.4, platform_size.x - 0.14), 0.14, maxf(0.4, platform_size.z - 0.14))
		chassis_mesh.material = chassis_mat
		var chassis := MeshInstance3D.new()
		chassis.mesh = chassis_mesh
		chassis.position = Vector3(0.0, -platform_size.y * 0.5 - 0.05, 0.0)
		trim_group.add_child(chassis)

		# 2. Four perimeter beveled bronze side rails
		var rail_ns_mesh := BoxMesh.new()
		rail_ns_mesh.size = Vector3(platform_size.x + 0.04, 0.08, 0.06)
		rail_ns_mesh.material = bronze_mat
		for sz in [-1.0, 1.0]:
			var r_ns := MeshInstance3D.new()
			r_ns.mesh = rail_ns_mesh
			r_ns.position = Vector3(0.0, -0.02, sz * (platform_size.z * 0.5 + 0.01))
			trim_group.add_child(r_ns)

		var rail_ew_mesh := BoxMesh.new()
		rail_ew_mesh.size = Vector3(0.06, 0.08, platform_size.z + 0.04)
		rail_ew_mesh.material = bronze_mat
		for sx in [-1.0, 1.0]:
			var r_ew := MeshInstance3D.new()
			r_ew.mesh = rail_ew_mesh
			r_ew.position = Vector3(sx * (platform_size.x * 0.5 + 0.01), -0.02, 0.0)
			trim_group.add_child(r_ew)

		# 3. Four sculpted corner bronze bollards (plinth + 6-sided post + warm-gold finial cap)
		var plinth_mesh := BoxMesh.new()
		plinth_mesh.size = Vector3(0.24, 0.06, 0.24)
		plinth_mesh.material = bronze_mat

		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.075
		post_mesh.bottom_radius = 0.10
		post_mesh.height = 0.20
		post_mesh.radial_segments = 6
		post_mesh.material = bronze_mat

		var finial_mesh := CylinderMesh.new()
		finial_mesh.top_radius = 0.01
		finial_mesh.bottom_radius = 0.06
		finial_mesh.height = 0.08
		finial_mesh.radial_segments = 6
		finial_mesh.material = finial_mat

		var top_y := platform_size.y * 0.5
		var hx := platform_size.x * 0.5 - 0.16
		var hz := platform_size.z * 0.5 - 0.16
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner_pos := Vector3(sx * hx, top_y, sz * hz)
				var plinth := MeshInstance3D.new()
				plinth.mesh = plinth_mesh
				plinth.position = corner_pos + Vector3(0.0, 0.03, 0.0)
				trim_group.add_child(plinth)

				var post := MeshInstance3D.new()
				post.mesh = post_mesh
				post.position = corner_pos + Vector3(0.0, 0.16, 0.0)
				trim_group.add_child(post)

				var cap := MeshInstance3D.new()
				cap.mesh = finial_mesh
				cap.position = corner_pos + Vector3(0.0, 0.30, 0.0)
				trim_group.add_child(cap)

		# 4. Side gear-tooth bumpers along edges perpendicular to travel
		var move_along_x := absf(travel_offset.x) >= absf(travel_offset.z)
		var tooth_mesh := BoxMesh.new()
		tooth_mesh.size = Vector3(0.14, 0.10, 0.10) if move_along_x else Vector3(0.10, 0.10, 0.14)
		tooth_mesh.material = chassis_mat
		var span := (platform_size.x if move_along_x else platform_size.z) * 0.30
		for side in [-1.0, 1.0]:
			for idx in [-1.0, 0.0, 1.0]:
				var tooth := MeshInstance3D.new()
				tooth.mesh = tooth_mesh
				if move_along_x:
					tooth.position = Vector3(idx * span, -platform_size.y * 0.5 - 0.03, side * (platform_size.z * 0.5 - 0.02))
				else:
					tooth.position = Vector3(side * (platform_size.x * 0.5 - 0.02), -platform_size.y * 0.5 - 0.03, idx * span)
				trim_group.add_child(tooth)

func register_trigger_activated() -> void:
	is_active = true

func register_trigger_deactivated() -> void:
	is_active = false

func toggle() -> void:
	is_active = not is_active

func sync_network_time(host_clock: float) -> void:
	if absf(_clock - host_clock) > 0.22:
		_clock = host_clock

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	_clock += delta
	var leg_dur := maxf(0.2, travel_duration)
	var hold_dur := maxf(0.0, pause_duration)
	var half_cycle := leg_dur + hold_dur
	var full_cycle := half_cycle * 2.0
	var t_in_cycle := fposmod(_clock, full_cycle)

	var frac: float
	if t_in_cycle < hold_dur:
		frac = 0.0
	elif t_in_cycle < half_cycle:
		var u := (t_in_cycle - hold_dur) / leg_dur
		frac = 0.5 - 0.5 * cos(u * PI)
	elif t_in_cycle < half_cycle + hold_dur:
		frac = 1.0
	else:
		var u2 := (t_in_cycle - half_cycle - hold_dur) / leg_dur
		frac = 0.5 + 0.5 * cos(u2 * PI)

	global_position = _start_pos + travel_offset * frac
