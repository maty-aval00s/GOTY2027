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

@export var min_camera_distance: float = 3.2


# ============================================================
# Nodes
# ============================================================

@onready var camera_pivot: Node3D = $CameraPivot

@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

@onready var camera_3d: Camera3D = \
	$CameraPivot/SpringArm3D/Camera3D

@onready var label_3d: Label3D = $Label3D


# Idle / Sprint / Jump
@onready var anim_player: AnimationPlayer = \
	$UAL2_Standard/AnimationPlayer2


# SprintAnimation adicional
@onready var animation_player: AnimationPlayer = \
	$UAL2_Standard/AnimationPlayer3


# Climb + Slide
@onready var climb_anim_player: AnimationPlayer = \
	$UAL2_Standard/AnimationPlayer


# Raycasts
@onready var ray_01: RayCast3D = $Ray1
@onready var ray_02: RayCast3D = $Ray2


# Controllers
@onready var grapple: GrappleHook = $GrappleHook
@onready var slide: SlideController = $SlideController


@onready var tag_zone: Area3D = $TagZone


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


# ------------------------------------------------------------
# Slide animations
# Estas están en:
# $UAL2_Standard/AnimationPlayer
# ------------------------------------------------------------

const ANIM_SLIDE_START: StringName = &"Slide_Start"
const ANIM_SLIDE: StringName = &"Slide"
const ANIM_SLIDE_EXIT: StringName = &"Slide_Exit"


const LAND_ANIMATION_SPEED: float = 2.0
const SPRINT_SPEED_MULTIPLIER: float = 1.5
const ANIM_CLIMB_DURATION: float = 0.6


# ============================================================
# Camera & Interpolation state
# ============================================================

var base_camera_pitch: float = 0.0

var free_look_yaw: float = 0.0
var free_look_pitch: float = 0.0

var camera_center_yaw: float = 0.0
var camera_center_roll: float = 0.0


# ============================================================
# Network Targets
# ============================================================

var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: Vector3 = Vector3.ZERO


# ============================================================
# Remote state
# ============================================================

var _remote_is_on_floor: bool = true
var _remote_was_on_floor: bool = true

var _prev_position: Vector3 = Vector3.ZERO
var _remote_velocity: Vector3 = Vector3.ZERO

var _remote_just_jumped: bool = false
var _remote_onledge: bool = false

var _remote_grapple_visible: bool = false
var _remote_grapple_point: Vector3 = Vector3.ZERO

var _remote_is_sliding: bool = false
var _remote_was_sliding: bool = false


# ============================================================
# Player state
# ============================================================

var onledge: bool = false
var is_climbing: bool = false

var last_floor_y: float = 0.0
var climb_cooldown: float = 0.0

var role: Statics.Role = Statics.Role.NONE

var _player_name: String = ""
var _tag_timer_label: Label


# True mientras se está reproduciendo Slide_Exit.
# Evita que Idle/Sprint pisen esa animación.
var _slide_exit_playing: bool = false


# ============================================================
# Initialization
# ============================================================

func _ready() -> void:
	process_priority = 1

	spring_arm.add_excluded_object(get_rid())

	climb_anim_player.callback_mode_process = \
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS


	# Escuchamos cuando terminan Slide_Start y Slide_Exit.
	if not climb_anim_player.animation_finished.is_connected(
		_on_action_animation_finished
	):
		climb_anim_player.animation_finished.connect(
			_on_action_animation_finished
		)


	_prev_position = global_position
	_target_position = global_position
	_target_rotation = global_rotation


	base_camera_pitch = camera_pivot.rotation.x
	camera_center_yaw = camera_pivot.rotation.y
	camera_center_roll = camera_pivot.rotation.z


	_apply_camera_rotation()


	tag_zone.body_entered.connect(
		_on_tag_zone_body_entered
	)

	TagGame.player_exploded.connect(
		_on_player_exploded
	)


func setup(player_data: Statics.PlayerData) -> void:
	_player_name = player_data.name
	role = player_data.role


	if not Game.instance.player_updated.is_connected(
		_on_player_data_updated
	):
		Game.instance.player_updated.connect(
			_on_player_data_updated
		)


	set_multiplayer_authority(player_data.id)

	_refresh_role_label()


	camera_3d.current = is_multiplayer_authority()


	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		_add_crosshair()
		_add_tag_hud()

		Debug.log(
			"Rol: %s" % Statics.get_role_name(role),
			6.0
		)


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


		var free_look_active: bool = \
			Input.is_key_pressed(KEY_ALT)


		if free_look_active:

			# -------------------------------------------------
			# ALT HELD
			# -------------------------------------------------

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

			# -------------------------------------------------
			# Normal third-person camera
			# -------------------------------------------------

			rotate_y(mouse_yaw)

			base_camera_pitch += mouse_pitch


			base_camera_pitch = clamp(
				base_camera_pitch,
				deg_to_rad(min_pitch),
				deg_to_rad(max_pitch)
			)


		_apply_camera_rotation()


