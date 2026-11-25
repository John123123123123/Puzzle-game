extends CharacterBody3D
class_name Player

signal interacted()
signal health_changed(new_health: int)
signal player_died(player: Player)

@export var player_id: int = 1
@export var speed: float = 6.5
@export var acceleration: float = 24.0
@export var friction: float = 20.0
@export var max_health: int = 3

var current_health: int = 3
var carried_item: Node3D = null
var grabbed_block: PushableBlock = null
var current_interactable: Node3D = null
var is_invulnerable: bool = false
var is_whipping: bool = false
var is_staggering: bool = false
var is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _ping_cooldown: float = 0.0
var _haste_timer: float = 0.0

const WHIP_SCENE: PackedScene = preload("res://scenes/characters/whip_effect.tscn")
const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")
const COOP_PING_BEACON := preload("res://scenes/effects/coop_ping_beacon.gd")

var hurt_light: OmniLight3D = null
var prompt_label: Label3D = null
var name_tag_label: Label3D = null
var revive_area: Area3D = null
var _net_sync_timer: float = 0.0
var _remote_target_pos: Vector3 = Vector3.ZERO
var _remote_target_vel: Vector3 = Vector3.ZERO
var _remote_target_yaw: float = 0.0
var _has_remote_state: bool = false
var _last_step_half_cycle: int = 0
var _hud: Node = null
var _coop_cameras: Array = []
var _whip_ray_query: PhysicsRayQueryParameters3D = null
var _last_prompt_target: Node3D = null
var _last_prompt_text: String = ""

# Distinct thematic outfits per player
const OUTFIT_JACKETS: Array[Color] = [
	Color(0.45, 0.28, 0.15), # P1: Indiana Brown Leather
	Color(0.18, 0.36, 0.58), # P2: Deep Explorer Blue
	Color(0.22, 0.44, 0.22), # P3: Safari Jungle Green
	Color(0.65, 0.50, 0.18)  # P4: Desert Nomad Gold
]

const OUTFIT_PANTS: Array[Color] = [
	Color(0.35, 0.30, 0.22), # P1: Khaki
	Color(0.25, 0.25, 0.28), # P2: Slate Grey
	Color(0.30, 0.28, 0.18), # P3: Jungle Cargo
	Color(0.28, 0.22, 0.15)  # P4: Dark Sand
]

const OUTFIT_HATS: Array[Color] = [
	Color(0.30, 0.20, 0.12), # P1: Dark Brown Fedora
	Color(0.15, 0.15, 0.18), # P2: Night Explorer Hat
	Color(0.38, 0.34, 0.24), # P3: Safari Hat
	Color(0.55, 0.45, 0.25)  # P4: Desert Sun Hat
]

# Node references
@onready var mesh_root: Node3D = $MeshRoot
@onready var ring_indicator: MeshInstance3D = $PlayerRing
@onready var interaction_area: Area3D = $InteractionArea

# Skeleton & Limbs hierarchy
@onready var pelvis: Node3D = $MeshRoot/Pelvis
@onready var leg_l: Node3D = $MeshRoot/Pelvis/LegL
@onready var leg_r: Node3D = $MeshRoot/Pelvis/LegR
@onready var pants_l: MeshInstance3D = $MeshRoot/Pelvis/LegL/PantsL
@onready var pants_r: MeshInstance3D = $MeshRoot/Pelvis/LegR/PantsR

@onready var torso: Node3D = $MeshRoot/Torso
@onready var body_mesh: MeshInstance3D = $MeshRoot/Torso/BodyMesh
@onready var arm_l: Node3D = $MeshRoot/Torso/ArmL
@onready var arm_r: Node3D = $MeshRoot/Torso/ArmR
@onready var sleeve_l: MeshInstance3D = $MeshRoot/Torso/ArmL/SleeveL
@onready var sleeve_r: MeshInstance3D = $MeshRoot/Torso/ArmR/SleeveR
@onready var head: Node3D = $MeshRoot/Torso/Head
@onready var hat_brim: MeshInstance3D = $MeshRoot/Torso/Head/Hat/Brim
@onready var hat_crown: MeshInstance3D = $MeshRoot/Torso/Head/Hat/Crown
@onready var carry_slot: Marker3D = $MeshRoot/Torso/CarrySlot

# Animation state variables
var walk_cycle: float = 0.0
var idle_cycle: float = 0.0
var torso_base_y: float = 0.55
var leg_base_l_y: float = 0.0
var leg_base_r_y: float = 0.0

