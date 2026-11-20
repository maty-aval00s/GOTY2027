extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players
@onready var void_plane: Area3D = $void_plane


# wraps around if index is too large
func spawn_player(player_inst: Player, spawn_point_index: int) -> void:
	var spawn_point: Node3D = spawn_points.get_child(spawn_point_index % spawn_points.get_child_count())
	player_inst.global_position = spawn_point.global_position

func spawn_player_randomly(player_inst: Player) -> void:
	var idx: int = randi_range(0, 67)
	spawn_player(player_inst, idx)

func handle_player_fell(player: Player) -> void:
	var owner_id := player.get_multiplayer_authority()
	TagGame.request_tag_by_map(owner_id)
	spawn_player_randomly(player)

func _ready() -> void:
	void_plane.player_fell.connect(handle_player_fell)
	TagGame.game_over.connect(_on_game_over)
	for i: int in Game.instance.players.size():
		var player_data: Statics.PlayerData = Game.instance.players[i]
		var player_inst: Player = player_scene.instantiate()
		player_inst.name = str(player_data.id)
		players.add_child(player_inst)
		player_inst.setup(player_data)
		
		# spawnear al jugador en el spawn con index i
		spawn_player(player_inst, i)
		
	if multiplayer.is_server():
		TagGame.start_game()
	

func _on_game_over(_winner_id: int) -> void:
	get_tree().change_scene_to_file("res://ui/game_over.tscn")