# ============================================================
# Visual Process
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


		grapple.show_synced(
			grapple.origin_from(self),
			_remote_grapple_visible,
			_remote_grapple_point
		)

		return


	# --------------------------------------------------------
	# Authority Camera Recenter
	# --------------------------------------------------------

	grapple.draw(
		grapple.origin_from(self)
	)

	_keep_camera_back()


	if _tag_timer_label:
		if (
			TagGame.game_active
			and TagGame.it_player_id
			== get_multiplayer_authority()
		):
			_tag_timer_label.visible = true
			_tag_timer_label.text = str(
				int(TagGame.time_left)
			)

		else:
			_tag_timer_label.visible = false


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
	_keep_camera_back()


func _keep_camera_back() -> void:
	var cam_pos: Vector3 = camera_3d.position


	if cam_pos.z >= min_camera_distance:
		return


	cam_pos.z = min_camera_distance
	camera_3d.position = cam_pos


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

	# ========================================================
	# REMOTE PLAYER
	# ========================================================

	if not is_multiplayer_authority():

		if delta > 0.0:
			_remote_velocity = (
				_target_position
				- _prev_position
			) / delta

			_prev_position = _target_position


		var is_moving: bool = Vector2(
			_remote_velocity.x,
			_remote_velocity.z
		).length() > 0.2


		var just_landed: bool = (
			not _remote_was_on_floor
			and _remote_is_on_floor
		)


		var just_jumped: bool = \
			_remote_just_jumped


		_remote_just_jumped = false
		_remote_was_on_floor = _remote_is_on_floor


		# ----------------------------------------------------
		# Remote slide animation state
		# ----------------------------------------------------

		if _remote_is_sliding != _remote_was_sliding:

			if _remote_is_sliding:
				start_slide_animation()

			else:
				stop_slide_animation()


		_remote_was_sliding = _remote_is_sliding


		_update_animation_state(
			is_moving,
			_remote_is_on_floor,
			just_jumped,
			just_landed,
			_remote_onledge
		)


		return


	# ========================================================
	# LOCAL PLAYER
	# ========================================================

	var was_on_floor: bool = is_on_floor()
	var just_jumped: bool = false


	# --------------------------------------------------------
	# General updates
	# --------------------------------------------------------

	raycast_detect_ledge()


	grapple.tick_cooldown(delta)

	grapple.tick_retract(
		grapple.origin_from(self),
		delta
	)


	slide.tick_cooldown(delta)


	# --------------------------------------------------------
	# Climbing
	# --------------------------------------------------------

	if is_climbing:

		if slide.active:
			slide.stop()

			# No hacemos Slide_Exit porque inmediatamente
			# entra la animación de climb.
			stop_slide_animation(false)


		grapple.cancel()

		velocity = Vector3.ZERO


		_update_animation_state(
			false,
			is_on_floor(),
			false,
			false,
			is_climbing
		)


		_send_state(
			false,
			is_climbing
		)


		return


	# --------------------------------------------------------
	# Grapple input
	# --------------------------------------------------------

	_handle_grapple_input()


	# --------------------------------------------------------
	# Grapple movement
	# --------------------------------------------------------

	if grapple.is_pulling():

		if slide.active:
			slide.stop()

			# Grapple toma prioridad.
			stop_slide_animation(false)


		if grapple.advance_pull(
			self,
			delta
		):
			move_and_slide()


			var grapple_moving: bool = Vector2(
				velocity.x,
				velocity.z
			).length() > 0.2


			_update_animation_state(
				grapple_moving,
				is_on_floor(),
				false,
				false,
				false
			)


			_send_state(
				false,
				false
			)


			return


	# --------------------------------------------------------
	# Ledge / climb
	# --------------------------------------------------------

	if (
		onledge
		and climb_cooldown <= 0.0
	):

		if slide.active:
			slide.stop()
			stop_slide_animation(false)


		start_climb()


		_update_animation_state(
			false,
			is_on_floor(),
			false,
			false,
			is_climbing
		)


		_send_state(
			false,
			is_climbing
		)


		return


	else:

		climb_cooldown = maxf(
			climb_cooldown - delta,
			0.0
		)


		if is_on_floor():
			last_floor_y = global_position.y


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

		# Saltar cancela el slide.
		if slide.active:
			slide.stop()

			# Dejamos que Jump_Start tome prioridad.
			stop_slide_animation(false)


		velocity.y = jump_speed
		just_jumped = true


	# --------------------------------------------------------
	# Slide start
	# --------------------------------------------------------

	if Input.is_action_just_pressed("crouch"):

		if slide.can_start(self):
			slide.start(self)

			start_slide_animation()


	# --------------------------------------------------------
	# Slide update
	# --------------------------------------------------------

	if slide.active:

		if not Input.is_action_pressed("crouch"):

			slide.stop()

			stop_slide_animation()


		else:

			var was_sliding: bool = slide.active


			slide.tick(
				self,
				delta
			)


			# SlideController puede terminar por tiempo
			# o por falta de velocidad.
			if (
				was_sliding
				and not slide.active
			):
				stop_slide_animation()


	# --------------------------------------------------------
	# Slide movement
	# --------------------------------------------------------

	if slide.active:

		move_and_slide()


		# No llamamos _update_animation_state aquí.
		# De lo contrario Sprint/Idle pisarían Slide.


		_send_state(
			false,
			false
		)


		return


	# --------------------------------------------------------
	# Normal Movement
	# --------------------------------------------------------

	var move_input: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)


	var direction: Vector3 = (
		transform.basis
		* Vector3(
			move_input.x,
			0.0,
			move_input.y
		)
	)


	# --------------------------------------------------------
	# Sprint
	# --------------------------------------------------------

	var is_sprinting: bool = \
		Input.is_action_pressed("sprint")


	if is_sprinting:
		move_speed = (
			max_move_speed
			* SPRINT_SPEED_MULTIPLIER
		)

	else:
		move_speed = max_move_speed


	# --------------------------------------------------------
	# Acceleration
	# --------------------------------------------------------

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


	update_animations(
		is_sprinting
	)


	# --------------------------------------------------------
	# Landing & Animation detection
	# --------------------------------------------------------

	var just_landed: bool = (
		not was_on_floor
		and is_on_floor()
	)


	var moving: bool = (
		move_input.length_squared()
		> 0.01
	)


	var on_floor: bool = is_on_floor()


	_update_animation_state(
		moving,
		on_floor,
		just_jumped,
		just_landed,
		onledge
	)


	# --------------------------------------------------------
	# Network Sync
	# --------------------------------------------------------

	_send_state(
		just_jumped,
		onledge
	)


