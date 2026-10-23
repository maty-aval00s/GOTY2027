extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players


func _ready() -> void:
	TagGame.game_over.connect(_on_game_over)
	for i: int in Game.instance.players.size():
		var player_data: Statics.PlayerData = Game.instance.players[i]
		var player_inst: Player = player_scene.instantiate()
		player_inst.name = str(player_data.id)
		players.add_child(player_inst)
		player_inst.setup(player_data)
		var spawn_point: Node3D = spawn_points.get_child(i % spawn_points.get_child_count())
		player_inst.global_position = spawn_point.global_position
		
	if multiplayer.is_server():
		TagGame.start_game()


func _on_game_over(_winner_id: int) -> void:
	get_tree().change_scene_to_file("res://ui/game_over.tscn")
