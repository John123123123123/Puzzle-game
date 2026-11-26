extends Node3D
class_name CisternWater
## Dynamic floodgate water pool: smoothly raises/lowers water surface, buoys PushableBlocks into walkable bridges,
## and optionally acts as a rising flood-tide escape hazard.

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")

@export var pool_size: Vector2 = Vector2(10.0, 8.0)
@export var low_y: float = -1.55
@export var high_y: float = -0.18
@export var starts_high: bool = false
@export var transition_speed: float = 1.15
@export var is_rising_hazard: bool = false
@export var rise_speed: float = 0.24
@export var max_hazard_y: float = 2.35

@onready var surface_mesh: MeshInstance3D = $SurfaceMesh
@onready var volume_area: Area3D = $VolumeArea
@onready var volume_shape: CollisionShape3D = $VolumeArea/CollisionShape3D
@onready var water_light: OmniLight3D = get_node_or_null("WaterLight")

var current_water_y: float = -1.55
var target_water_y: float = -1.55
var is_flood_active: bool = false
var _hazard_cooldowns: Dictionary = {} # instance_id -> float
var _inside_players: Array[Player] = []
var _inside_blocks: Array[PushableBlock] = []

func _ready() -> void:
	add_to_group("cistern_water")
	current_water_y = high_y if starts_high else low_y
	target_water_y = current_water_y
	_configure_geometry()
	_apply_surface_y()
	if is_instance_valid(volume_area):
		volume_area.body_entered.connect(_on_body_entered)
		volume_area.body_exited.connect(_on_body_exited)

func _configure_geometry() -> void:
	if is_instance_valid(surface_mesh):
		var pm := PlaneMesh.new()
		pm.size = pool_size
		pm.subdivide_width = 16
		pm.subdivide_depth = 16
		var orig := surface_mesh.get_active_material(0)
		if orig != null:
			pm.material = orig
		surface_mesh.mesh = pm

	if is_instance_valid(volume_shape):
		var bs := BoxShape3D.new()
		var span_h := maxf(4.5, (max_hazard_y if is_rising_hazard else high_y) - low_y + 3.2)
		bs.size = Vector3(pool_size.x, span_h, pool_size.y)
		volume_shape.shape = bs
		volume_shape.position = Vector3(0.0, low_y + span_h * 0.5 - 0.5, 0.0)

	if is_instance_valid(water_light):
		water_light.omni_range = maxf(6.5, maxf(pool_size.x, pool_size.y) * 0.68)

func get_water_surface_y() -> float:
	return current_water_y

func set_flooded(high: bool) -> void:
	target_water_y = high_y if high else low_y
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx_3d(&"door_rumble", global_position + Vector3(0, current_water_y, 0), 1.15, 1.25, -4.0, 28.0, 6.0)

func register_trigger_activated() -> void:
	if is_rising_hazard:
		start_flood_tide()
	else:
		set_flooded(not starts_high)

func register_trigger_deactivated() -> void:
	if not is_rising_hazard:
		set_flooded(starts_high)

func start_flood_tide() -> void:
	is_flood_active = true
	target_water_y = max_hazard_y

func _apply_surface_y() -> void:
	if is_instance_valid(surface_mesh):
		surface_mesh.position.y = current_water_y
	if is_instance_valid(water_light):
		water_light.position.y = current_water_y + 1.4

func _on_body_entered(body: Node3D) -> void:
	if body is PushableBlock:
		var blk := body as PushableBlock
		if not _inside_blocks.has(blk):
			_inside_blocks.append(blk)
		blk.enter_water_zone(self)
	elif body is Player:
		var p := body as Player
		if not _inside_players.has(p):
			_inside_players.append(p)

func _on_body_exited(body: Node3D) -> void:
	if body is PushableBlock:
		var blk := body as PushableBlock
		_inside_blocks.erase(blk)
		blk.exit_water_zone(self)
	elif body is Player:
		var p := body as Player
		_inside_players.erase(p)
		_hazard_cooldowns.erase(p.get_instance_id())

func _physics_process(delta: float) -> void:
	if is_rising_hazard:
		if is_flood_active:
			current_water_y = move_toward(current_water_y, max_hazard_y, rise_speed * delta)
			_apply_surface_y()
	else:
		if absf(current_water_y - target_water_y) > 0.002:
			current_water_y = move_toward(current_water_y, target_water_y, transition_speed * delta)
			_apply_surface_y()

	var is_authority := not (is_instance_valid(NetworkManager) and NetworkManager.is_online) or NetworkManager.is_host
	for i in range(_inside_players.size() - 1, -1, -1):
		var p: Player = _inside_players[i]
		if not is_instance_valid(p) or not p.is_inside_tree():
			_inside_players.remove_at(i)
			continue
		if p.current_health <= 0:
			continue

		var pid := p.get_instance_id()
		var cd := maxf(0.0, float(_hazard_cooldowns.get(pid, 0.0)) - delta)
		_hazard_cooldowns[pid] = cd

		var depth := (global_position.y + current_water_y) - p.global_position.y
		if depth > 0.25 and depth <= 0.62:
			# Ankle/waist wading slows movement slightly
			p.apply_environment_effect(0.72, Vector3.ZERO, depth * 0.18)
		elif depth > 0.62 and cd <= 0.0:
			# Deep water / flood tide hazard
			_hazard_cooldowns[pid] = 1.4
			if p.is_local_controlled():
				if is_authority:
					p.take_damage(1)
				else:
					p._rpc_request_chasm_damage.rpc_id(1)
				if p.current_health > 0:
					var respawn_pos := Vector3(0.0, 0.4, 4.0)
					var lvl := _find_temple_level()
					if is_instance_valid(lvl) and lvl.has_method("get_room_respawn_pos"):
						respawn_pos = lvl.get_room_respawn_pos(p.global_position)
					elif is_instance_valid(lvl) and "latest_checkpoint_pos" in lvl:
						respawn_pos = lvl.latest_checkpoint_pos + Vector3(0.0, 0.35, 0.0)
					p.velocity = Vector3.ZERO
					p.global_position = respawn_pos
					if is_instance_valid(get_parent()):
						DUST_PUFF.spawn(get_parent(), p.global_position, 4, 1.0)

func _find_temple_level() -> Node:
	var n: Node = get_parent()
	while is_instance_valid(n):
		if n.has_method("get_room_respawn_pos"):
			return n
		n = n.get_parent()
	if is_instance_valid(get_tree()) and is_instance_valid(get_tree().current_scene):
		return get_tree().current_scene
	return null