func _ready() -> void:
	current_health = max_health
	torso_base_y = torso.position.y
	leg_base_l_y = leg_l.position.y
	leg_base_r_y = leg_r.position.y

	_apply_player_identity()

	# Register with coop camera & cache HUD/camera refs
	_coop_cameras = get_tree().get_nodes_in_group("coop_camera")
	if is_local_controlled():
		for cam in _coop_cameras:
			cam.register_target(self)
	_hud = get_tree().get_first_node_in_group("hud")

	_whip_ray_query = PhysicsRayQueryParameters3D.new()
	_whip_ray_query.collision_mask = 5 # Layer 1 (Environment) and Layer 3 (Interactables)
	_whip_ray_query.collide_with_areas = true
	_whip_ray_query.exclude = [self]

	# Interaction area setup
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)

	# Damage flash light
	hurt_light = OmniLight3D.new()
	hurt_light.light_color = Color(1.0, 0.15, 0.15)
	hurt_light.light_energy = 0.0
	hurt_light.omni_range = 3.2
	hurt_light.position = Vector3(0, 0.9, 0)
	add_child(hurt_light)

	# World-space interaction prompt
	prompt_label = Label3D.new()
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.no_depth_test = true
	prompt_label.font_size = 36
	prompt_label.outline_size = 8
	prompt_label.modulate = Color(1.0, 0.94, 0.72)
	prompt_label.visible = false
	add_child(prompt_label)

	# Co-op revive area (enabled only while downed)
	revive_area = Area3D.new()
	revive_area.collision_layer = 4
	revive_area.collision_mask = 0
	revive_area.monitoring = false
	revive_area.monitorable = false
	var rev_col := CollisionShape3D.new()
	var rev_sphere := SphereShape3D.new()
	rev_sphere.radius = 1.15
	rev_col.shape = rev_sphere
	rev_col.position = Vector3(0, 0.5, 0)
	revive_area.add_child(rev_col)
	add_child(revive_area)

	# Online player nametag
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		name_tag_label = Label3D.new()
		name_tag_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag_label.font_size = 28
		name_tag_label.outline_size = 8
		name_tag_label.position = Vector3(0, 1.92, 0)
		name_tag_label.modulate = GameManager.get_player_color(player_id).lightened(0.28)
		_refresh_online_nametag()
		add_child(name_tag_label)
		NetworkManager.lobby_updated.connect(_refresh_online_nametag)

func _refresh_online_nametag() -> void:
	if not is_instance_valid(name_tag_label) or not is_instance_valid(NetworkManager):
		return
	var pid := NetworkManager.get_peer_for_slot(player_id)
	name_tag_label.text = str(NetworkManager.peer_names.get(pid, "P%d" % player_id))

func is_local_controlled() -> bool:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_online:
		return true
	return NetworkManager.is_slot_local(player_id)

func _get_input_prefix() -> String:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		return "p1_"
	return "p%d_" % player_id

func _apply_player_identity() -> void:
	var idx = clampi(player_id - 1, 0, 3)

	# 1. Ring indicator glow
	if ring_indicator:
		var ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var p_color := GameManager.get_player_color(player_id)
		ring_mat.albedo_color = p_color
		ring_mat.emission_enabled = true
		ring_mat.emission = p_color
		ring_mat.emission_energy_multiplier = 1.4
		ring_indicator.material_override = ring_mat

	# 2. Jacket & Sleeves (PBR leather with subtle rim catchlight)
	var jacket_mat = StandardMaterial3D.new()
	jacket_mat.albedo_color = OUTFIT_JACKETS[idx]
	jacket_mat.roughness = 0.58
	jacket_mat.metallic = 0.06
	jacket_mat.rim_enabled = true
	jacket_mat.rim = 0.25
	jacket_mat.rim_tint = 0.4
	if body_mesh: body_mesh.material_override = jacket_mat
	if sleeve_l: sleeve_l.material_override = jacket_mat
	if sleeve_r: sleeve_r.material_override = jacket_mat

	# 3. Pants
	var pants_mat = StandardMaterial3D.new()
	pants_mat.albedo_color = OUTFIT_PANTS[idx]
	pants_mat.roughness = 0.88
	if pants_l: pants_l.material_override = pants_mat
	if pants_r: pants_r.material_override = pants_mat

	# 4. Hat
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = OUTFIT_HATS[idx]
	hat_mat.roughness = 0.68
	hat_mat.rim_enabled = true
	hat_mat.rim = 0.18
	if hat_brim: hat_brim.material_override = hat_mat
	if hat_crown: hat_crown.material_override = hat_mat

func _physics_process(delta: float) -> void:
	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta
	if _ping_cooldown > 0.0:
		_ping_cooldown -= delta
	if _haste_timer > 0.0:
		_haste_timer -= delta

	# Remote online player: smoothly interpolate replicated state and animate
	if not is_local_controlled():
		if _has_remote_state:
			if global_position.distance_to(_remote_target_pos) > 4.5:
				global_position = _remote_target_pos
			else:
				global_position = global_position.lerp(_remote_target_pos, minf(1.0, 18.0 * delta))
			velocity = _remote_target_vel
			if current_health > 0:
				mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, _remote_target_yaw, 16.0 * delta)
		_update_animation(delta)
		prompt_label.visible = false
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0

	if current_health <= 0:
		var downed_prefix := _get_input_prefix()
		if InputMap.has_action(downed_prefix + "ping") and Input.is_action_just_pressed(downed_prefix + "ping"):
			trigger_coop_ping()
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		move_and_slide()
		_broadcast_local_motion(delta)
		return

	# Chasm fall safety: damage 1 HP and return to latest checkpoint
	if global_position.y < -5.5:
		if not is_instance_valid(NetworkManager) or not NetworkManager.is_online or NetworkManager.is_host:
			take_damage(1)
		else:
			_rpc_request_chasm_damage.rpc_id(1)
		if current_health > 0:
			velocity = Vector3.ZERO
			var respawn_pos := Vector3(0.0, 0.4, 4.0)
			var parent_lvl := get_parent()
			if is_instance_valid(parent_lvl) and "latest_checkpoint_pos" in parent_lvl:
				respawn_pos = parent_lvl.latest_checkpoint_pos + Vector3(0.0, 0.3, 0.0)
			global_position = respawn_pos
		return

	if is_dashing:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * 11.5
		velocity.z = _dash_dir.z * 11.5
		if _dash_timer <= 0.0:
			is_dashing = false
	else:
		_handle_movement(delta)

	_handle_input()
	move_and_slide()
	_handle_push_collisions()
	_update_animation(delta)
	_update_interact_prompt()
	_broadcast_local_motion(delta)

