extends Node

var player_count: int = 1
var current_level_index: int = 1
var current_level: int:
	get: return current_level_index
	set(val): current_level_index = val
const MAX_PLAYERS: int = 4

# Regular exploration & puzzle levels
var exploration_levels: Array[String] = [
	"res://scenes/levels/temple_level_2.tscn", # Nivå 1: Katakomberna (Eldfat, spikar, spakar)
	"res://scenes/levels/temple_level_3.tscn", # Nivå 2: Solens Spegelsal (Ljusstråle & spegelpussel)
]

# The Golden Idol Temple & Giant Boulder Escape is ALWAYS the grand finale (always the last level)
const FINALE_LEVEL: String = "res://scenes/levels/temple_level_1.tscn"

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

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