# ============================================================
# Ledge / Obstacle Detection
# ============================================================

var ledge_point: Vector3 = Vector3.ZERO


func raycast_detect_ledge() -> bool:

	onledge = (
		ray_01.is_colliding()
		and not ray_02.is_colliding()
	)


	if onledge:
		ledge_point = \
			ray_01.get_collision_point()


	return onledge


# ============================================================
# Climb
# ============================================================

func start_climb() -> void:
	is_climbing = true


	# Cualquier Slide_Exit pendiente deja de tener prioridad.
	_slide_exit_playing = false


	var forward: Vector3 = (
		global_transform.basis
		* Vector3(
			0,
			0,
			climb_forward_offset
		)
	)


	var target_pos: Vector3 = Vector3(
		global_position.x + forward.x,
		ledge_point.y + climb_up_offset,
		global_position.z + forward.z
	)


	var climb_duration: float = 0.5


	var playback_speed: float = (
		ANIM_CLIMB_DURATION
		/ climb_duration
	)


	climb_anim_player.play(
		ANIM_CLIMB,
		-1.0,
		playback_speed
	)


	var tween: Tween = create_tween()


	tween.tween_property(
		self,
		"global_position",
		target_pos,
		climb_duration
	)


	tween.finished.connect(
		_on_climb_finished
	)


func _on_climb_finished() -> void:
	is_climbing = false

	velocity = Vector3.ZERO

	move_and_slide()

	climb_cooldown = 0.5


# ============================================================
# Slide Animations
# ============================================================

func start_slide_animation() -> void:

	_slide_exit_playing = false


	# Paramos las animaciones normales para que no
	# pisen el slide.
	anim_player.stop()
	animation_player.stop()


	climb_anim_player.play(
		ANIM_SLIDE_START
	)


