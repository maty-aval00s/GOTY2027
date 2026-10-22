class_name PlayerAnimations
extends Node


# ============================================================
# Animation names
# ============================================================

const ANIM_IDLE: StringName = \
	&"UAL1_Standard_RM/Idle"

const ANIM_SPRINT: StringName = \
	&"UAL1_Standard_RM/Sprint"

const ANIM_JUMP_START: StringName = \
	&"UAL1_Standard_RM/Jump_Start"

const ANIM_JUMP_LOOP: StringName = \
	&"UAL1_Standard_RM/Jump"

const ANIM_JUMP_LAND: StringName = \
	&"UAL1_Standard_RM/Jump_Land"

const ANIM_CLIMB: StringName = \
	&"ClimbUp_1m"

const ANIM_DANCE: StringName = \
	&"UAL1_Standard_RM/Dance"

const ANIM_DEATH: StringName = \
	&"UAL1_Standard_RM/Death01"


# ------------------------------------------------------------
# Slide animations
# Estas están en:
# $UAL2_Standard/AnimationPlayer
# ------------------------------------------------------------

const ANIM_SLIDE_START: StringName = &"Slide_Start"
const ANIM_SLIDE: StringName = &"Slide"
const ANIM_SLIDE_EXIT: StringName = &"Slide_Exit"


const LAND_ANIMATION_SPEED: float = 2.0
const ANIM_CLIMB_DURATION: float = 0.6


# ============================================================
# References and state
# ============================================================

# Idle / Sprint / Jump.
@onready var _anim_player: AnimationPlayer = \
	$"../UAL2_Standard/AnimationPlayer2"

# SprintAnimation adicional.
@onready var _sprint_animation_player: AnimationPlayer = \
	$"../UAL2_Standard/AnimationPlayer3"

# Climb + Slide.
@onready var _action_animation_player: AnimationPlayer = \
	$"../UAL2_Standard/AnimationPlayer"


# True mientras se está reproduciendo Slide_Exit.
# Evita que Idle/Sprint pisen esa animación.
var _slide_exit_playing: bool = false
var _visual_slide_active: bool = false


# ============================================================
# Initialization
# ============================================================

func _ready() -> void:
	_action_animation_player.callback_mode_process = \
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	# Escuchamos cuando terminan Slide_Start y Slide_Exit.
	if not _action_animation_player.animation_finished.is_connected(
		_on_action_animation_finished
	):
		_action_animation_player.animation_finished.connect(
			_on_action_animation_finished
		)


# ============================================================
# Climb
# ============================================================

func play_climb(
	climb_duration: float
) -> void:
	# Cualquier Slide_Exit pendiente deja de tener prioridad.
	_slide_exit_playing = false

	var playback_speed: float = (
		ANIM_CLIMB_DURATION
		/ climb_duration
	)

	_action_animation_player.play(
		ANIM_CLIMB,
		-1.0,
		playback_speed
	)


# ============================================================
# Slide animations
# ============================================================

func start_slide_animation() -> void:
	_visual_slide_active = true
	_slide_exit_playing = false

	# Paramos las animaciones normales para que no
	# pisen el slide.
	_anim_player.stop()
	_sprint_animation_player.stop()

	_action_animation_player.play(
		ANIM_SLIDE_START
	)


func stop_slide_animation(
	play_exit: bool = true
) -> void:
	_visual_slide_active = false

	if not play_exit:
		_slide_exit_playing = false

		if (
			_action_animation_player.current_animation
			== ANIM_SLIDE_START
			or
			_action_animation_player.current_animation
			== ANIM_SLIDE
			or
			_action_animation_player.current_animation
			== ANIM_SLIDE_EXIT
		):
			_action_animation_player.stop()

		return

	# Si ya está haciendo Slide_Exit,
	# no lo reiniciamos.
	if (
		_action_animation_player.current_animation
		== ANIM_SLIDE_EXIT
	):
		_slide_exit_playing = true
		return

	if (
		_action_animation_player.current_animation
		== ANIM_SLIDE_START
		or
		_action_animation_player.current_animation
		== ANIM_SLIDE
	):
		_slide_exit_playing = true

		_action_animation_player.play(
			ANIM_SLIDE_EXIT
		)