func _broadcast_local_motion(delta: float) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_online:
		return
	_net_sync_timer += delta
	if _net_sync_timer >= 0.033:
		_net_sync_timer = 0.0
		_rpc_sync_motion.rpc(global_position, velocity, mesh_root.rotation.y)

@rpc("any_peer", "unreliable_ordered")
func _rpc_sync_motion(pos: Vector3, vel: Vector3, yaw: float) -> void:
	if is_local_controlled():
		return
	_remote_target_pos = pos
	_remote_target_vel = vel
	_remote_target_yaw = yaw
	_has_remote_state = true

@rpc("any_peer", "reliable")
func _rpc_request_chasm_damage() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_host:
		take_damage(1)

func _handle_push_collisions() -> void:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is PushableBlock or (collider and collider.is_in_group("pushable")):
			var push_dir = -col.get_normal()
			push_dir.y = 0.0
			if push_dir.length_squared() > 0.01:
				collider.push(push_dir.normalized(), speed * 0.75)

func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	var prefix = _get_input_prefix()

	if InputMap.has_action(prefix + "up"):
		input_dir.y -= Input.get_action_strength(prefix + "up")
	if InputMap.has_action(prefix + "down"):
		input_dir.y += Input.get_action_strength(prefix + "down")
	if InputMap.has_action(prefix + "left"):
		input_dir.x -= Input.get_action_strength(prefix + "left")
	if InputMap.has_action(prefix + "right"):
		input_dir.x += Input.get_action_strength(prefix + "right")

	input_dir = input_dir.limit_length(1.0)

	# Convert 2D input to Isometric 3D world direction relative to active camera
	var cam = get_viewport().get_camera_3d()
	var cam_forward = Vector3(-1, 0, -1).normalized()
	var cam_right   = Vector3(1, 0, -1).normalized()
	if cam:
		var cam_basis = cam.global_transform.basis
		var fwd = -cam_basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.01:
			cam_forward = fwd.normalized()
		var rgt = cam_basis.x
		rgt.y = 0.0
		if rgt.length_squared() > 0.01:
			cam_right = rgt.normalized()

	var move_dir = (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()

	if move_dir.length() > 0.05:
		var active_speed := speed * (1.24 if _haste_timer > 0.0 else 1.0)
		velocity.x = move_toward(velocity.x, move_dir.x * active_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * active_speed, acceleration * delta)

		# Rotate character towards movement direction smoothly
		var target_rotation_y = atan2(move_dir.x, move_dir.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation_y, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

func _update_animation(delta: float) -> void:
	if is_staggering or current_health <= 0:
		return

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var is_moving = horizontal_speed > 0.2 and (is_on_floor() or not is_local_controlled())

	if is_moving:
		# Walking cycle: frequency proportional to speed
		var stride_frequency = 2.4 * (horizontal_speed / speed)
		walk_cycle += delta * stride_frequency * TAU

		# Synced stone footstep SFX each half-stride
		var half_cycle := int(floor(walk_cycle / PI))
		if half_cycle != _last_step_half_cycle:
			_last_step_half_cycle = half_cycle
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx_3d(&"footstep", global_position, 0.88, 1.12, -10.0, 16.0, 3.0)

		# 1. Legs swing back and forth
		var leg_swing = sin(walk_cycle) * 0.75
		leg_l.rotation.x = leg_swing
		leg_r.rotation.x = -leg_swing

		# 2. Foot lift: slight elevation during forward step
		leg_l.position.y = leg_base_l_y + max(0.0, sin(walk_cycle)) * 0.07
		leg_r.position.y = leg_base_r_y + max(0.0, -sin(walk_cycle)) * 0.07

		# 3. Torso bobbing (drops and rises with each step)
		torso.position.y = torso_base_y + abs(sin(walk_cycle)) * 0.05

		# 4. Torso weight transfer / hip sway
		torso.rotation.z = lerp_angle(torso.rotation.z, cos(walk_cycle) * 0.06, 12.0 * delta)
		torso.rotation.y = lerp_angle(torso.rotation.y, -sin(walk_cycle) * 0.08, 12.0 * delta)

		# 5. Head subtle counter-tilt
		head.rotation.z = -cos(walk_cycle) * 0.03

		# 6. Arms swing (unless carrying or whipping)
		if not is_whipping:
			if carried_item != null or is_instance_valid(grabbed_block):
				# Carrying an object with both hands forward
				arm_l.rotation.x = lerp_angle(arm_l.rotation.x, deg_to_rad(-65.0), 12.0 * delta)
				arm_r.rotation.x = lerp_angle(arm_r.rotation.x, deg_to_rad(-65.0), 12.0 * delta)
				arm_l.rotation.y = lerp_angle(arm_l.rotation.y, deg_to_rad(15.0), 12.0 * delta)
				arm_r.rotation.y = lerp_angle(arm_r.rotation.y, deg_to_rad(-15.0), 12.0 * delta)
				arm_l.rotation.z = lerp_angle(arm_l.rotation.z, 0.0, 12.0 * delta)
				arm_r.rotation.z = lerp_angle(arm_r.rotation.z, 0.0, 12.0 * delta)
			else:
				# Natural opposing arm swing
				var arm_swing = sin(walk_cycle) * 0.7
				arm_l.rotation.x = -arm_swing
				arm_r.rotation.x = arm_swing
				arm_l.rotation.y = 0.0
				arm_r.rotation.y = 0.0
				arm_l.rotation.z = deg_to_rad(-8.0) + cos(walk_cycle) * 0.04
				arm_r.rotation.z = deg_to_rad(8.0) - cos(walk_cycle) * 0.04
	else:
		# Idle cycle (calm breathing)
		idle_cycle += delta * 2.5
		walk_cycle = 0.0
		_last_step_half_cycle = 0

		# Return legs to resting standing stance
		leg_l.rotation.x = lerp_angle(leg_l.rotation.x, 0.0, 12.0 * delta)
		leg_r.rotation.x = lerp_angle(leg_r.rotation.x, 0.0, 12.0 * delta)
		leg_l.position.y = lerpf(leg_l.position.y, leg_base_l_y, 12.0 * delta)
		leg_r.position.y = lerpf(leg_r.position.y, leg_base_r_y, 12.0 * delta)

		# Gentle breathing bob
		torso.position.y = lerpf(torso.position.y, torso_base_y + sin(idle_cycle) * 0.015, 8.0 * delta)
		torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, 10.0 * delta)
		torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, 10.0 * delta)
		head.rotation.z = lerp_angle(head.rotation.z, 0.0, 10.0 * delta)

		if not is_whipping:
			if carried_item != null or is_instance_valid(grabbed_block):
				arm_l.rotation.x = lerp_angle(arm_l.rotation.x, deg_to_rad(-65.0), 12.0 * delta)
				arm_r.rotation.x = lerp_angle(arm_r.rotation.x, deg_to_rad(-65.0), 12.0 * delta)
				arm_l.rotation.y = lerp_angle(arm_l.rotation.y, deg_to_rad(15.0), 12.0 * delta)
				arm_r.rotation.y = lerp_angle(arm_r.rotation.y, deg_to_rad(-15.0), 12.0 * delta)
			else:
				# Relaxed arms at sides
				arm_l.rotation.x = lerp_angle(arm_l.rotation.x, 0.0, 10.0 * delta)
				arm_r.rotation.x = lerp_angle(arm_r.rotation.x, 0.0, 10.0 * delta)
				arm_l.rotation.y = lerp_angle(arm_l.rotation.y, 0.0, 10.0 * delta)
				arm_r.rotation.y = lerp_angle(arm_r.rotation.y, 0.0, 10.0 * delta)
				arm_l.rotation.z = lerp_angle(arm_l.rotation.z, deg_to_rad(-8.0) + sin(idle_cycle) * 0.02, 8.0 * delta)
				arm_r.rotation.z = lerp_angle(arm_r.rotation.z, deg_to_rad(8.0) - sin(idle_cycle) * 0.02, 8.0 * delta)

