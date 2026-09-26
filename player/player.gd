class_name Player
extends CharacterBody3D


# ============================================================
# Movement
# ============================================================

@export var max_move_speed: float = 14.0
@export var move_speed: float = 14.0
@export var jump_speed: float = 15.0
@export var acceleration: float = 300.0
@export var climb_forward_offset: float = -0.9
@export var climb_up_offset: float = 0.3

@export var gravity_multiplier: float = 3.0
@export var fall_gravity_multiplier: float = 4.5

# Smoothing speed for remote players over the network
@export var position_interpolate_speed: float = 20.0


# ============================================================
# Camera
# ============================================================

@export var mouse_sensitivity: float = 0.003

@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

# Higher = camera recenters faster after releasing Alt.
@export var free_look_recenter_speed: float = 8.0


# ============================================================
# Nodes
# ============================================================

@onready var camera_pivot: Node3D = $CameraPivot

@onready var camera_3d: Camera3D = \
	$CameraPivot/SpringArm3D/Camera3D

@onready var label_3d: Label3D = $Label3D

@onready var anim_player: AnimationPlayer = \
	$UAL2_Standard/AnimationPlayer2

@onready var animation_player: AnimationPlayer = \
	$UAL2_Standard/AnimationPlayer3

@onready var climb_anim_player: AnimationPlayer = \
	$UAL2_Standard/AnimationPlayer
	
#raycasts 
@onready var ray_01:RayCast3D = $Ray1
@onready var ray_02:RayCast3D = $Ray2


# ============================================================
# Animations
# ============================================================

const ANIM_IDLE: StringName = \
	&"UAL1_Standard_RM/Idle"

const ANIM_SPRINT: StringName = \
	&"UAL1_Standard_RM/Sprint"

const ANIM_JUMP_START: StringName = \
	&"UAL1_Standard_RM/Jump_Start"

const ANIM_JUMP_LOOP: StringName = \
	&"UAL1_Standard_RM/Jump_Loop"

const ANIM_JUMP_LAND: StringName = \
	&"UAL1_Standard_RM/Jump_Land"

const ANIM_CLIMB: StringName = \
	&"ClimbUp_1m"

const LAND_ANIMATION_SPEED: float = 2.0
const SPRINT_SPEED_MULTIPLIER = 1.5

const ANIM_CLIMB_DURATION: float = 0.6


# ============================================================
# Camera & Interpolation state
# ============================================================

# Normal third-person vertical camera angle.
var base_camera_pitch: float = 0.0

# Temporary offsets produced while Alt is held.
var free_look_yaw: float = 0.0
var free_look_pitch: float = 0.0

# Preserve whatever rotation CameraPivot already has in the editor.
var camera_center_yaw: float = 0.0
var camera_center_roll: float = 0.0

# Network Targets for Remote Interpolation
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: Vector3 = Vector3.ZERO

# Remote state flags
var _remote_is_on_floor: bool = true
var _remote_was_on_floor: bool = true
var _prev_position: Vector3 = Vector3.ZERO
var _remote_velocity: Vector3 = Vector3.ZERO
var _remote_just_jumped: bool = false
var _remote_onledge: bool = false
var onledge: bool = false
var is_climbing: bool = false
var last_floor_y:float =0.0
var climb_cooldown:float = 0.0





# ============================================================
# Initialization
# ============================================================

func _ready() -> void:
	climb_anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	
	_prev_position = global_position
	_target_position = global_position
	_target_rotation = global_rotation
	
	base_camera_pitch = camera_pivot.rotation.x
	camera_center_yaw = camera_pivot.rotation.y
	camera_center_roll = camera_pivot.rotation.z

	_apply_camera_rotation()


