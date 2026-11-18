extends Node
## Centralized persistent settings manager for Audio, Graphics, Display, Game, Keybinds, and Gamepad.

signal settings_changed

const CONFIG_PATH: String = "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
const DEFAULT_RESOLUTION_INDEX: int = 2

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "p1_up", "label": "P1 Move Up"},
	{"action": "p1_down", "label": "P1 Move Down"},
	{"action": "p1_left", "label": "P1 Move Left"},
	{"action": "p1_right", "label": "P1 Move Right"},
	{"action": "p1_interact", "label": "P1 Interact / Grab"},
	{"action": "p1_action", "label": "P1 Whip"},
	{"action": "p2_up", "label": "P2 Move Up"},
	{"action": "p2_down", "label": "P2 Move Down"},
	{"action": "p2_left", "label": "P2 Move Left"},
	{"action": "p2_right", "label": "P2 Move Right"},
	{"action": "p2_interact", "label": "P2 Interact / Grab"},
	{"action": "p2_action", "label": "P2 Whip"},
	{"action": "cam_rotate_left", "label": "Camera Rotate Left"},
	{"action": "cam_rotate_right", "label": "Camera Rotate Right"},
]

# Audio
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ambient_volume: float = 0.7

# Graphics
var msaa: int = 2 # 0=Off, 1=2x, 2=4x
var fxaa: bool = true
var shadow_quality: int = 2 # 0=Low, 1=Medium, 2=High
var ssao_enabled: bool = true
var ssil_enabled: bool = true
var glow_enabled: bool = true

# Display
var window_mode: int = 0 # 0=Windowed, 1=Borderless, 2=Fullscreen
var resolution_index: int = DEFAULT_RESOLUTION_INDEX
var vsync: int = 1 # 0=Off, 1=On, 2=Adaptive

# Game
var camera_sensitivity: float = 1.0
var camera_shake: bool = true
var show_interact_prompts: bool = true
var show_timer: bool = true
var show_progression_indicators: bool = false

# Gamepad
var gamepad_deadzone: float = 0.25
var invert_camera_x: bool = false
var controller_rumble: bool = true

var _default_keys: Dictionary = {} # action_name -> Array[int] of physical_keycode

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snapshot_default_keys()
	load_settings()
	apply_all()

func _snapshot_default_keys() -> void:
	for entry in REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		var keys: Array[int] = []
		if InputMap.has_action(action):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey:
					keys.append(ev.physical_keycode)
		_default_keys[action] = keys

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return

	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	ambient_volume = cfg.get_value("audio", "ambient_volume", 0.7)

	msaa = cfg.get_value("graphics", "msaa", 2)
	fxaa = cfg.get_value("graphics", "fxaa", true)
	shadow_quality = cfg.get_value("graphics", "shadow_quality", 2)
	ssao_enabled = cfg.get_value("graphics", "ssao_enabled", true)
	ssil_enabled = cfg.get_value("graphics", "ssil_enabled", true)
	glow_enabled = cfg.get_value("graphics", "glow_enabled", true)

	window_mode = cfg.get_value("display", "window_mode", 0)
	resolution_index = clampi(cfg.get_value("display", "resolution_index", DEFAULT_RESOLUTION_INDEX), 0, RESOLUTIONS.size() - 1)
	vsync = cfg.get_value("display", "vsync", 1)

	camera_sensitivity = cfg.get_value("game", "camera_sensitivity", 1.0)
	camera_shake = cfg.get_value("game", "camera_shake", true)
	show_interact_prompts = cfg.get_value("game", "show_interact_prompts", true)
	show_timer = cfg.get_value("game", "show_timer", true)
	show_progression_indicators = cfg.get_value("game", "show_progression_indicators", false)

	gamepad_deadzone = cfg.get_value("gamepad", "gamepad_deadzone", 0.25)
	invert_camera_x = cfg.get_value("gamepad", "invert_camera_x", false)
	controller_rumble = cfg.get_value("gamepad", "controller_rumble", true)

	for entry in REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		if cfg.has_section_key("keybinds", action):
			var keycode := int(cfg.get_value("keybinds", action, 0))
			if keycode > 0:
				set_action_key(action, keycode, false)