func _on_action_animation_finished(
	anim_name: StringName
) -> void:
	# --------------------------------------------------------
	# Slide_Start terminó -> Slide loop
	# --------------------------------------------------------
	if anim_name == ANIM_SLIDE_START:
		if _visual_slide_active:
			_action_animation_player.play(
				ANIM_SLIDE
			)

		return

	# --------------------------------------------------------
	# Slide_Exit terminó
	# --------------------------------------------------------
	if anim_name == ANIM_SLIDE_EXIT:
		_slide_exit_playing = false


# ============================================================
# Animation state
# ============================================================

func update_animations(
	is_sprinting: bool,
	velocity: Vector3,
	slide_active: bool
) -> void:
	# SprintAnimation no debe interferir
	# con Slide ni Slide_Exit.
	if (
		slide_active
		or _slide_exit_playing
	):
		_sprint_animation_player.stop()
		return

	var is_moving: bool = Vector2(
		velocity.x,
		velocity.z
	).length() > 0.2

	if (
		is_sprinting
		and is_moving
	):
		_sprint_animation_player.play(
			"SprintAnimation"
		)

	else:
		_sprint_animation_player.stop()


func update_animation_state(
	moving: bool,
	on_floor: bool,
	just_jumped: bool,
	just_landed: bool,
	on_ledge: bool = false,
	visual_slide_active: bool = false
) -> void:
	_visual_slide_active = visual_slide_active

	# --------------------------------------------------------
	# 1. Climbing
	# --------------------------------------------------------
	if on_ledge:
		_slide_exit_playing = false

		_anim_player.stop()
		_sprint_animation_player.stop()

		if (
			_action_animation_player.current_animation
			!= ANIM_CLIMB
			or not _action_animation_player.is_playing()
		):
			_action_animation_player.play(
				ANIM_CLIMB
			)

		return

	# --------------------------------------------------------
	# Slide
	# --------------------------------------------------------
	if (
		_visual_slide_active
		or _slide_exit_playing
	):
		_anim_player.stop()
		_sprint_animation_player.stop()

		return

	# --------------------------------------------------------
	# 2. Landing
	# --------------------------------------------------------
	if just_landed:
		if moving:
			_play_anim(
				ANIM_SPRINT
			)

		else:
			_play_anim(
				ANIM_JUMP_LAND,
				LAND_ANIMATION_SPEED
			)

		return

	# --------------------------------------------------------
	# 3. Jump start
	# --------------------------------------------------------
	if just_jumped:
		_anim_player.stop()

		_play_anim(
			ANIM_JUMP_START
		)

		return

	# --------------------------------------------------------
	# 4. Airborne
	# --------------------------------------------------------
	if not on_floor:
		if (
			_anim_player.current_animation
			== ANIM_JUMP_START
			and _anim_player.is_playing()
		):
			return

		_play_anim(
			ANIM_JUMP_LOOP
		)

		return

	# --------------------------------------------------------
	# 5. Ground movement
	# --------------------------------------------------------
	if moving:
		_play_anim(
			ANIM_SPRINT
		)

		return

	# --------------------------------------------------------
	# 6. Finish landing transition
	# --------------------------------------------------------
	if (
		_anim_player.current_animation
		== ANIM_JUMP_LAND
		and _anim_player.is_playing()
	):
		return

	# --------------------------------------------------------
	# 7. Idle
	# --------------------------------------------------------
	_play_anim(
		ANIM_IDLE
	)


func _play_anim(
	animation: StringName,
	speed: float = 1.0
) -> void:
	if (
		_anim_player.current_animation
		== animation
	):
		return

	_anim_player.play(
		animation,
		-1.0,
		speed
	)


# ============================================================
# Podium
# ============================================================

func play_podium(
	is_winner: bool
) -> void:
	_action_animation_player.stop()
	_sprint_animation_player.stop()
	_anim_player.play(
		ANIM_DANCE if is_winner else ANIM_DEATH
	)

	if (
		not is_winner
		and not _anim_player.animation_finished.is_connected(
			_hold_defeat_pose
		)
	):
		_anim_player.animation_finished.connect(
			_hold_defeat_pose
		)


func _hold_defeat_pose(
	anim_name: StringName
) -> void:
	if anim_name != ANIM_DEATH:
		return

	_anim_player.seek(
		_anim_player.current_animation_length,
		true
	)
	_anim_player.pause()
