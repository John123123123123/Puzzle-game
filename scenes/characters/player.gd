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
var current_interactable: Node3D = null
var is_invulnerable: bool = false
var is_whipping: bool = false
var is_staggering: bool = false

var hurt_audio: AudioStreamPlayer3D = null
var death_audio: AudioStreamPlayer3D = null
var hurt_light: OmniLight3D = null

# Player ring indicator colors
const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2), # P1: Red
	Color(0.2, 0.5, 0.9),  # P2: Blue
	Color(0.2, 0.75, 0.3), # P3: Green
	Color(0.9, 0.75, 0.15) # P4: Gold
]

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

	# Register with coop camera
	var cameras = get_tree().get_nodes_in_group("coop_camera")
	for cam in cameras:
		cam.register_target(self)

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

	# Damage hurt sound
	hurt_audio = AudioStreamPlayer3D.new()
	hurt_audio.stream = _create_hurt_sound()
	hurt_audio.unit_size = 5.5
	hurt_audio.max_distance = 25.0
	add_child(hurt_audio)

	# Death sound
	death_audio = AudioStreamPlayer3D.new()
	death_audio.stream = _create_death_sound()
	death_audio.unit_size = 7.0
	death_audio.max_distance = 30.0
	add_child(death_audio)

func _apply_player_identity() -> void:
	var idx = clampi(player_id - 1, 0, 3)

	# 1. Ring indicator glow
	if ring_indicator:
		var ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.albedo_color = PLAYER_COLORS[idx]
		ring_indicator.material_override = ring_mat

	# 2. Jacket & Sleeves
	var jacket_mat = StandardMaterial3D.new()
	jacket_mat.albedo_color = OUTFIT_JACKETS[idx]
	jacket_mat.roughness = 0.75
	if body_mesh: body_mesh.material_override = jacket_mat
	if sleeve_l: sleeve_l.material_override = jacket_mat
	if sleeve_r: sleeve_r.material_override = jacket_mat

	# 3. Pants
	var pants_mat = StandardMaterial3D.new()
	pants_mat.albedo_color = OUTFIT_PANTS[idx]
	pants_mat.roughness = 0.85
	if pants_l: pants_l.material_override = pants_mat
	if pants_r: pants_r.material_override = pants_mat

	# 4. Hat
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = OUTFIT_HATS[idx]
	hat_mat.roughness = 0.8
	if hat_brim: hat_brim.material_override = hat_mat
	if hat_crown: hat_crown.material_override = hat_mat

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0

	if current_health <= 0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		move_and_slide()
		return

	_handle_movement(delta)
	_handle_input()
	move_and_slide()
	_handle_push_collisions()
	_update_animation(delta)

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
	var prefix = "p%d_" % player_id

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
		velocity.x = move_toward(velocity.x, move_dir.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, acceleration * delta)

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
	var is_moving = horizontal_speed > 0.2 and is_on_floor()

	if is_moving:
		# Walking cycle: frequency proportional to speed
		var stride_frequency = 2.4 * (horizontal_speed / speed)
		walk_cycle += delta * stride_frequency * TAU

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
			if carried_item != null:
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
			if carried_item != null:
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
	var prefix = "p%d_" % player_id
	if InputMap.has_action(prefix + "interact") and Input.is_action_just_pressed(prefix + "interact"):
		interact()
	if InputMap.has_action(prefix + "action") and Input.is_action_just_pressed(prefix + "action"):
		use_whip()

func use_whip() -> void:
	if is_whipping:
		return

	is_whipping = true
	# Whip arm animation: snap right arm forward
	var tween = create_tween()
	tween.tween_property(arm_r, "rotation:x", deg_to_rad(-105.0), 0.08)
	tween.tween_property(arm_r, "rotation:x", deg_to_rad(0.0), 0.16)
	tween.finished.connect(func(): is_whipping = false)

	# Spawn whip lash effect
	var whip_scene = preload("res://scenes/characters/whip_effect.tscn")
	var whip = whip_scene.instantiate() as WhipEffect
	get_parent().add_child(whip)

	var start_pt = global_position + Vector3(0, 0.95, 0)
	var forward_dir = mesh_root.global_transform.basis.z.normalized()
	var max_reach: float = 4.5
	var target_pt = start_pt + forward_dir * max_reach

	# Perform 3D raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_pt, target_pt)
	query.collision_mask = 5 # Layer 1 (Environment) and Layer 3 (Interactables)
	query.collide_with_areas = true
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	if result:
		target_pt = result.position
		var hit_collider = result.collider
		var target_obj = hit_collider.get_parent() if hit_collider is Area3D else hit_collider

		if target_obj.has_method("on_whipped"):
			target_obj.on_whipped(self)
		elif target_obj.has_method("interact"):
			target_obj.interact(self)

	whip.lash(start_pt, target_pt, 0.22)

