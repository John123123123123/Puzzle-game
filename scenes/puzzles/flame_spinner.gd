extends StaticBody3D
class_name FlameSpinner

@export var spin_speed: float = 1.15
@export var dual_sided: bool = true
@export var damage: int = 1

@onready var spinner_head: Node3D = $SpinnerHead
@onready var arm_a: Node3D = $SpinnerHead/FlameArmA
@onready var arm_b: Node3D = $SpinnerHead/FlameArmB
@onready var area_a: Area3D = $SpinnerHead/FlameArmA/DamageArea
@onready var area_b: Area3D = $SpinnerHead/FlameArmB/DamageArea

func _ready() -> void:
	if is_instance_valid(arm_b):
		arm_b.visible = dual_sided
		if is_instance_valid(area_b):
			area_b.monitoring = dual_sided

	if is_instance_valid(area_a):
		area_a.body_entered.connect(_on_flame_hit)
	if is_instance_valid(area_b):
		area_b.body_entered.connect(_on_flame_hit)

func _physics_process(delta: float) -> void:
	if is_instance_valid(spinner_head):
		spinner_head.rotation.y += spin_speed * delta

	_check_area(area_a)
	if dual_sided:
		_check_area(area_b)

func _check_area(area: Area3D) -> void:
	if not is_instance_valid(area) or not area.monitoring:
		return
	for body in area.get_overlapping_bodies():
		if body is Player:
			body.take_damage(damage)

func _on_flame_hit(body: Node3D) -> void:
	if body is Player:
		body.take_damage(damage)