func _handle_input() -> void:
	var prefix = _get_input_prefix()
	if InputMap.has_action(prefix + "interact") and Input.is_action_just_pressed(prefix + "interact"):
		interact()
	if InputMap.has_action(prefix + "action") and Input.is_action_just_pressed(prefix + "action"):
		use_whip()
	if InputMap.has_action(prefix + "dash") and Input.is_action_just_pressed(prefix + "dash"):
		use_dash()
	if InputMap.has_action(prefix + "ping") and Input.is_action_just_pressed(prefix + "ping"):
		trigger_coop_ping()

func trigger_coop_ping() -> void:
	if _ping_cooldown > 0.0:
		return
	_ping_cooldown = 0.65

	var ping_pos := global_position
	var label_txt := "📍 P%d: Over Here!" % player_id
	var p_tag := "P%d" % player_id
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		var pid := NetworkManager.get_peer_for_slot(player_id)
		p_tag = str(NetworkManager.peer_names.get(pid, p_tag))

	if current_health <= 0:
		ping_pos = global_position + Vector3(0.0, 0.05, 0.0)
		label_txt = "🆘 %s: Revive Me!" % p_tag
	else:
		var forward_dir := Vector3(mesh_root.global_basis.z.x, 0.0, mesh_root.global_basis.z.z)
		if forward_dir.length_squared() < 0.001:
			forward_dir = Vector3.FORWARD
		forward_dir = forward_dir.normalized()

		var focus_target: Node3D = current_interactable
		if not is_instance_valid(focus_target):
			var space_state := get_world_3d().direct_space_state
			if space_state != null:
				var rq := PhysicsRayQueryParameters3D.create(
					global_position + Vector3(0.0, 0.85, 0.0),
					global_position + Vector3(0.0, 0.85, 0.0) + forward_dir * 6.5,
					5
				)
				rq.collide_with_areas = true
				rq.exclude = [get_rid()]
				var r_hit := space_state.intersect_ray(rq)
				if not r_hit.is_empty():
					var col_obj = r_hit.collider
					focus_target = col_obj.get_parent() if col_obj is Area3D else col_obj
					ping_pos = Vector3(r_hit.position.x, global_position.y, r_hit.position.z)
				else:
					ping_pos = global_position + forward_dir * 2.2
		else:
			ping_pos = focus_target.global_position

		if is_instance_valid(focus_target):
			if focus_target is Player and focus_target.current_health <= 0:
				label_txt = "🆘 %s: Revive Ally!" % p_tag
			elif focus_target is PressurePlate or focus_target.is_in_group("pressure_plate"):
				label_txt = "📍 %s: Stand on Seal!" % p_tag
			elif focus_target is WallLever:
				label_txt = "📍 %s: Pull Lever!" % p_tag
			elif focus_target is MirrorPillar:
				label_txt = "📍 %s: Rotate Mirror!" % p_tag
			elif focus_target is Brazier:
				label_txt = "🔥 %s: Light Brazier!" % p_tag
			elif focus_target is PushableBlock or focus_target.is_in_group("pushable"):
				label_txt = "🪨 %s: Move Block!" % p_tag
			elif focus_target.is_in_group("carryable"):
				label_txt = "✨ %s: Grab Relic!" % p_tag
			elif focus_target.has_method("get_interact_prompt"):
				var pr := str(focus_target.get_interact_prompt())
				label_txt = ("📍 %s: %s!" % [p_tag, pr]) if not pr.is_empty() else ("📍 %s: Look Here!" % p_tag)
			else:
				label_txt = "📍 %s: Over Here!" % p_tag
		else:
			label_txt = "📍 %s: Over Here!" % p_tag

	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		_rpc_spawn_ping.rpc(ping_pos, label_txt)
	else:
		_spawn_local_ping(ping_pos, label_txt)

