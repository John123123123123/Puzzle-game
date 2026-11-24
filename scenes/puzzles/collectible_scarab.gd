extends Area3D
class_name CollectibleScarab

signal collected(scarab: CollectibleScarab)

var is_collected: bool = false
var _bob_time: float = 0.0
var _base_y: float = 0.0

@onready var mesh_root: Node3D = $MeshRoot
@onready var glow_light: OmniLight3D = $OmniLight3D
@onready var wing_l: Node3D = get_node_or_null("MeshRoot/WingL")
@onready var wing_r: Node3D = get_node_or_null("MeshRoot/WingR")

func _ready() -> void:
	add_to_group("collectible_scarab")
	_base_y = mesh_root.position.y
	_bob_time = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	_bob_time += delta * 2.8
	if is_instance_valid(mesh_root):
		mesh_root.rotation.y += delta * 1.9
		mesh_root.position.y = _base_y + sin(_bob_time) * 0.10
	var wing_flap := sin(_bob_time * 3.4) * 0.22
	if is_instance_valid(wing_l):
		wing_l.rotation.z = 0.25 + wing_flap
	if is_instance_valid(wing_r):
		wing_r.rotation.z = -0.25 - wing_flap

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not (body is Player):
		return
	is_collected = true
	collected.emit(self)

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_2d(&"scarab_pickup", 0.98, 1.04, -8.0)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_scarab_collected"):
		hud.register_scarab_collected()

	_spawn_pickup_popup()

	var tween := create_tween().set_parallel(true)
	if is_instance_valid(mesh_root):
		tween.tween_property(mesh_root, "position:y", _base_y + 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh_root, "scale", Vector3.ZERO, 0.3)
	if is_instance_valid(glow_light):
		tween.tween_property(glow_light, "light_energy", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

func _spawn_pickup_popup() -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	var lbl := Label3D.new()
	lbl.text = "🪲 +1 SCARAB!"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.modulate = Color(0.35, 0.95, 1.0, 1.0)
	parent_node.add_child(lbl)
	lbl.global_position = global_position + Vector3(0, 1.1, 0)

	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 0.95, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)
