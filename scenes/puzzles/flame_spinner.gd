extends StaticBody3D
class_name FlameSpinner

@export var spin_speed: float = 1.15
@export var rotation_speed: float = 0.0
@export var beam_length: float = 3.1
@export var dual_sided: bool = true
@export var four_way_in_coop: bool = true
@export var min_players: int = 1
@export var damage: int = 1

@onready var spinner_head: Node3D = $SpinnerHead
@onready var core_light: OmniLight3D = get_node_or_null("SpinnerHead/CoreLight")
@onready var arm_a: Node3D = $SpinnerHead/FlameArmA
@onready var arm_b: Node3D = $SpinnerHead/FlameArmB
@onready var area_a: Area3D = $SpinnerHead/FlameArmA/DamageArea
@onready var area_b: Area3D = $SpinnerHead/FlameArmB/DamageArea

var arm_c: Node3D = null
var arm_d: Node3D = null
var area_c: Area3D = null
var area_d: Area3D = null

var _base_speed: float = 1.15
var _effective_speed: float = 1.15
var _quad_active: bool = false
var _coop_enabled: bool = true
var _pulse_t: float = 0.0

func _ready() -> void:
	add_to_group("flame_spinner")
	_base_speed = rotation_speed if absf(rotation_speed) > 0.001 else spin_speed
	_effective_speed = _base_speed

	var len_scale := clampf(beam_length / 3.1, 0.5, 1.8)
	if is_instance_valid(arm_a):
		arm_a.scale.z = len_scale
	if is_instance_valid(arm_b):
		arm_b.scale.z = len_scale
		arm_b.visible = dual_sided
		if is_instance_valid(area_b):
			area_b.monitoring = dual_sided

	# Build perpendicular arms C & D for 3-4 player co-op escalation
	if is_instance_valid(arm_a) and is_instance_valid(spinner_head):
		arm_c = arm_a.duplicate() as Node3D
		arm_c.name = "FlameArmC"
		arm_c.rotation = Vector3(0.0, PI * 0.5, 0.0)
		arm_c.visible = false
		spinner_head.add_child(arm_c)
		area_c = arm_c.get_node_or_null("DamageArea") as Area3D
		if is_instance_valid(area_c):
			area_c.monitoring = false
			area_c.body_entered.connect(_on_flame_hit)

		arm_d = arm_a.duplicate() as Node3D
		arm_d.name = "FlameArmD"
		arm_d.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		arm_d.visible = false
		spinner_head.add_child(arm_d)
		area_d = arm_d.get_node_or_null("DamageArea") as Area3D
		if is_instance_valid(area_d):
			area_d.monitoring = false
			area_d.body_entered.connect(_on_flame_hit)

	if is_instance_valid(area_a):
		area_a.body_entered.connect(_on_flame_hit)
	if is_instance_valid(area_b):
		area_b.body_entered.connect(_on_flame_hit)

func apply_coop_difficulty(player_count: int) -> void:
	_coop_enabled = player_count >= min_players
	visible = _coop_enabled
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(col):
		col.set_deferred("disabled", not _coop_enabled)
	if not _coop_enabled:
		for ar in [area_a, area_b, area_c, area_d]:
			if is_instance_valid(ar):
				ar.set_deferred("monitoring", false)
		return

	var extra := maxi(0, player_count - 1)
	_effective_speed = _base_speed * (1.0 + 0.18 * float(extra))
	_quad_active = four_way_in_coop and player_count >= 3

	if is_instance_valid(area_a):
		area_a.set_deferred("monitoring", true)
	if is_instance_valid(arm_b):
		arm_b.visible = dual_sided
		if is_instance_valid(area_b):
			area_b.set_deferred("monitoring", dual_sided)
	if is_instance_valid(arm_c):
		arm_c.visible = _quad_active
		if is_instance_valid(area_c):
			area_c.set_deferred("monitoring", _quad_active)
	if is_instance_valid(arm_d):
		arm_d.visible = _quad_active
		if is_instance_valid(area_d):
			area_d.set_deferred("monitoring", _quad_active)

func _physics_process(delta: float) -> void:
	if not _coop_enabled:
		return
	_pulse_t += delta * 12.0
	if is_instance_valid(spinner_head):
		spinner_head.rotation.y += _effective_speed * delta
	if is_instance_valid(core_light):
		core_light.light_energy = 2.8 + sin(_pulse_t) * 0.32 + sin(_pulse_t * 2.1) * 0.14

	_check_area(area_a)
	if dual_sided:
		_check_area(area_b)
	if _quad_active:
		_check_area(area_c)
		_check_area(area_d)

func _check_area(area: Area3D) -> void:
	if not is_instance_valid(area) or not area.monitoring:
		return
	for body in area.get_overlapping_bodies():
		if body is Player:
			body.take_damage(damage)

func _on_flame_hit(body: Node3D) -> void:
	if _coop_enabled and body is Player:
		body.take_damage(damage)
