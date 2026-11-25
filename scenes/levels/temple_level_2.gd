extends "res://scenes/levels/base_temple_level.gd"
## Campaign Level 2: Chamber of Mirrors (4-Chamber Co-op Scaled Solar Relay — Zero Crates)
## Mapped as index 1 in GameManager.exploration_levels.

@onready var level_exit: LevelExit = $LevelExit

# Chamber 1: Outer Hall of Reflections (4 Mirrors -> SunReceiver + 1-4P Sun Seals)
@onready var mirror_1: MirrorPillar = $Chamber/Mirror1
@onready var mirror_2: MirrorPillar = $Chamber/Mirror2
@onready var mirror_3: MirrorPillar = $Chamber/Mirror3
@onready var mirror_4: MirrorPillar = $Chamber/Mirror4
@onready var sun_receiver: SunReceiver = $Chamber/SunReceiver
@onready var pharaoh_gate: AncientDoor = $Chamber/PharaohGate

# Chamber 2: Crossfire Solar Gallery (Twin Skylights -> 6 Mirrors -> Twin Receivers + 1-4P Seals)
@onready var mirror_w1: MirrorPillar = $SolarGallery/MirrorW1
@onready var mirror_w2: MirrorPillar = $SolarGallery/MirrorW2
@onready var mirror_w3: MirrorPillar = $SolarGallery/MirrorW3
@onready var mirror_e1: MirrorPillar = $SolarGallery/MirrorE1
@onready var mirror_e2: MirrorPillar = $SolarGallery/MirrorE2
@onready var mirror_e3: MirrorPillar = $SolarGallery/MirrorE3
@onready var receiver_west: SunReceiver = $SolarGallery/SunReceiverWest
@onready var receiver_east: SunReceiver = $SolarGallery/SunReceiverEast
@onready var sanctum_gate: AncientDoor = $SolarGallery/InnerSanctumGate

# Chamber 3: Hall of the Solar Prism (4-Mirror Obstacle Zig-Zag -> PrismSunReceiver + 1-4P Seals)
@onready var prism_m1: MirrorPillar = $PrismHall/PrismMirror1
@onready var prism_m2: MirrorPillar = $PrismHall/PrismMirror2
@onready var prism_m3: MirrorPillar = $PrismHall/PrismMirror3
@onready var prism_m4: MirrorPillar = $PrismHall/PrismMirror4
@onready var prism_receiver: SunReceiver = $PrismHall/PrismSunReceiver
@onready var prism_gate: AncientDoor = $PrismHall/PrismGate

var _all_mirrors: Array[MirrorPillar] = []
var _all_receivers: Array[SunReceiver] = []

func _ready() -> void:
	super._ready()
	for g in [pharaoh_gate, sanctum_gate, prism_gate]:
		if is_instance_valid(g):
			g.door_opened.connect(func(_d): _update_objective())
			g.door_closed.connect(func(_d): _update_objective())

	spawn_initial_players(get_configured_player_count(1))

	_all_mirrors = [
		mirror_1, mirror_2, mirror_3, mirror_4,
		mirror_w1, mirror_w2, mirror_w3,
		mirror_e1, mirror_e2, mirror_e3,
		prism_m1, prism_m2, prism_m3, prism_m4,
	]
	_all_receivers = [sun_receiver, receiver_west, receiver_east, prism_receiver]

	for m in _all_mirrors:
		if is_instance_valid(m):
			m.rotated.connect(_evaluate_mirrors)
	for r in _all_receivers:
		if is_instance_valid(r):
			r.power_changed.connect(func(_p): _update_objective())

	_evaluate_mirrors()
	_update_objective()

	var scarab_spots: Array[Vector3] = [
		Vector3(-7.2, 0.1, -6.5),
		Vector3(7.2, 0.1, -6.5),
		Vector3(-6.2, 0.1, -24.5),
		Vector3(-7.4, 0.1, -42.5),
		Vector3(0.0, 0.1, -51.5),
	]
	spawn_scarabs(scarab_spots)

func on_difficulty_scaled(_party_size: int) -> void:
	_update_objective()

func _physics_process(_delta: float) -> void:
	for m in _all_mirrors:
		if is_instance_valid(m) and m.is_turning:
			_evaluate_mirrors()
			break

func _evaluate_mirrors(_angle: float = 0.0) -> void:
	var lit_mirrors: Array[MirrorPillar] = []
	var powered_receivers: Array[SunReceiver] = []

	var sources: Array[MirrorPillar] = [mirror_1, mirror_w1, mirror_e1, prism_m1]
	for src in sources:
		var current: MirrorPillar = src
		while is_instance_valid(current) and not lit_mirrors.has(current):
			lit_mirrors.append(current)
			var trace := current.trace_beam(30.0)
			current.set_beam_active(true, trace["length"])

			if trace["hit_receiver"] is SunReceiver:
				var hit_r := trace["hit_receiver"] as SunReceiver
				if not powered_receivers.has(hit_r):
					powered_receivers.append(hit_r)
				current = null
			elif trace["hit_mirror"] is MirrorPillar:
				current = trace["hit_mirror"]
			else:
				current = null

	for m in _all_mirrors:
		if is_instance_valid(m) and not lit_mirrors.has(m):
			m.set_beam_active(false)

	for r in _all_receivers:
		if is_instance_valid(r):
			r.set_powered(powered_receivers.has(r))

func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	if is_instance_valid(prism_gate) and prism_gate.is_open:
		hud.set_objective("Level 2: The Solar Prism is unlocked! Step into the portal ahead!")
	elif is_instance_valid(sanctum_gate) and sanctum_gate.is_open:
		hud.set_objective("Level 2: Weave the Solar Prism beam around the central pillar into the crystal!")
	elif is_instance_valid(pharaoh_gate) and pharaoh_gate.is_open:
		var charged := 0
		if is_instance_valid(receiver_west) and receiver_west.is_powered:
			charged += 1
		if is_instance_valid(receiver_east) and receiver_east.is_powered:
			charged += 1
		hud.set_objective("Level 2: Align both twin sunbeams (%d/2) in the Solar Gallery!" % charged)
	else:
		hud.set_objective("Level 2: Rotate the four golden mirrors to guide the sunbeam into the solar crystal!")
