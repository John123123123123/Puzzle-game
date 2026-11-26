extends Node3D
class_name QuicksandPit
## Swirling desert quicksand zone: slows movement, pulls toward center, and sinks players who linger without dashing.

const DUST_PUFF := preload("res://scenes/effects/dust_puff.gd")

@export var pit_size: Vector3 = Vector3(4.5, 0.4, 4.5)
@export var slow_factor: float = 0.50
@export var pull_strength: float = 0.85
@export var sink_duration: float = 4.8

@onready var trigger_area: Area3D = $TriggerArea
@onready var collision_shape: CollisionShape3D = $TriggerArea/CollisionShape3D
@onready var sand_mesh: MeshInstance3D = $SandMesh
@onready var rim_mesh: MeshInstance3D = $RimMesh

var _inside_players: Array[Player] = []
var _sink_progress: Dictionary = {} # instance_id -> float (0..1)
var _dust_timers: Dictionary = {} # instance_id -> float

func _ready() -> void:
	add_to_group("quicksand_pit")
	_configure_geometry()
	if is_instance_valid(trigger_area):
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)

func _configure_geometry() -> void:
	if is_instance_valid(collision_shape):
		var b := BoxShape3D.new()
		b.size = Vector3(maxf(0.8, pit_size.x - 0.3), maxf(0.8, pit_size.y + 0.9), maxf(0.8, pit_size.z - 0.3))
		collision_shape.shape = b
		collision_shape.position = Vector3(0.0, 0.45, 0.0)

	if is_instance_valid(sand_mesh):
		var qm := PlaneMesh.new()
		qm.size = Vector2(pit_size.x, pit_size.z)
		sand_mesh.mesh = qm
		sand_mesh.position = Vector3(0.0, 0.03, 0.0)

	if is_instance_valid(rim_mesh):
		var rm := BoxMesh.new()
		rm.size = Vector3(pit_size.x + 0.28, 0.08, pit_size.z + 0.28)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.56, 0.45, 0.30)
		mat.roughness = 0.90
		rm.material = mat
		rim_mesh.mesh = rm
		rim_mesh.position = Vector3(0.0, -0.025, 0.0)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		if not _inside_players.has(p):
			_inside_players.append(p)
		_sink_progress[p.get_instance_id()] = 0.0
		_dust_timers[p.get_instance_id()] = 0.0

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		var p := body as Player
		_inside_players.erase(p)
		_sink_progress.erase(p.get_instance_id())
		_dust_timers.erase(p.get_instance_id())

func _physics_process(delta: float) -> void:
	var is_authority := not (is_instance_valid(NetworkManager) and NetworkManager.is_online) or NetworkManager.is_host
	for i in range(_inside_players.size() - 1, -1, -1):
		var p: Player = _inside_players[i]
		if not is_instance_valid(p) or not p.is_inside_tree():
			_inside_players.remove_at(i)
			continue
		if p.current_health <= 0:
			continue

		var pid := p.get_instance_id()
		if p.is_dashing:
			_sink_progress[pid] = 0.0
			continue

		var prog := float(_sink_progress.get(pid, 0.0)) + delta / maxf(0.5, sink_duration)
		_sink_progress[pid] = clampf(prog, 0.0, 1.0)

		var to_center := global_position - p.global_position
		to_center.y = 0.0
		var pull_vec := to_center.normalized() * pull_strength if to_center.length_squared() > 0.04 else Vector3.ZERO
		p.apply_environment_effect(slow_factor, pull_vec, clampf(prog, 0.0, 1.0) * 0.55)

		var dt := float(_dust_timers.get(pid, 0.0)) + delta
		if dt >= 0.58:
			dt = 0.0
			if is_instance_valid(get_parent()):
				DUST_PUFF.spawn(get_parent(), p.global_position + Vector3(0.0, 0.08, 0.0), 2, 0.85)
		_dust_timers[pid] = dt

		if prog >= 1.0 and p.is_local_controlled():
			_sink_progress[pid] = 0.0
			if is_authority:
				p.take_damage(1)
			else:
				p._rpc_request_chasm_damage.rpc_id(1)
			# Eject to nearest safe pit rim so player isn't trapped
			var out_dir := p.global_position - global_position
			out_dir.y = 0.0
			if out_dir.length_squared() < 0.01:
				out_dir = Vector3.BACK
			out_dir = out_dir.normalized()
			p.global_position = Vector3(
				global_position.x + out_dir.x * (pit_size.x * 0.5 + 0.65),
				global_position.y + 0.25,
				global_position.z + out_dir.z * (pit_size.z * 0.5 + 0.65)
			)
			if is_instance_valid(get_parent()):
				DUST_PUFF.spawn(get_parent(), p.global_position, 5, 1.1)