@rpc("any_peer", "call_local", "reliable")
func _rpc_spawn_ping(world_pos: Vector3, label_txt: String) -> void:
	_spawn_local_ping(world_pos, label_txt)

func _spawn_local_ping(world_pos: Vector3, label_txt: String) -> void:
	if is_instance_valid(get_parent()):
		var col := Color(1.0, 0.30, 0.30) if current_health <= 0 else GameManager.get_player_color(player_id)
		COOP_PING_BEACON.spawn(get_parent(), world_pos, col, label_txt)

func grant_speed_boost(duration: float = 4.0) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_haste.rpc(duration)
	_apply_speed_boost(duration)

@rpc("authority", "reliable")
func _rpc_sync_haste(duration: float) -> void:
	_apply_speed_boost(duration)

func _apply_speed_boost(duration: float) -> void:
	_haste_timer = maxf(_haste_timer, duration)
	if is_instance_valid(hurt_light):
		hurt_light.light_color = Color(1.0, 0.88, 0.25)
		hurt_light.light_energy = 2.6
		var tw := create_tween()
		tw.tween_property(hurt_light, "light_energy", 0.0, 0.45)
		tw.chain().tween_callback(func():
			if is_instance_valid(hurt_light):
				hurt_light.light_color = Color(1.0, 0.15, 0.15)
		)

func use_dash() -> void:
	if is_dashing or is_staggering or _dash_cooldown > 0.0 or current_health <= 0:
		return
	var forward_dir := Vector3(mesh_root.global_basis.z.x, 0.0, mesh_root.global_basis.z.z)
	if forward_dir.length_squared() < 0.001:
		forward_dir = Vector3.FORWARD
	_dash_dir = forward_dir.normalized()
	_play_dash_fx()
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		_rpc_remote_dash.rpc(_dash_dir)

func _play_dash_fx() -> void:
	is_dashing = true
	_dash_timer = 0.18
	_dash_cooldown = 0.65
	if is_instance_valid(get_parent()):
		DUST_PUFF.spawn(get_parent(), global_position, 4, 0.9)
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"footstep", global_position, 1.15, 1.30, -4.0, 18.0, 4.0)
	var roll_tw := create_tween()
	roll_tw.tween_property(torso, "rotation:x", deg_to_rad(32.0), 0.08)
	roll_tw.tween_property(torso, "rotation:x", 0.0, 0.12)

@rpc("any_peer", "reliable")
func _rpc_remote_dash(dir: Vector3) -> void:
	if is_local_controlled():
		return
	_dash_dir = dir
	_play_dash_fx()

func use_whip() -> void:
	if is_whipping:
		return

	var start_pt = global_position + Vector3(0, 0.95, 0)
	var forward_dir = mesh_root.global_transform.basis.z.normalized()
	var max_reach: float = 4.5
	var target_pt = start_pt + forward_dir * max_reach

	var space_state = get_world_3d().direct_space_state
	_whip_ray_query.from = start_pt
	_whip_ray_query.to = target_pt

	var result = space_state.intersect_ray(_whip_ray_query)
	var hit_surface := false
	if result:
		hit_surface = true
		target_pt = result.position
		var hit_collider = result.collider
		var target_obj = hit_collider.get_parent() if hit_collider is Area3D else hit_collider

		if target_obj.has_method("on_whipped"):
			target_obj.on_whipped(self)
		elif target_obj.has_method("interact") and not (target_obj is PushableBlock or target_obj.is_in_group("pushable")):
			target_obj.interact(self)

	_play_whip_visuals(start_pt, target_pt, hit_surface)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		_rpc_remote_whip.rpc(start_pt, target_pt, hit_surface)