func setup(player_data: Statics.PlayerData) -> void:
	label_3d.text = player_data.name

	set_multiplayer_authority(player_data.id)

	camera_3d.current = is_multiplayer_authority()

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ============================================================
# Input
# ============================================================

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("test"):
		test.rpc()


	# --------------------------------------------------------
	# Mouse movement
	# --------------------------------------------------------

	if event is InputEventMouseMotion:
		var mouse_yaw: float = (
			-event.relative.x
			* mouse_sensitivity
		)

		var mouse_pitch: float = (
			-event.relative.y
			* mouse_sensitivity
		)


		# No Input Map action required.
		var free_look_active: bool = \
			Input.is_key_pressed(KEY_ALT)


		if free_look_active:

			# =================================================
			# ALT HELD
			#
			# Orbit camera around character.
			# Character does not rotate.
			# =================================================

			free_look_yaw += mouse_yaw

			free_look_yaw = wrapf(
				free_look_yaw,
				-PI,
				PI
			)


			var desired_pitch: float = (
				base_camera_pitch
				+ free_look_pitch
				+ mouse_pitch
			)

			desired_pitch = clamp(
				desired_pitch,
				deg_to_rad(min_pitch),
				deg_to_rad(max_pitch)
			)

			free_look_pitch = (
				desired_pitch
				- base_camera_pitch
			)


		else:

			# =================================================
			# NORMAL THIRD-PERSON CAMERA
			#
			# Horizontal mouse turns character.
			# Vertical mouse changes camera pitch.
			# =================================================

			rotate_y(mouse_yaw)

			base_camera_pitch += mouse_pitch

			base_camera_pitch = clamp(
				base_camera_pitch,
				deg_to_rad(min_pitch),
				deg_to_rad(max_pitch)
			)


		_apply_camera_rotation()


# ============================================================
# Visual Process (Camera Recenter & Remote Interpolation)
# ============================================================

func _process(delta: float) -> void:
	# --------------------------------------------------------
	# Remote Player Visual Interpolation
	# --------------------------------------------------------
	if not is_multiplayer_authority():
		global_position = global_position.lerp(
			_target_position, 
			position_interpolate_speed * delta
		)
		global_rotation.y = lerp_angle(
			global_rotation.y, 
			_target_rotation.y, 
			position_interpolate_speed * delta
		)
		return


	# --------------------------------------------------------
	# Authority Camera Recenter
	# --------------------------------------------------------
	if Input.is_key_pressed(KEY_ALT):
		return

	var weight: float = (
		1.0
		- exp(
			-free_look_recenter_speed
			* delta
		)
	)

	free_look_yaw = lerp_angle(
		free_look_yaw,
		0.0,
		weight
	)

	free_look_pitch = lerp(
		free_look_pitch,
		0.0,
		weight
	)

	if abs(free_look_yaw) < 0.0001:
		free_look_yaw = 0.0

	if abs(free_look_pitch) < 0.0001:
		free_look_pitch = 0.0

	_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	camera_pivot.rotation = Vector3(
		base_camera_pitch + free_look_pitch,
		camera_center_yaw + free_look_yaw,
		camera_center_roll
	)


# ============================================================
# Physics
# ============================================================

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		if delta > 0.0:
			_remote_velocity = (_target_position - _prev_position) / delta
			_prev_position = _target_position

		var is_moving: bool = Vector2(_remote_velocity.x, _remote_velocity.z).length() > 0.2
		var just_landed: bool = not _remote_was_on_floor and _remote_is_on_floor
		var just_jumped: bool = _remote_just_jumped

		_remote_just_jumped = false
		_remote_was_on_floor = _remote_is_on_floor

		_update_animation_state(is_moving, _remote_is_on_floor, just_jumped, just_landed, _remote_onledge)
		return

	var was_on_floor: bool = is_on_floor()
	var just_jumped: bool = false

	# --------------------------------------------------------
	# Gravity
	# --------------------------------------------------------
	raycast_detect_ledge()

	if is_climbing:
		velocity = Vector3.ZERO
		_update_animation_state(false, is_on_floor(), false, false, is_climbing)
		send_data.rpc(global_position, global_rotation, is_on_floor(), false, is_climbing)
		return

	elif onledge and climb_cooldown<= 0.0:
		start_climb()
		_update_animation_state(false, is_on_floor(), false, false, is_climbing)
		send_data.rpc(global_position, global_rotation, is_on_floor(), false, is_climbing)
		return

	else:
		climb_cooldown-= delta
		if is_on_floor():
			last_floor_y = global_position.y
		if not is_on_floor():
			if velocity.y < 0.0:
				velocity += get_gravity() * fall_gravity_multiplier * delta
			else:
				velocity += get_gravity() * gravity_multiplier * delta
	# --------------------------------------------------------
	# Jump
	# --------------------------------------------------------
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
		just_jumped = true

	# --------------------------------------------------------
	# Movement
	# --------------------------------------------------------
	var move_input: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	var direction: Vector3 = (transform.basis * Vector3(move_input.x, 0.0, move_input.y))
	var target: Vector2 = Vector2(direction.x, direction.z) * move_speed
	var current: Vector2 = Vector2(velocity.x, velocity.z)
	var result: Vector2 = current.move_toward(target, acceleration * delta)
	var is_sprinting = Input.is_action_just_pressed("sprint")
	velocity.x = result.x
	velocity.z = result.y
	if Input.is_action_pressed("sprint"):
		move_speed = max_move_speed * SPRINT_SPEED_MULTIPLIER
	else:
		move_speed = max_move_speed
		
	

	move_and_slide()
	update_animations(is_sprinting)
		
	# Landing & Animation detection
	var just_landed: bool = (not was_on_floor and is_on_floor())
	var moving: bool = move_input.length_squared() > 0.01
	var on_floor: bool = is_on_floor()
	

	_update_animation_state(moving, on_floor, just_jumped, just_landed, onledge)

	# --------------------------------------------------------
	# Network Sync
	# --------------------------------------------------------
	send_data.rpc(
		global_position,
		global_rotation,
		is_on_floor(),
		just_jumped,
		onledge
	)

