class_name Player
extends CharacterBody3D

@export var move_speed: float = 5
@export var jump_speed: float = 7
@export var acceleration: float = 20


@onready var camera_3d: Camera3D = $Camera3D
@onready var label_3d: Label3D = $Label3D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("test"):
		test.rpc()


func setup(player_data: Statics.PlayerData) -> void:
	label_3d.text = player_data.name
	set_multiplayer_authority(player_data.id)
	camera_3d.current = is_multiplayer_authority()

@rpc("any_peer")
func test() -> void:
	#var reciver_name: String = Game.get_current_player().name
	Debug.log(name, 10)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
	
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	var direction: Vector3 = transform.basis * Vector3(move_input.x, 0, move_input.y)
	
	var target: Vector2 = Vector2(direction.x, direction.z) * move_speed
	var current: Vector2 = Vector2(velocity.x, velocity.z)
	var result: Vector2 = current.move_toward(target, acceleration * delta)
	
	velocity.x = result.x
	velocity.z = result.y
	
	
	move_and_slide()
	
	send_data.rpc(global_position)


@rpc("authority", "call_remote", "unreliable_ordered")
func send_data(pos: Vector3) -> void:
	global_position = pos