func _play_whip_visuals(start_pt: Vector3, target_pt: Vector3, hit_surface: bool = false) -> void:
	is_whipping = true
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"whip_crack", global_position, 0.94, 1.08, -2.0, 22.0, 5.0)
	var tween = create_tween()
	tween.tween_property(arm_r, "rotation:x", deg_to_rad(-105.0), 0.08)
	tween.tween_property(arm_r, "rotation:x", deg_to_rad(0.0), 0.16)
	tween.finished.connect(func(): is_whipping = false)

	var whip = WHIP_SCENE.instantiate() as WhipEffect
	get_parent().add_child(whip)
	whip.lash(start_pt, target_pt, 0.22)
	if hit_surface and is_instance_valid(get_parent()):
		_spawn_whip_sparks(get_parent(), target_pt)

func _spawn_whip_sparks(parent_node: Node, impact_pos: Vector3) -> void:
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.albedo_color = Color(1.0, 0.85, 0.35, 0.95)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.05, 0.05, 0.05)
	spark_mesh.material = spark_mat
	for i in range(5):
		var sp := MeshInstance3D.new()
		sp.mesh = spark_mesh
		parent_node.add_child(sp)
		sp.global_position = impact_pos
		var vel := Vector3(randf_range(-1.2, 1.2), randf_range(0.5, 1.4), randf_range(-1.2, 1.2))
		var tw := sp.create_tween().set_parallel(true)
		tw.tween_property(sp, "global_position", impact_pos + vel * 0.28, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.20)
		tw.chain().tween_callback(sp.queue_free)

@rpc("any_peer", "reliable")
func _rpc_remote_whip(start_pt: Vector3, target_pt: Vector3, hit_surface: bool = false) -> void:
	if is_local_controlled():
		return
	_play_whip_visuals(start_pt, target_pt, hit_surface)

func _can_interact_while_carrying(target: Node3D) -> bool:
	if not is_instance_valid(target) or target == carried_item:
		return false
	if target is Player:
		return target != self and target.current_health <= 0
	if target.is_in_group("carryable") or target is PushableBlock or target.is_in_group("pushable"):
		return false
	if target is Brazier and target.is_lit:
		return false
	return target.has_method("interact")

func get_interact_prompt() -> String:
	return "Revive Ally" if current_health <= 0 else ""

func on_whipped(by_player: Player) -> void:
	if current_health <= 0 and is_instance_valid(by_player) and by_player != self and by_player.current_health > 0:
		revive_in_place()

func interact(by_player: Player = null) -> void:
	if by_player != null and by_player != self:
		if current_health <= 0 and by_player.current_health > 0:
			revive_in_place()
		return

	# If carrying something (e.g., Torch), prioritize lighting an unlit Brazier or operating a switch
	if carried_item != null:
		if _can_interact_while_carrying(current_interactable):
			current_interactable.interact(self)
			interacted.emit()
			return
		drop_item()
		return

	# If grabbing a pushable block, release it
	if is_instance_valid(grabbed_block):
		grabbed_block.release()
		return

	# Otherwise, interact with nearby object
	if is_instance_valid(current_interactable):
		if current_interactable.is_in_group("carryable"):
			pick_up_item(current_interactable)
		elif current_interactable.has_method("interact"):
			current_interactable.interact(self)
		interacted.emit()

func pick_up_item(item: Node3D) -> void:
	if not is_instance_valid(item):
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		if not NetworkManager.is_host:
			_rpc_request_pickup.rpc_id(1, get_tree().current_scene.get_path_to(item))
			return
		_rpc_sync_pickup.rpc(get_tree().current_scene.get_path_to(item))
	_do_pick_up_item(item)

func _do_pick_up_item(item: Node3D) -> void:
	if not is_instance_valid(item) or carried_item != null:
		return
	carried_item = item
	if item.has_method("on_picked_up"):
		item.on_picked_up(self)
	item.reparent(carry_slot)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO

@rpc("any_peer", "reliable")
func _rpc_request_pickup(rel_item_path: NodePath) -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_host:
		return
	var item := get_tree().current_scene.get_node_or_null(rel_item_path) as Node3D
	if is_instance_valid(item) and carried_item == null:
		pick_up_item(item)

@rpc("authority", "reliable")
func _rpc_sync_pickup(rel_item_path: NodePath) -> void:
	var item := get_tree().current_scene.get_node_or_null(rel_item_path) as Node3D
	if is_instance_valid(item):
		_do_pick_up_item(item)

func drop_item() -> void:
	if carried_item == null:
		return
	var drop_pos := _find_safe_drop_position()
	if is_instance_valid(NetworkManager) and NetworkManager.is_online:
		if not NetworkManager.is_host:
			_rpc_request_drop.rpc_id(1, drop_pos)
			return
		_rpc_sync_drop.rpc(drop_pos)
	_do_drop_item(drop_pos)

