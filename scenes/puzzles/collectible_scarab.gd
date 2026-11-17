extends Area3D
class_name CollectibleScarab

signal collected(scarab: CollectibleScarab)

var is_collected: bool = false
var _bob_time: float = 0.0
var _base_y: float = 0.0

@onready var mesh_root: Node3D = $MeshRoot
@onready var glow_light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	add_to_group("collectible_scarab")
	_base_y = mesh_root.position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	_bob_time += delta * 2.6
	if is_instance_valid(mesh_root):
		mesh_root.rotation.y += delta * 1.8
		mesh_root.position.y = _base_y + sin(_bob_time) * 0.1

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not (body is Player):
		return
	is_collected = true
	collected.emit(self)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_2d(&"scarab_pickup", 0.98, 1.04, -2.0)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_scarab_collected"):
		hud.register_scarab_collected()

	var tween := create_tween().set_parallel(true)
	if is_instance_valid(mesh_root):
		tween.tween_property(mesh_root, "position:y", _base_y + 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh_root, "scale", Vector3.ZERO, 0.3)
	if is_instance_valid(glow_light):
		tween.tween_property(glow_light, "light_energy", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
