class_name GameOverScreen
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/match/player/player.tscn")
const FACING_CAMERA: float = PI

@onready var players_root: Node3D = $Players
@onready var camera: Camera3D = $Camera3D
@onready var winner_name_label: Label = %WinnerName
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.look_at(Vector3(0.0, 1.15, 0.2))
	menu_button.pressed.connect(_return_to_menu)
	menu_button.grab_focus()
	if Game.instance.player_id:
		Game.instance.player_id.hide()
	_build_podium()


func _build_podium() -> void:
	var winner: Statics.PlayerData = Game.instance.get_player(TagGame.match_winner_id)
	winner_name_label.text = winner.name if winner != null else "Sin ganador"

	var losers: Array[Statics.PlayerData] = []
	for player: Statics.PlayerData in Game.instance.players:
		if winner == null or player.id != winner.id:
			losers.append(player)

	if winner != null:
		_spawn(winner, _winner_transform(), true)

	var total: int = losers.size()
	for index: int in total:
		_spawn(losers[index], _loser_transform(index, total), false)


func _spawn(data: Statics.PlayerData, placement: Transform3D, is_winner: bool) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.podium_mode = true
	player.name = "Podium%d" % data.id
	players_root.add_child(player)
	player.global_transform = placement
	player.present_on_podium(data.name, is_winner)


func _winner_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, FACING_CAMERA), Vector3(0.0, 0.0, 1.0))


func _loser_transform(index: int, _total: int) -> Transform3D:
	var slots: Array[Vector3] = [
		Vector3(-1.9, 0.0, -0.15),
		Vector3(1.9, 0.0, -0.15),
		Vector3(-3.3, 0.0, -0.95),
		Vector3(3.3, 0.0, -0.95),
	]
	var position: Vector3 = slots[mini(index, slots.size() - 1)]
	return Transform3D(Basis(Vector3.UP, FACING_CAMERA), position)


func _return_to_menu() -> void:
	Lobby.instance.go_to_menu()
