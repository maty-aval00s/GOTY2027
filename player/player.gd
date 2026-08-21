class_name Player
extends CharacterBody3D

@export var move_speed: float = 20
@export var jump_speed: float = 5
@export var acceleration: float = 300
@export var gravity_multiplier: float = 3.0
@export var fall_gravity_multiplier: float = 4.5

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -80.0  # grados
@export var max_pitch: float = 80.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var label_3d: Label3D = $Label3D

@onready var anim_player: AnimationPlayer = $UAL2_Standard/AnimationPlayer

func _ready() -> void:
	pass

func setup(player_data: Statics.PlayerData) -> void:
	label_3d.text = player_data.name
	set_multiplayer_authority(player_data.id)
	camera_3d.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if event.is_action_pressed("test"):
		test.rpc()
	
	if event is InputEventMouseMotion:
		# Yaw: rota el personaje entero
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Pitch: rota solo el pivote de la cámara
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		var rot: Vector3 = camera_pivot.rotation_degrees
		rot.x = clamp(rot.x, min_pitch, max_pitch)
		camera_pivot.rotation_degrees = rot

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	if not is_on_floor():
		if velocity.y < 0:
			velocity += get_gravity() * fall_gravity_multiplier * delta
		else:
			velocity += get_gravity() * gravity_multiplier * delta
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
	
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = transform.basis * Vector3(move_input.x, 0, move_input.y)
	
	var target: Vector2 = Vector2(direction.x, direction.z) * move_speed
	var current: Vector2 = Vector2(velocity.x, velocity.z)
	var result: Vector2 = current.move_toward(target, acceleration * delta)
	
	velocity.x = result.x
	velocity.z = result.y
	
	if move_input.length() > 0.1:
		anim_player.play("Walk_Carry")
	else:
		anim_player.play("Idle_FoldArms")
	
	move_and_slide()
	
	send_data.rpc(global_position)

@rpc("any_peer")
func test() -> void:
	Debug.log(name, 10)

@rpc("authority", "call_remote", "unreliable_ordered")
func send_data(pos: Vector3) -> void:
	global_position = pos
