class_name SlideController
extends Node


@export var min_slide_speed: float = 8.0
@export var start_speed_multiplier: float = 1.15
@export var friction: float = 12.0
@export var max_duration: float = 1.2
@export var cooldown_duration: float = 0.4


var active: bool = false
var cooldown: float = 0.0

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _timer: float = 0.0


func tick_cooldown(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(cooldown - delta, 0.0)


func is_on_cooldown() -> bool:
	return cooldown > 0.0


func can_start(player: CharacterBody3D) -> bool:
	if active:
		return false

	if is_on_cooldown():
		return false

	if not player.is_on_floor():
		return false

	var horizontal_velocity := Vector3(
		player.velocity.x,
		0.0,
		player.velocity.z
	)

	return horizontal_velocity.length() >= min_slide_speed


func start(player: CharacterBody3D) -> void:
	if not can_start(player):
		return
	print("slide start")
	print("current speed: ", player.velocity)
	var horizontal_velocity := Vector3(
		player.velocity.x,
		0.0,
		player.velocity.z
	)

	_direction = horizontal_velocity.normalized()
	_speed = horizontal_velocity.length() * start_speed_multiplier

	_timer = max_duration
	active = true


func stop() -> void:
	if not active:
		return

	active = false
	_timer = 0.0
	_speed = 0.0

	cooldown = cooldown_duration


func tick(player: CharacterBody3D, delta: float) -> void:
	if not active:
		return

	# Si dejamos el suelo, termina el slide.
	if not player.is_on_floor():
		stop()
		return

	_timer -= delta

	if _timer <= 0.0:
		stop()
		return

	# Frenado progresivo.
	_speed = move_toward(
		_speed,
		0.0,
		friction * delta
	)

	# Terminar cuando ya casi no queda velocidad.
	if _speed < min_slide_speed * 0.3:
		stop()
		return

	player.velocity.x = _direction.x * _speed
	player.velocity.z = _direction.z * _speed
