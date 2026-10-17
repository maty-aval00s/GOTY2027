class_name DashController
extends Node


@export var speed: float = 42.0
@export var duration: float = 0.18
@export var cooldown: float = 1.0


enum State {
	IDLE,
	DASHING,
}


var state: State = State.IDLE

var _cooldown_left: float = 0.0
var _time_left: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _velocity_before_dash: Vector3 = Vector3.ZERO


func is_dashing() -> bool:
	return state == State.DASHING


func is_on_cooldown() -> bool:
	return _cooldown_left > 0.0


func tick_cooldown(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(
			_cooldown_left - delta,
			0.0
		)


func try_start(
	role: Statics.Role,
	body: CharacterBody3D
) -> bool:

	if role != Statics.Role.rapido:
		return false

	if state != State.IDLE:
		return false

	if is_on_cooldown():
		return false

	# Frente horizontal del jugador.
	_direction = -body.global_transform.basis.z
	_direction.y = 0.0

	if _direction.length_squared() < 0.0001:
		return false

	_direction = _direction.normalized()

	# Guardamos solo la velocidad horizontal previa.
	_velocity_before_dash = body.velocity
	_velocity_before_dash.y = 0.0

	_time_left = duration
	state = State.DASHING

	return true


# Devuelve true mientras Player debe ejecutar move_and_slide()
# usando la velocidad del dash.
func advance(
	body: CharacterBody3D,
	delta: float
) -> bool:

	if not is_dashing():
		return false

	# El dash ya terminó en el frame anterior.
	if _time_left <= 0.0:
		_end_dash(body)
		return false

	body.velocity.x = _direction.x * speed
	body.velocity.z = _direction.z * speed

	_time_left = maxf(
		_time_left - delta,
		0.0
	)

	return true


func cancel(
	body: CharacterBody3D
) -> void:

	if not is_dashing():
		return

	_end_dash(body)


func _end_dash(
	body: CharacterBody3D
) -> void:

	# Restauramos la velocidad que tenía antes de dashear.
	# El slide nunca recibe la velocidad de `speed`.
	body.velocity.x = _velocity_before_dash.x
	body.velocity.z = _velocity_before_dash.z

	state = State.IDLE
	_cooldown_left = cooldown