func _do_drop_item(drop_pos: Vector3) -> void:
	if carried_item == null:
		return
	var item = carried_item
	carried_item = null
	item.reparent(get_parent())
	item.global_position = drop_pos
	if item.has_method("on_dropped"):
		item.on_dropped(self)

@rpc("any_peer", "reliable")
func _rpc_request_drop(drop_pos: Vector3) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_host and carried_item != null:
		_rpc_sync_drop.rpc(drop_pos)
		_do_drop_item(drop_pos)

@rpc("authority", "reliable")
func _rpc_sync_drop(drop_pos: Vector3) -> void:
	_do_drop_item(drop_pos)

func _find_safe_drop_position() -> Vector3:
	var forward := Vector3(mesh_root.global_basis.z.x, 0.0, mesh_root.global_basis.z.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3.BACK
	else:
		forward = forward.normalized()

	var drop_distance := 1.2
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return global_position + forward * drop_distance

	var shape := SphereShape3D.new()
	shape.radius = 0.25

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.5, 0.0))
	query.motion = forward * drop_distance
	query.collision_mask = 1 # World / walls / pillars / solid obstacles
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var result := space_state.cast_motion(query)
	if result.is_empty():
		return global_position

	var safe_dist := result[0] * drop_distance
	if safe_dist < 0.2:
		return global_position
	var candidate := global_position + forward * safe_dist

	# Verify solid floor beneath drop position so items aren't dropped into chasm pits
	var floor_ray := PhysicsRayQueryParameters3D.create(
		candidate + Vector3(0.0, 0.6, 0.0),
		candidate + Vector3(0.0, -1.8, 0.0),
		1
	)
	floor_ray.exclude = [get_rid()]
	if space_state.intersect_ray(floor_ray).is_empty():
		return global_position

	return candidate

func heal(amount: int = 1) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	if current_health <= 0 or current_health >= max_health:
		return
	var next_h := mini(max_health, current_health + amount)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_health_event.rpc(next_h, 1, global_position)
	_apply_heal(next_h)

func _apply_heal(next_h: int) -> void:
	current_health = next_h
	health_changed.emit(current_health)
	if is_instance_valid(hurt_light):
		hurt_light.light_color = Color(0.25, 1.0, 0.45)
		hurt_light.light_energy = 2.8
		var tw := create_tween()
		tw.tween_property(hurt_light, "light_energy", 0.0, 0.4)
		tw.chain().tween_callback(func():
			if is_instance_valid(hurt_light):
				hurt_light.light_color = Color(1.0, 0.15, 0.15)
		)

func take_damage(amount: int = 1) -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	if is_invulnerable or is_dashing or current_health <= 0:
		return
	var next_h := maxi(0, current_health - amount)
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_health_event.rpc(next_h, 0, global_position)
	_apply_damage_to(next_h)