func interact() -> void:
	# If carrying something, drop or place it
	if carried_item != null:
		drop_item()
		return

	# Otherwise, interact with nearby object
	if is_instance_valid(current_interactable):
		if current_interactable.has_method("interact"):
			current_interactable.interact(self)
		elif current_interactable.is_in_group("carryable"):
			pick_up_item(current_interactable)
		interacted.emit()

func pick_up_item(item: Node3D) -> void:
	carried_item = item
	if item.has_method("on_picked_up"):
		item.on_picked_up(self)
	item.reparent(carry_slot)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO

func drop_item() -> void:
	if carried_item == null:
		return
	var item = carried_item
	carried_item = null
	item.reparent(get_parent())
	item.global_position = global_position + mesh_root.basis.z * 1.2 + Vector3.UP * 0.2
	if item.has_method("on_dropped"):
		item.on_dropped(self)

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or current_health <= 0:
		return
	current_health -= amount
	health_changed.emit(current_health)

	if is_instance_valid(hurt_audio):
		hurt_audio.pitch_scale = randf_range(0.94, 1.06)
		hurt_audio.play()

	if current_health <= 0:
		current_health = 0
		_die()
		return

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
	velocity += -transform.basis.z * 3.5 + Vector3.UP * 1.5

	# End stagger after 0.32s
	get_tree().create_timer(0.32).timeout.connect(func():
		is_staggering = false
	)

	# 3. Invulnerability blinking / flickering for 1.0s
	var flicker_tween = create_tween().set_loops(6)
	flicker_tween.tween_property(mesh_root, "visible", false, 0.08)
	flicker_tween.tween_property(mesh_root, "visible", true, 0.08)

	await get_tree().create_timer(1.0).timeout
	mesh_root.visible = true
	is_invulnerable = false

func _die() -> void:
	drop_item()
	is_invulnerable = true
	is_staggering = true

	if is_instance_valid(death_audio):
		death_audio.pitch_scale = randf_range(0.95, 1.05)
		death_audio.play()

	if is_instance_valid(hurt_light):
		hurt_light.light_energy = 5.0
		var light_tween = create_tween()
		light_tween.tween_property(hurt_light, "light_energy", 0.0, 0.5)

	# Dramatic fall over animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh_root, "rotation:z", deg_to_rad(85.0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_root, "position:y", 0.12, 0.35)
	player_died.emit(self)

func _create_hurt_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.25
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Flesh / leather impact thud + sharp pain transient + vocal groan
		var thud = sin(t * 115.0 * TAU) * exp(-t * 16.0)
		var punch = (sin(t * 1800.0 * TAU) if t < 0.02 else 0.0) * 0.5
		var pitch = 380.0 - t * 450.0
		var vocal = sin(t * pitch * TAU + sin(t * 65.0 * TAU) * 1.5) * exp(-t * 10.0) * 0.6
		var sample = clampf((thud * 0.5 + punch + vocal) * 0.9, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.7 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _create_death_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.55
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		# Heavy collapse groan + decaying sigh
		var pitch = 280.0 - t * 240.0
		var groan = sin(t * pitch * TAU + sin(t * 40.0 * TAU) * 2.0) * exp(-t * 5.0) * 0.6
		var thud = sin(t * 65.0 * TAU) * exp(-t * 8.0) * 0.4
		var sample = clampf(groan + thud, -1.0, 1.0)
		data[i] = int(clampi(int((sample * 0.7 + 0.5) * 255.0), 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _on_interaction_area_entered(area: Area3D) -> void:
	var target = area.get_parent()
	if target and (target.has_method("interact") or target.is_in_group("carryable")):
		current_interactable = target

func _on_interaction_area_exited(area: Area3D) -> void:
	var target = area.get_parent()
	if current_interactable == target:
		current_interactable = null
