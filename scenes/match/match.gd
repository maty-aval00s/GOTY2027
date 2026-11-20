extends Node3D

@export var player_scene: PackedScene
@onready var level_root: Node3D = $LevelRoot
@onready var players: Node3D = $Players
@onready var fallback_spawns: Node3D = $SpawnPoints

var spawn_points: Node3D


func _ready() -> void:
	_load_selected_level()
	TagGame.game_over.connect(_on_game_over)
	_spawn_players()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		TagGame.start_game()


func _load_selected_level() -> void:
	var path: String = LevelManager.get_selected_path()
	if path.is_empty():
		push_error("Match: no level selected")
		return

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Match: failed to load level %s" % path)
		return

	var level: Node = packed.instantiate()
	level_root.add_child(level)

	if level.has_node("SpawnPoints"):
		spawn_points = level.get_node("SpawnPoints") as Node3D
	else:
		spawn_points = fallback_spawns


func _spawn_players() -> void:
	if spawn_points == null or spawn_points.get_child_count() == 0:
		spawn_points = fallback_spawns

	for i: int in Game.instance.players.size():
		var player_data: Statics.PlayerData = Game.instance.players[i]
		var player_inst: Player = player_scene.instantiate()
		player_inst.name = str(player_data.id)
		players.add_child(player_inst)
		player_inst.setup(player_data)
		var spawn_point: Node3D = spawn_points.get_child(i % spawn_points.get_child_count())
		player_inst.global_position = spawn_point.global_position


func _on_game_over(_winner_id: int) -> void:
	get_tree().change_scene_to_file("res://ui/game_over.tscn")
