extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players
@onready var void_plane: Area3D = $void_plane


# wraps around if index is too large
@rpc("any_peer", "call_local", "reliable")
func spawn_player(player_id: int, spawn_point_index: int) -> void:
	var spawn_point: Node3D = spawn_points.get_child(spawn_point_index % spawn_points.get_child_count())
	var player_inst: Player = Game.instance.get_player(player_id).inst
	player_inst.global_position = spawn_point.global_position

func spawn_player_randomly(player_inst: Player) -> void:
	var idx: int = randi_range(0, 67)
	var player_id: int = player_inst.get_multiplayer_authority()
	spawn_player.rpc_id(player_id, player_id, idx)

func handle_player_fell(player: Player) -> void:
	print("player fell")
	var owner_id := player.get_multiplayer_authority()
	TagGame.request_tag_by_map(owner_id)
	spawn_player_randomly(player)

func _ready() -> void:
	void_plane.player_fell.connect(handle_player_fell)
	TagGame.game_over.connect(_on_game_over)
		
	if multiplayer.is_server():
		TagGame.start_game()
	

func _on_game_over(_winner_id: int) -> void:
	get_tree().change_scene_to_file("res://ui/game_over.tscn")