#=============================================================
#Ledge/Obstacle Detection
var ledge_point: Vector3 = Vector3.ZERO
func raycast_detect_ledge() -> bool:

	onledge = ray_01.is_colliding() and not ray_02.is_colliding()
	if onledge:
		ledge_point = ray_01.get_collision_point()
	return onledge 


func start_climb() -> void:
	is_climbing = true
	

	var forward: Vector3 = global_transform.basis * Vector3(0, 0, climb_forward_offset)
	var target_pos: Vector3 = Vector3(
		global_position.x + forward.x,
		ledge_point.y + climb_up_offset,
		global_position.z + forward.z
	)

	var climb_duration: float = 0.5
	var playback_speed: float = ANIM_CLIMB_DURATION/ climb_duration
	
	climb_anim_player.play(ANIM_CLIMB, -1.0, playback_speed)

	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, climb_duration)
	tween.finished.connect(_on_climb_finished)

func _on_climb_finished() -> void:
	
	is_climbing = false
	velocity = Vector3.ZERO
	move_and_slide()
	climb_cooldown=0.5



# ============================================================


# ============================================================
# Animation state
# ============================================================

func update_animations(is_sprinting):
	var is_moving: bool = Vector2(velocity.x, velocity.z).length() > 0.2
	if Input.is_action_pressed("sprint") and is_moving:
		animation_player.play("SprintAnimation")
	else:
		animation_player.stop()

func _update_animation_state(
	moving: bool,
	on_floor: bool,
	just_jumped: bool,
	just_landed: bool,
	on_ledge: bool = false
	
) -> void:
	# 1 Climbing
	if on_ledge:
		anim_player.stop()
		if not climb_anim_player.is_playing():
			climb_anim_player.play(ANIM_CLIMB)
		return
	# 2. Landing
	if just_landed:
		if moving:
			play_anim(ANIM_SPRINT)
		else:
			play_anim(ANIM_JUMP_LAND, LAND_ANIMATION_SPEED)
		return

	# 3. Jump start
	if just_jumped:
		play_anim(ANIM_JUMP_START)
		return

	# 4. Airborne
	if not on_floor:
		if anim_player.current_animation == ANIM_JUMP_START and anim_player.is_playing():
			return
		play_anim(ANIM_JUMP_LOOP)
		return

	# 5. Ground movement
	if moving:
		play_anim(ANIM_SPRINT)
		return

	# 6. Finish landing transition
	if anim_player.current_animation == ANIM_JUMP_LAND and anim_player.is_playing():
		return
	
	# 7. Idle
	play_anim(ANIM_IDLE)


func play_anim(
	animation: StringName,
	speed: float = 1.0
) -> void:

	if anim_player.current_animation == animation:
		return

	anim_player.play(
		animation,
		-1.0,
		speed
	)


# ============================================================
# RPCs
# ============================================================

@rpc("any_peer")
func test() -> void:
	Debug.log(name, 10)


@rpc(
	"authority",
	"call_remote",
    "unreliable_ordered"
)
func send_data(
	pos: Vector3,
	rot: Vector3,
	on_floor: bool,
	just_jumped: bool,
	on_ledge:bool
) -> void:

	_target_position = pos
	_target_rotation = rot
	_remote_is_on_floor = on_floor
	_remote_onledge = on_ledge
	if just_jumped:
		_remote_just_jumped = true
