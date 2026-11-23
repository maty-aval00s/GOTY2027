extends Area3D

signal player_fell(player: Player)

func _ready() -> void:
	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	print("Entró: ", body.name)
	var player := body as Player
	if player == null:
		return
	player_fell.emit(player)
	
