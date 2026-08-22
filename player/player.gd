class_name Player
extends CharacterBody3D


# ============================================================
# Movement
# ============================================================

@export var move_speed: float = 14.0
@export var jump_speed: float = 15.0
@export var acceleration: float = 300.0

@export var gravity_multiplier: float = 3.0
@export var fall_gravity_multiplier: float = 4.5


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


const LAND_ANIMATION_SPEED: float = 2.0


# ============================================================
# Camera state
# ============================================================

# Normal third-person vertical camera angle.
var base_camera_pitch: float = 0.0

# Temporary offsets produced while Alt is held.
var free_look_yaw: float = 0.0
var free_look_pitch: float = 0.0

# Preserve whatever rotation CameraPivot already has
# in the editor.
var camera_center_yaw: float = 0.0
var camera_center_roll: float = 0.0


# ============================================================
# Initialization
# ============================================================

func _ready() -> void:
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
# Camera recenter
# ============================================================

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return


	# While Alt is held, do not recenter anything.
	if Input.is_key_pressed(KEY_ALT):
		return


	# Frame-rate-independent smoothing.
	var weight: float = (
		1.0
		- exp(
			-free_look_recenter_speed
			* delta
		)
	)


	# --------------------------------------------------------
	# Horizontal recenter
	# --------------------------------------------------------

	free_look_yaw = lerp_angle(
		free_look_yaw,
		0.0,
		weight
	)


	# --------------------------------------------------------
	# Vertical recenter
	# --------------------------------------------------------

	free_look_pitch = lerp(
		free_look_pitch,
		0.0,
		weight
	)


	# Remove tiny floating-point leftovers.

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
		return


	var was_on_floor: bool = is_on_floor()
	var just_jumped: bool = false


	# --------------------------------------------------------
	# Gravity
	# --------------------------------------------------------

	if not is_on_floor():

		if velocity.y < 0.0:
			velocity += (
				get_gravity()
				* fall_gravity_multiplier
				* delta
			)

		else:
			velocity += (
				get_gravity()
				* gravity_multiplier
				* delta
			)


	# --------------------------------------------------------
	# Jump
	# --------------------------------------------------------

	if (
		is_on_floor()
		and Input.is_action_just_pressed("jump")
	):
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


	# Important:
	# movement follows CHARACTER orientation even while
	# Alt free-look is active.
	#
	# This means you can look behind yourself while continuing
	# to run forward.
	var direction: Vector3 = (
		transform.basis
		* Vector3(
			move_input.x,
			0.0,
			move_input.y
		)
	)


	var target: Vector2 = Vector2(
		direction.x,
		direction.z
	) * move_speed


	var current: Vector2 = Vector2(
		velocity.x,
		velocity.z
	)


	var result: Vector2 = current.move_toward(
		target,
		acceleration * delta
	)


	velocity.x = result.x
	velocity.z = result.y


	# --------------------------------------------------------
	# Move
	# --------------------------------------------------------

	move_and_slide()


	# --------------------------------------------------------
	# Landing detection
	# --------------------------------------------------------

	var just_landed: bool = (
		not was_on_floor
		and is_on_floor()
	)


	# --------------------------------------------------------
	# Animation
	# --------------------------------------------------------

	_update_animation(
		move_input,
		just_jumped,
		just_landed
	)


	# --------------------------------------------------------
	# Multiplayer
	# --------------------------------------------------------

	send_data.rpc(
		global_position,
		global_rotation
	)


# ============================================================
# Animation state
# ============================================================

func _update_animation(
	move_input: Vector2,
	just_jumped: bool,
	just_landed: bool
) -> void:

	var moving: bool = (
		move_input.length_squared() > 0.01
	)


	# --------------------------------------------------------
	# Landing
	# --------------------------------------------------------

	if just_landed:

		# Movement immediately cancels the landing animation.
		if moving:
			play_anim(ANIM_SPRINT)

		else:
			play_anim(
				ANIM_JUMP_LAND,
				LAND_ANIMATION_SPEED
			)

		return


	# --------------------------------------------------------
	# Jump start
	# --------------------------------------------------------

	if just_jumped:
		play_anim(ANIM_JUMP_START)
		return


	# --------------------------------------------------------
	# Airborne
	# --------------------------------------------------------

	if not is_on_floor():

		# Allow Jump_Start to finish first.
		if (
			anim_player.current_animation
			== ANIM_JUMP_START
			and anim_player.is_playing()
		):
			return

		play_anim(ANIM_JUMP_LOOP)
		return


	# --------------------------------------------------------
	# Ground movement
	# --------------------------------------------------------

	if moving:
		play_anim(ANIM_SPRINT)
		return


	# --------------------------------------------------------
	# Finish landing only while stationary
	# --------------------------------------------------------

	if (
		anim_player.current_animation
		== ANIM_JUMP_LAND
		and anim_player.is_playing()
	):
		return


	# --------------------------------------------------------
	# Idle
	# --------------------------------------------------------

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
	rot: Vector3
) -> void:

	global_position = pos
	global_rotation = rot
