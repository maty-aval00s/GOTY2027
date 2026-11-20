extends Node

## Lightweight map catalog (paths only — never preload match scenes here).

signal level_changed(index: int)

const LEVEL_PATHS: PackedStringArray = [
	"res://scenes/match/levels/parkour1.tscn",
	"res://scenes/match/levels/parkour2.tscn",
]

const LEVEL_NAMES: PackedStringArray = [
	"Parkour 1 - Courtyard",
	"Parkour 2 - High Spire",
]

var current_level_index: int = 0


func _ready() -> void:
	current_level_index = clampi(current_level_index, 0, maxi(get_level_count() - 1, 0))


func get_level_count() -> int:
	return LEVEL_PATHS.size()


func get_level_name(index: int = -1) -> String:
	var i: int = current_level_index if index < 0 else index
	if i < 0 or i >= LEVEL_NAMES.size():
		return "—"
	return LEVEL_NAMES[i]


func get_selected_path() -> String:
	if LEVEL_PATHS.is_empty():
		return ""
	var path: String = LEVEL_PATHS[current_level_index]
	if not ResourceLoader.exists(path):
		return ""
	return path


func can_select() -> bool:
	return get_level_count() > 0


func set_level_index(index: int) -> void:
	if LEVEL_PATHS.is_empty():
		return
	var next: int = clampi(index, 0, LEVEL_PATHS.size() - 1)
	current_level_index = next
	level_changed.emit(current_level_index)


func select_next() -> void:
	if LEVEL_PATHS.is_empty():
		return
	set_level_index((current_level_index + 1) % LEVEL_PATHS.size())


func select_previous() -> void:
	if LEVEL_PATHS.is_empty():
		return
	var next: int = current_level_index - 1
	if next < 0:
		next = LEVEL_PATHS.size() - 1
	set_level_index(next)
