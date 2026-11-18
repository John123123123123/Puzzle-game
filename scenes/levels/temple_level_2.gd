extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 2: Pharaoh's Hall of Mirrors (Light beam & mirror puzzle)
## Mapped as index 1 in GameManager.exploration_levels.

@onready var level_exit: LevelExit = $LevelExit

# Mirror & Light Beam elements
@onready var mirror_1: MirrorPillar = $Chamber/Mirror1
@onready var mirror_2: MirrorPillar = $Chamber/Mirror2
@onready var sun_receiver: SunReceiver = $Chamber/SunReceiver
@onready var pharaoh_gate: AncientDoor = $Chamber/PharaohGate

# Co-op plates
@onready var plate_1: PressurePlate = $Chamber/Plate1
@onready var plate_2: PressurePlate = $Chamber/Plate2
@onready var plate_3: PressurePlate = $Chamber/Plate3
@onready var plate_4: PressurePlate = $Chamber/Plate4

var _pushable_blocks: Array = []

func _ready() -> void:
	super._ready()
	hud.set_objective("Level 2: Direct the sunbeam through the mirrors to break the seal!")
	spawn_initial_players(get_configured_player_count(1))
	_pushable_blocks = get_tree().get_nodes_in_group("pushable")

	# Initial light beam check
	mirror_1.rotated.connect(_evaluate_mirrors)
	mirror_2.rotated.connect(_evaluate_mirrors)
	_evaluate_mirrors()

	var scarab_spots: Array[Vector3] = []
	if is_instance_valid(plate_3):
		scarab_spots.append(plate_3.global_position + Vector3(0.0, 0.0, 1.8))
	if is_instance_valid(plate_4):
		scarab_spots.append(plate_4.global_position + Vector3(0.0, 0.0, 1.8))
	if is_instance_valid(pharaoh_gate):
		scarab_spots.append(pharaoh_gate.global_position + Vector3(0.0, 0.0, -2.5))
	spawn_scarabs(scarab_spots)

func _physics_process(_delta: float) -> void:
	# Only re-trace when a mirror is turning or a pushable block is moving
	var needs_update := mirror_1.is_turning or mirror_2.is_turning
	if not needs_update:
		for b in _pushable_blocks:
			if is_instance_valid(b) and b.velocity.length_squared() > 0.001:
				needs_update = true
				break
	if needs_update:
		_evaluate_mirrors()

func _evaluate_mirrors(_angle: float = 0.0) -> void:
	var all_mirrors: Array = [mirror_1, mirror_2]
	var lit_mirrors: Array[MirrorPillar] = []
	var powered_receivers: Array[SunReceiver] = []

	# Mirror 1 receives direct skylight beam from above
	var current: MirrorPillar = mirror_1
	while is_instance_valid(current) and not lit_mirrors.has(current):
		lit_mirrors.append(current)
		var trace := current.trace_beam(30.0)
		current.set_beam_active(true, trace["length"])

		if trace["hit_receiver"] is SunReceiver:
			powered_receivers.append(trace["hit_receiver"])
			current = null
		elif trace["hit_mirror"] is MirrorPillar:
			current = trace["hit_mirror"]
		else:
			current = null

	for m in all_mirrors:
		if is_instance_valid(m) and not lit_mirrors.has(m):
			m.set_beam_active(false)

	if is_instance_valid(sun_receiver):
		sun_receiver.set_powered(powered_receivers.has(sun_receiver))