func stop_slide_animation(
	play_exit: bool = true
) -> void:

	if not play_exit:

		_slide_exit_playing = false


		if (
			climb_anim_player.current_animation
			== ANIM_SLIDE_START
			or
			climb_anim_player.current_animation
			== ANIM_SLIDE
			or
			climb_anim_player.current_animation
			== ANIM_SLIDE_EXIT
		):
			climb_anim_player.stop()


		return


	# Si ya está haciendo Slide_Exit,
	# no lo reiniciamos.
	if (
		climb_anim_player.current_animation
		== ANIM_SLIDE_EXIT
	):

		_slide_exit_playing = true
		return


	if (
		climb_anim_player.current_animation
		== ANIM_SLIDE_START
		or
		climb_anim_player.current_animation
		== ANIM_SLIDE
	):

		_slide_exit_playing = true


		climb_anim_player.play(
			ANIM_SLIDE_EXIT
		)


func _on_action_animation_finished(
	anim_name: StringName
) -> void:

	# --------------------------------------------------------
	# Slide_Start terminó -> Slide loop
	# --------------------------------------------------------

	if anim_name == ANIM_SLIDE_START:

		var should_continue_slide: bool


		if is_multiplayer_authority():
			should_continue_slide = slide.active

		else:
			should_continue_slide = _remote_is_sliding


		if should_continue_slide:

			climb_anim_player.play(
				ANIM_SLIDE
			)


		return


	# --------------------------------------------------------
	# Slide_Exit terminó
	# --------------------------------------------------------

	if anim_name == ANIM_SLIDE_EXIT:

		_slide_exit_playing = false

		return


# ============================================================
# Animation state
# ============================================================

func update_animations(
	is_sprinting: bool
) -> void:

	# SprintAnimation no debe interferir
	# con Slide ni Slide_Exit.
	if (
		slide.active
		or _slide_exit_playing
	):
		animation_player.stop()
		return


	var is_moving: bool = Vector2(
		velocity.x,
		velocity.z
	).length() > 0.2


	if (
		is_sprinting
		and is_moving
	):
		animation_player.play(
			"SprintAnimation"
		)

	else:
		animation_player.stop()


func _update_animation_state(
	moving: bool,
	on_floor: bool,
	just_jumped: bool,
	just_landed: bool,
	on_ledge: bool = false
) -> void:

	# --------------------------------------------------------
	# 1. Climbing
	# --------------------------------------------------------

	if on_ledge:

		_slide_exit_playing = false


		anim_player.stop()
		animation_player.stop()


		if (
			climb_anim_player.current_animation
			!= ANIM_CLIMB
			or not climb_anim_player.is_playing()
		):

			climb_anim_player.play(
				ANIM_CLIMB
			)


		return


	# --------------------------------------------------------
	# Slide
	# --------------------------------------------------------

	var visual_slide_active: bool


	if is_multiplayer_authority():
		visual_slide_active = slide.active

	else:
		visual_slide_active = _remote_is_sliding


	if (
		visual_slide_active
		or _slide_exit_playing
	):

		anim_player.stop()
		animation_player.stop()

		return


	# --------------------------------------------------------
	# 2. Landing
	# --------------------------------------------------------

	if just_landed:

		if moving:
			play_anim(
				ANIM_SPRINT
			)

		else:
			play_anim(
				ANIM_JUMP_LAND,
				LAND_ANIMATION_SPEED
			)


		return


	# --------------------------------------------------------
	# 3. Jump start
	# --------------------------------------------------------

	if just_jumped:

		play_anim(
			ANIM_JUMP_START
		)

		return


	# --------------------------------------------------------
	# 4. Airborne
	# --------------------------------------------------------

	if not on_floor:

		if (
			anim_player.current_animation
			== ANIM_JUMP_START
			and anim_player.is_playing()
		):
			return


		play_anim(
			ANIM_JUMP_LOOP
		)

		return


	# --------------------------------------------------------
	# 5. Ground movement
	# --------------------------------------------------------

	if moving:

		play_anim(
			ANIM_SPRINT
		)

		return


	# --------------------------------------------------------
	# 6. Finish landing transition
	# --------------------------------------------------------

	if (
		anim_player.current_animation
		== ANIM_JUMP_LAND
		and anim_player.is_playing()
	):
		return


	# --------------------------------------------------------
	# 7. Idle
	# --------------------------------------------------------

	play_anim(
		ANIM_IDLE
	)


func play_anim(
	animation: StringName,
	speed: float = 1.0
) -> void:

	if (
		anim_player.current_animation
		== animation
	):
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
	Debug.log(
		name,
		10
	)


# ============================================================
# Grapple
# ============================================================

