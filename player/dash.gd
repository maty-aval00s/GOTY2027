class_name DashController
extends Node


signal meter_changed(
	value: float,
	maximum: float,
	whole_charges: int
)


@export var speed: float = 80.0
@export var duration: float = 0.2
@export var cooldown: float = 0.1

# N: cantidad máxima de dashes guardados.
@export var max_charges: int = 5

# Segundos para recuperar una carga.
@export var recharge_time_per_charge: float = 3.0


enum State {
	IDLE,
	DASHING,
}


var state: State = State.IDLE

var _charges: int = 0
var _recharge_progress: float = 0.0

var _cooldown_left: float = 0.0
var _time_left: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _velocity_before_dash: Vector3 = Vector3.ZERO


func _ready() -> void:
	max_charges = maxi(max_charges, 1)
	_charges = max_charges
	_emit_meter_changed()


func is_dashing() -> bool:
	return state == State.DASHING


func is_on_cooldown() -> bool:
	return _cooldown_left > 0.0


func has_charges() -> bool:
	return _charges > 0


func meter_value() -> float:
	var partial_charge: float = 0.0

	if (
		_charges < max_charges
		and recharge_time_per_charge > 0.0
	):
		partial_charge = (
			_recharge_progress
			/ recharge_time_per_charge
		)

	return float(_charges) + partial_charge


func tick(delta: float) -> void:
	_tick_cooldown(delta)
	_tick_recharge(delta)


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

	if not has_charges():
		return false

	_direction = -body.global_transform.basis.z
	_direction.y = 0.0

	if _direction.length_squared() < 0.0001:
		return false

	_direction = _direction.normalized()

	_velocity_before_dash = body.velocity
	_velocity_before_dash.y = 0.0

	_charges -= 1
	_emit_meter_changed()

	_time_left = duration
	state = State.DASHING

	return true


func advance(
	body: CharacterBody3D,
	delta: float
) -> bool:

	if not is_dashing():
		return false

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


func _tick_cooldown(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(
			_cooldown_left - delta,
			0.0
		)


func _tick_recharge(delta: float) -> void:
	if _charges >= max_charges:
		return

	if recharge_time_per_charge <= 0.0:
		_charges = max_charges
		_recharge_progress = 0.0
		_emit_meter_changed()
		return

	_recharge_progress += delta

	while (
		_recharge_progress >= recharge_time_per_charge
		and _charges < max_charges
	):
		_recharge_progress -= recharge_time_per_charge
		_charges += 1

	if _charges >= max_charges:
		_recharge_progress = 0.0

	_emit_meter_changed()


func _end_dash(
	body: CharacterBody3D
) -> void:

	# El slide recibe la velocidad previa, nunca la del dash.
	body.velocity.x = _velocity_before_dash.x
	body.velocity.z = _velocity_before_dash.z

	state = State.IDLE
	_cooldown_left = cooldown


func _emit_meter_changed() -> void:
	meter_changed.emit(
		meter_value(),
		float(max_charges),
		_charges
	)
