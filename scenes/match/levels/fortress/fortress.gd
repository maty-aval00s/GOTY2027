extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players


func _ready() -> void:
	TagGame.game_over.connect(_on_game_over)
		
	if multiplayer.is_server():
		TagGame.start_game()


func _on_game_over(_winner_id: int) -> void:
	get_tree().change_scene_to_file("res://ui/game_over.tscn")