func _handle_grapple_input() -> void:

	if not Input.is_action_just_pressed(
		"grapple"
	):
		return


	if (
		role != Statics.Role.gancho
		and not grapple.is_pulling()
	):

		Debug.log(
			"Rol: %s. El gancho es solo de gancho."
			% Statics.get_role_name(role)
		)

		return


	if grapple.is_pulling():
		grapple.cancel()
		return


	if is_climbing:
		return


	if grapple.is_on_cooldown():

		Debug.log(
			"Gancho en espera"
		)

		return


	if not grapple.try_launch(
		role,
		camera_3d,
		self
	):

		Debug.log(
			"Sin superficie. Apuntá a un bloque o pared."
		)


# ============================================================
# Player Data
# ============================================================

func _on_player_data_updated(
	id: int
) -> void:

	if id != get_multiplayer_authority():
		return


	var data: Statics.PlayerData = \
		Game.instance.get_player(id)


	if data == null:
		return


	role = data.role

	_refresh_role_label()


	if role != Statics.Role.gancho:
		grapple.cancel()


# ============================================================
# Crosshair
# ============================================================

func _add_crosshair() -> void:

	var layer: CanvasLayer = \
		CanvasLayer.new()


	layer.name = "Crosshair"
	layer.layer = 20


	var root: Control = \
		Control.new()


	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	root.mouse_filter = \
		Control.MOUSE_FILTER_IGNORE


	layer.add_child(root)


	var color: Color = \
		Color(
			1,
			1,
			1,
			0.95
		)


	root.add_child(
		_crosshair_bar(
			color,
			-9.0,
			9.0,
			-1.0,
			1.0
		)
	)


	root.add_child(
		_crosshair_bar(
			color,
			-1.0,
			1.0,
			-9.0,
			9.0
		)
	)


	add_child(layer)


func _crosshair_bar(
	color: Color,
	left: float,
	right: float,
	top: float,
	bottom: float
) -> ColorRect:

	var bar: ColorRect = \
		ColorRect.new()


	bar.color = color


	bar.mouse_filter = \
		Control.MOUSE_FILTER_IGNORE


	bar.set_anchors_preset(
		Control.PRESET_CENTER
	)


	bar.offset_left = left
	bar.offset_right = right
	bar.offset_top = top
	bar.offset_bottom = bottom


	return bar


# ============================================================
# Tag HUD
# ============================================================

func _add_tag_hud() -> void:

	var layer: CanvasLayer = \
		CanvasLayer.new()


	layer.name = "TagHUD"
	layer.layer = 20


	_tag_timer_label = \
		Label.new()


	_tag_timer_label.add_theme_font_size_override(
		"font_size",
		32
	)


	_tag_timer_label.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)


	_tag_timer_label.offset_left = -100
	_tag_timer_label.offset_top = 20

	_tag_timer_label.visible = false


	layer.add_child(
		_tag_timer_label
	)


	add_child(layer)


# ============================================================
# Tag
# ============================================================

func _on_tag_zone_body_entered(
	body: Node3D
) -> void:

	if not is_multiplayer_authority():
		return


	if (
		TagGame.it_player_id
		!= get_multiplayer_authority()
	):
		return


	if (
		body == self
		or not body is Player
	):
		return


	TagGame.request_tag.rpc_id(
		1,
		body.get_multiplayer_authority()
	)


func _on_player_exploded(
	player_id: int
) -> void:

	if (
		player_id
		!= get_multiplayer_authority()
	):
		return


	set_physics_process(false)
	set_process(false)

	visible = false


# ============================================================
# Role Label
# ============================================================

func _refresh_role_label() -> void:

	var role_name: String = \
		Statics.get_role_name(role)


	label_3d.text = (
		"%s · %s"
		% [
			_player_name,
			role_name
		]
	)


	if is_multiplayer_authority():

		Game.instance.player_id.text = (
			"Rol: %s"
			% role_name
		)

		Game.instance.player_id.show()


# ============================================================
# Network State
# ============================================================

func _send_state(
	just_jumped: bool,
	ledge_flag: bool
) -> void:

	send_data.rpc(
		global_position,
		global_rotation,
		is_on_floor(),
		just_jumped,
		ledge_flag,
		grapple.is_rope_visible(),
		grapple.rope_end(),
		slide.active
	)


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
	on_ledge: bool,
	grapple_visible: bool,
	grapple_point: Vector3,
	is_sliding: bool
) -> void:

	_target_position = pos
	_target_rotation = rot

	_remote_is_on_floor = on_floor
	_remote_onledge = on_ledge

	_remote_grapple_visible = \
		grapple_visible

	_remote_grapple_point = \
		grapple_point

	_remote_is_sliding = \
		is_sliding


	if just_jumped:
		_remote_just_jumped = true