func _apply_damage_to(next_h: int) -> void:
	current_health = next_h
	health_changed.emit(current_health)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"player_hurt", global_position, 0.94, 1.06, 0.0, 25.0, 5.5)

	if is_local_controlled():
		if is_instance_valid(SettingsManager) and SettingsManager.controller_rumble:
			Input.start_joy_vibration(0 if (is_instance_valid(NetworkManager) and NetworkManager.is_online) else (player_id - 1), 0.4, 0.7, 0.22)
		if is_instance_valid(_hud) and _hud.has_method("flash_damage_vignette"):
			_hud.flash_damage_vignette()
		for cam in _coop_cameras:
			if is_instance_valid(cam) and cam.has_method("trigger_shake"):
				cam.trigger_shake(0.12, 0.14)

	if current_health <= 0:
		current_health = 0
		_die()
		return

	if not (is_instance_valid(NetworkManager) and NetworkManager.is_online):
		Engine.time_scale = 0.25
		get_tree().create_timer(0.04, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
		)

	# Start stagger & invulnerability
	is_invulnerable = true
	is_staggering = true

	# 1. Flash red light
	if is_instance_valid(hurt_light):
		hurt_light.light_energy = 3.5
		var light_tween = create_tween()
		light_tween.tween_property(hurt_light, "light_energy", 0.0, 0.3)

	# 2. Dramatic stagger / flinch animation
	var stagger_tween = create_tween().set_parallel(true)
	stagger_tween.tween_property(torso, "rotation:x", deg_to_rad(-24.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stagger_tween.tween_property(head, "rotation:x", deg_to_rad(30.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stagger_tween.tween_property(arm_l, "rotation:x", deg_to_rad(-45.0), 0.1)
	stagger_tween.tween_property(arm_r, "rotation:x", deg_to_rad(-45.0), 0.1)
	stagger_tween.tween_property(mesh_root, "position:y", 0.18, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stagger_tween.tween_property(mesh_root, "scale", Vector3(1.15, 0.88, 1.15), 0.08)

	# Return to normal stance
	stagger_tween.chain().tween_property(torso, "rotation:x", 0.0, 0.22)
	stagger_tween.tween_property(head, "rotation:x", 0.0, 0.22)
	stagger_tween.tween_property(mesh_root, "position:y", 0.0, 0.22)
	stagger_tween.tween_property(mesh_root, "scale", Vector3.ONE, 0.22)

	# Brief knockback impulse away from facing
	velocity += -mesh_root.global_transform.basis.z * 3.5 + Vector3.UP * 1.5

	# End stagger after 0.32s
	get_tree().create_timer(0.32).timeout.connect(func():
		is_staggering = false
	)

	# 3. Invulnerability blinking / flickering for 1.0s
	var flicker_tween = create_tween().set_loops(6)
	flicker_tween.tween_property(mesh_root, "visible", false, 0.08)
	flicker_tween.tween_property(mesh_root, "visible", true, 0.08)

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	mesh_root.visible = true
	is_invulnerable = false

func _die() -> void:
	drop_item()
	if is_instance_valid(grabbed_block):
		grabbed_block.release()
	is_invulnerable = true
	is_staggering = true
	is_dashing = false
	if is_instance_valid(revive_area):
		revive_area.set_deferred("monitorable", true)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"player_death", global_position, 0.95, 1.05, 0.0, 30.0, 7.0)

	if is_instance_valid(hurt_light):
		hurt_light.light_energy = 5.0
		var light_tween = create_tween()
		light_tween.tween_property(hurt_light, "light_energy", 0.0, 0.5)

	# Dramatic fall over animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh_root, "rotation:z", deg_to_rad(85.0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_root, "position:y", 0.12, 0.35)
	player_died.emit(self)

func revive_in_place() -> void:
	if current_health > 0:
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		_rpc_request_revive.rpc_id(1)
		return
	respawn_at(global_position + Vector3(0.0, 0.1, 0.0))
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"scarab_pickup", global_position, 0.90, 0.96, -3.0, 22.0, 5.0)
	if is_instance_valid(hurt_light):
		hurt_light.light_color = Color(0.25, 1.0, 0.50)
		hurt_light.light_energy = 3.5
		var tw := create_tween()
		tw.tween_property(hurt_light, "light_energy", 0.0, 0.45)
		tw.chain().tween_callback(func():
			if is_instance_valid(hurt_light):
				hurt_light.light_color = Color(1.0, 0.15, 0.15)
		)

@rpc("any_peer", "reliable")
func _rpc_request_revive() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_host and current_health <= 0:
		revive_in_place()

@rpc("authority", "reliable")
func _rpc_sync_health_event(next_h: int, kind: int, pos: Vector3) -> void:
	if kind == 0:
		_apply_damage_to(next_h)
	elif kind == 1:
		_apply_heal(next_h)
	elif kind == 2:
		_do_respawn_at(pos)

func respawn_at(pos: Vector3) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_health_event.rpc(maxi(1, max_health - 1), 2, pos)
	_do_respawn_at(pos)

func _do_respawn_at(pos: Vector3) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if is_instance_valid(revive_area):
		revive_area.set_deferred("monitorable", false)
	current_health = maxi(1, max_health - 1)
	health_changed.emit(current_health)
	is_staggering = false
	is_whipping = false
	is_invulnerable = true
	velocity = Vector3.ZERO
	global_position = pos
	mesh_root.rotation = Vector3.ZERO
	mesh_root.position = Vector3.ZERO
	mesh_root.scale = Vector3.ONE
	mesh_root.visible = true

	var flicker := create_tween().set_loops(8)
	flicker.tween_property(mesh_root, "visible", false, 0.09)
	flicker.tween_property(mesh_root, "visible", true, 0.09)

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	mesh_root.visible = true
	is_invulnerable = false

func _update_interact_prompt() -> void:
	if not is_instance_valid(prompt_label):
		return

	if current_health <= 0 or (is_instance_valid(SettingsManager) and not SettingsManager.show_interact_prompts):
		prompt_label.visible = false
		return

	if carried_item != null and not _can_interact_while_carrying(current_interactable):
		prompt_label.visible = false
		return

	var target: Node3D = null
	if carried_item == null and is_instance_valid(grabbed_block):
		target = grabbed_block
	elif is_instance_valid(current_interactable):
		target = current_interactable

	if target == null:
		prompt_label.visible = false
		return

	var action_text := ""
	if target.has_method("get_interact_prompt_for"):
		action_text = target.get_interact_prompt_for(self)
	elif target.has_method("get_interact_prompt"):
		action_text = target.get_interact_prompt()
	elif target.is_in_group("carryable"):
		action_text = "Pick Up"
	else:
		action_text = "Interact"

	if action_text.is_empty():
		prompt_label.visible = false
		_last_prompt_target = null
		_last_prompt_text = ""
		return

	if target != _last_prompt_target or action_text != _last_prompt_text:
		_last_prompt_target = target
		_last_prompt_text = action_text
		var online_mode := is_instance_valid(NetworkManager) and NetworkManager.is_online
		var key_hint := "[E]" if (player_id == 1 or online_mode) else ("[Enter]" if player_id == 2 else "(A)")
		prompt_label.text = "%s %s" % [key_hint, action_text]

	prompt_label.global_position = target.global_position + Vector3(0, 1.65, 0)
	prompt_label.visible = true

func _on_interaction_area_entered(area: Area3D) -> void:
	var target = area.get_parent()
	if target == self:
		return
	if target is Player:
		if target.current_health <= 0:
			current_interactable = target
		return
	if target and (target.has_method("interact") or target.is_in_group("carryable")):
		current_interactable = target

func _on_interaction_area_exited(area: Area3D) -> void:
	var target = area.get_parent()
	if current_interactable == target:
		current_interactable = null
