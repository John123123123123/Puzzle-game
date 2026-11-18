extends Node

var player_count: int = 1
var current_level_index: int = 1
var current_level: int:
	get: return current_level_index
	set(val): current_level_index = val
const MAX_PLAYERS: int = 4

const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2), # P1: Red
	Color(0.2, 0.5, 0.9),  # P2: Blue
	Color(0.2, 0.75, 0.3), # P3: Green
	Color(0.9, 0.75, 0.15) # P4: Gold
]

static func get_player_color(id: int) -> Color:
	return PLAYER_COLORS[clampi(id - 1, 0, PLAYER_COLORS.size() - 1)]

# Regular exploration & puzzle levels
var exploration_levels: Array[String] = [
	"res://scenes/levels/temple_level_1.tscn", # Level 1: The Catacombs (Braziers, spikes, levers)
	"res://scenes/levels/temple_level_2.tscn", # Level 2: Chamber of Mirrors (Light beam & mirror puzzle)
]

# The Golden Idol Temple & Giant Boulder Escape is ALWAYS the grand finale (always the last level)
const FINALE_LEVEL: String = "res://scenes/levels/temple_level_3.tscn"

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const PROGRESS_PATH: String = "user://progress.cfg"

var level_progress: Dictionary = {} # level_num (int) -> { "best_time": float, "best_scarabs": int, "total_scarabs": int }

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	level_progress.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	for section in cfg.get_sections():
		if section.begins_with("level_"):
			var lvl_num := int(section.trim_prefix("level_"))
			level_progress[lvl_num] = {
				"best_time": float(cfg.get_value(section, "best_time", -1.0)),
				"best_scarabs": int(cfg.get_value(section, "best_scarabs", 0)),
				"total_scarabs": int(cfg.get_value(section, "total_scarabs", 3))
			}

func save_progress() -> void:
	var cfg := ConfigFile.new()
	for lvl_num in level_progress.keys():
		var data: Dictionary = level_progress[lvl_num]
		var section := "level_%d" % lvl_num
		cfg.set_value(section, "best_time", data.get("best_time", -1.0))
		cfg.set_value(section, "best_scarabs", data.get("best_scarabs", 0))
		cfg.set_value(section, "total_scarabs", data.get("total_scarabs", 3))
	cfg.save(PROGRESS_PATH)

func record_level_clear(level_num: int, clear_time: float, scarabs: int, total_scarabs: int) -> bool:
	var prev: Dictionary = level_progress.get(level_num, {"best_time": -1.0, "best_scarabs": 0, "total_scarabs": total_scarabs})
	var prev_time: float = float(prev.get("best_time", -1.0))
	var prev_scarabs: int = int(prev.get("best_scarabs", 0))
	var has_previous_clear := prev_time >= 0.0
	var is_new_best := false

	var best_time := prev_time
	if not has_previous_clear or clear_time < prev_time:
		best_time = clear_time
		if has_previous_clear:
			is_new_best = true

	var best_scarabs := maxi(prev_scarabs, scarabs)
	if has_previous_clear and scarabs > prev_scarabs:
		is_new_best = true

	level_progress[level_num] = {
		"best_time": best_time,
		"best_scarabs": best_scarabs,
		"total_scarabs": maxi(total_scarabs, int(prev.get("total_scarabs", 0)))
	}
	save_progress()
	return is_new_best

func get_level_progress(level_num: int) -> Dictionary:
	return level_progress.get(level_num, {})

static func format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

## Returns all levels in order, guaranteeing that the Golden Idol / Boulder Finale is ALWAYS last!
func get_levels() -> Array[String]:
	var list: Array[String] = []
	for lvl in exploration_levels:
		if lvl != FINALE_LEVEL:
			list.append(lvl)
	# Finale level is always appended as the final climax
	list.append(FINALE_LEVEL)
	return list

func get_total_levels() -> int:
	return get_levels().size()

var LEVELS: Array[String]:
	get: return get_levels()

func start_game(selected_players: int, start_level: int = 1) -> void:
	player_count = clampi(selected_players, 1, MAX_PLAYERS)
	load_level(start_level)

func load_level(level_num: int) -> void:
	get_tree().paused = false
	var all_levels = get_levels()
	current_level_index = clampi(level_num, 1, all_levels.size())
	var scene_path = all_levels[current_level_index - 1]
	get_tree().change_scene_to_file(scene_path)

func next_level() -> void:
	get_tree().paused = false
	var all_levels = get_levels()
	if current_level_index < all_levels.size():
		load_level(current_level_index + 1)
	else:
		# Beat the entire campaign! Return to menu
		return_to_menu()

func restart_current_level() -> void:
	get_tree().paused = false
	load_level(current_level_index)

func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