func save_settings() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "ambient_volume", ambient_volume)

	cfg.set_value("graphics", "msaa", msaa)
	cfg.set_value("graphics", "fxaa", fxaa)
	cfg.set_value("graphics", "shadow_quality", shadow_quality)
	cfg.set_value("graphics", "ssao_enabled", ssao_enabled)
	cfg.set_value("graphics", "ssil_enabled", ssil_enabled)
	cfg.set_value("graphics", "glow_enabled", glow_enabled)

	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "vsync", vsync)

	cfg.set_value("game", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("game", "camera_shake", camera_shake)
	cfg.set_value("game", "show_interact_prompts", show_interact_prompts)
	cfg.set_value("game", "show_timer", show_timer)
	cfg.set_value("game", "show_progression_indicators", show_progression_indicators)

	cfg.set_value("gamepad", "gamepad_deadzone", gamepad_deadzone)
	cfg.set_value("gamepad", "invert_camera_x", invert_camera_x)
	cfg.set_value("gamepad", "controller_rumble", controller_rumble)

	for entry in REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		var kc := get_action_keycode(action)
		if kc > 0:
			cfg.set_value("keybinds", action, kc)

	cfg.save(CONFIG_PATH)

func apply_all() -> void:
	apply_audio()
	apply_graphics()
	apply_display()
	apply_gamepad()
	settings_changed.emit()

func apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(0.001, master_volume)))

	if is_instance_valid(AudioManager):
		AudioManager.master_sfx_volume_db = -80.0 if sfx_volume <= 0.001 else linear_to_db(sfx_volume)
		AudioManager.ambient_volume_db = -80.0 if ambient_volume <= 0.001 else (linear_to_db(ambient_volume) - 12.0)
		if is_instance_valid(AudioManager._ambient_player):
			AudioManager._ambient_player.volume_db = AudioManager.ambient_volume_db

func apply_graphics() -> void:
	var vp := get_viewport()
	if vp:
		match msaa:
			0: vp.msaa_3d = Viewport.MSAA_DISABLED
			1: vp.msaa_3d = Viewport.MSAA_2X
			_: vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if fxaa else Viewport.SCREEN_SPACE_AA_DISABLED

	match shadow_quality:
		0:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)

	apply_environment()

func apply_environment() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var world_env := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.ssao_enabled = ssao_enabled
		world_env.environment.ssil_enabled = ssil_enabled
		world_env.environment.glow_enabled = glow_enabled

func apply_display() -> void:
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res := RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
			DisplayServer.window_set_size(res)

	match vsync:
		0: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		2: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

func apply_gamepad() -> void:
	for p_id in range(1, 5):
		for suffix in ["up", "down", "left", "right", "interact", "action"]:
			var action := "p%d_%s" % [p_id, suffix]
			if InputMap.has_action(action):
				InputMap.action_set_deadzone(action, gamepad_deadzone)

func get_action_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0

func get_action_key_label(action: String) -> String:
	var kc := get_action_keycode(action)
	if kc <= 0:
		return "Unbound"
	return OS.get_keycode_string(kc)

func set_action_key(action: String, physical_keycode: int, save_after: bool = true) -> void:
	if not InputMap.has_action(action):
		return
	var to_remove: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			to_remove.append(ev)
	for ev in to_remove:
		InputMap.action_erase_event(action, ev)

	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, new_ev)
	if save_after:
		save_settings()
		settings_changed.emit()

func reset_keybinds() -> void:
	for action in _default_keys.keys():
		if not InputMap.has_action(action):
			continue
		var to_remove: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				to_remove.append(ev)
		for ev in to_remove:
			InputMap.action_erase_event(action, ev)

		for kc in _default_keys[action]:
			var new_ev := InputEventKey.new()
			new_ev.physical_keycode = kc
			InputMap.action_add_event(action, new_ev)
	save_settings()
	settings_changed.emit()

func reset_to_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	ambient_volume = 0.7
	msaa = 2
	fxaa = true
	shadow_quality = 2
	ssao_enabled = true
	ssil_enabled = true
	glow_enabled = true
	window_mode = 0
	resolution_index = DEFAULT_RESOLUTION_INDEX
	vsync = 1
	camera_sensitivity = 1.0
	camera_shake = true
	show_interact_prompts = true
	show_timer = true
	show_progression_indicators = false
	gamepad_deadzone = 0.25
	invert_camera_x = false
	controller_rumble = true
	reset_keybinds()
	apply_all()
	save_settings()
