extends StaticBody3D
@export var TagGame: Script

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if (player == null):
		return
	if (player.is_multiplayer_authority()):
		TagGame.request_tag_by_map.rpc_id(1, player.get_multiplayer_authority())
