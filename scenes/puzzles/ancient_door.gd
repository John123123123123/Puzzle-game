extends StaticBody3D
class_name AncientDoor

signal door_opened(door: AncientDoor)

@export var required_triggers: int = 1
@export var coop_extra_triggers_per_player: int = 0
@export var open_height: float = 4.8
@export var open_duration: float = 1.0
@export var pressure_plates: Array[NodePath] = []
@export var stays_open: bool = true

var external_triggers_count: int = 0
var active_triggers_count: int = 0
var is_open: bool = false
var closed_position: Vector3
var _base_required_triggers: int = 1

@onready var door_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var rune_light: OmniLight3D = $RuneLight
@onready var rune_light_back: OmniLight3D = $RuneLightBack

var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	closed_position = position
	_base_required_triggers = required_triggers
	add_to_group("ancient_door")

	if is_instance_valid(door_mesh):
		var mat = door_mesh.get_active_material(0)
		if mat:
			door_mesh.material_override = mat.duplicate()

	if is_instance_valid(AudioManager):
		audio_player = AudioManager.create_player_3d(&"door_rumble", self, 0.0, 35.0, 8.0)

	if rune_light:
		rune_light.light_energy = 0.4
	if rune_light_back:
		rune_light_back.light_energy = 0.4

	for path in pressure_plates:
		var plate = get_node_or_null(path)
		if plate and plate.has_signal("state_changed"):
			plate.state_changed.connect(_on_plate_state_changed)

	_evaluate_door_state()

func apply_coop_difficulty(player_count: int) -> void:
	if is_open or required_triggers == 0 or coop_extra_triggers_per_player <= 0:
		return
	required_triggers = _base_required_triggers + coop_extra_triggers_per_player * maxi(0, player_count - 1)
	_evaluate_door_state()

func _on_plate_state_changed(_is_active: bool) -> void:
	_evaluate_door_state()

func register_trigger_activated() -> void:
	external_triggers_count += 1
	_evaluate_door_state()

func register_trigger_deactivated() -> void:
	external_triggers_count = maxi(0, external_triggers_count - 1)
	_evaluate_door_state()

func _get_pressed_plates_count() -> int:
	var count = 0
	for path in pressure_plates:
		var plate = get_node_or_null(path)
		if plate and "is_pressed" in plate and plate.is_pressed:
			count += 1
	return count

func force_open_permanent() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
		_rpc_sync_door.rpc(true, true)
	_apply_force_open()

func _apply_force_open() -> void:
	required_triggers = 0
	if not is_open:
		is_open = true
		_animate_door(true)
		door_opened.emit(self)
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)

@rpc("authority", "reliable")
func _rpc_sync_door(open_state: bool, permanent: bool) -> void:
	if permanent:
		_apply_force_open()
		return
	if is_open != open_state:
		is_open = open_state
		_animate_door(is_open)
		if is_open:
			door_opened.emit(self)

func _evaluate_door_state() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.is_online and not NetworkManager.is_host:
		return
	if required_triggers == 0:
		return

	active_triggers_count = _get_pressed_plates_count() + external_triggers_count
	var should_be_open = active_triggers_count >= required_triggers
	if should_be_open:
		if not is_open:
			is_open = true
			_animate_door(true)
			door_opened.emit(self)
			if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
				_rpc_sync_door.rpc(true, stays_open)
		if stays_open:
			required_triggers = 0
	elif not stays_open:
		if is_open:
			is_open = false
			_animate_door(false)
			if is_instance_valid(NetworkManager) and NetworkManager.is_online and NetworkManager.is_host:
				_rpc_sync_door.rpc(false, false)

func _animate_door(open: bool) -> void:
	var target_pos = closed_position + (Vector3.UP * open_height if open else Vector3.ZERO)

	if is_instance_valid(audio_player):
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_pos, open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var target_energy = 2.4 if open else 0.4
	if rune_light:
		tween.tween_property(rune_light, "light_energy", target_energy, 0.6)
	if rune_light_back:
		tween.tween_property(rune_light_back, "light_energy", target_energy, 0.6)

	if is_instance_valid(door_mesh):
		var mat = door_mesh.get_active_material(0) as ShaderMaterial
		if not mat and door_mesh.mesh:
			mat = door_mesh.mesh.material as ShaderMaterial
		if mat:
			var target_glow = 1.0 if open else 0.0
			tween.tween_property(mat, "shader_parameter/open_glow", target_glow, 0.6)

	if open:
		tween.chain().tween_callback(func():
			if is_instance_valid(collision_shape):
				collision_shape.set_deferred("disabled", true)
		)
	else:
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", false)
