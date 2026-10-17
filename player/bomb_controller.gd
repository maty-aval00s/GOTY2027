class_name BombController
extends Node


signal bomb_launched(
	origin: Vector3,
	initial_velocity: Vector3
)

signal bomb_exploded(
	center: Vector3,
	radius: float,
	force: float,
	falloff_exponent: float,
	player_center_height: float
)


@export var projectile_scene: PackedScene

@export var launch_speed: float = 27.0
@export var cooldown: float = 1.4

@export var spawn_height: float = 1.2
@export var spawn_forward_offset: float = 0.9

@export var blast_radius: float = 6.0
@export var blast_force: float = 42.0
@export var falloff_exponent: float = 2.0
@export var player_center_height: float = 1.0


var _cooldown_left: float = 0.0


func tick(delta: float) -> void:
	_cooldown_left = maxf(
		_cooldown_left - delta,
		0.0
	)


func is_on_cooldown() -> bool:
	return _cooldown_left > 0.0


func try_launch(
	role: Statics.Role,
	camera: Camera3D,
	body: CharacterBody3D
) -> bool:

	if role != Statics.Role.doble_vida:
		return false

	if is_on_cooldown():
		return false

	if projectile_scene == null or camera == null:
		return false

	var direction: Vector3 = -camera.global_basis.z

	if direction.length_squared() < 0.0001:
		return false

	direction = direction.normalized()

	var origin: Vector3 = (
		body.global_position
		+ Vector3.UP * spawn_height
		+ direction * spawn_forward_offset
	)

	var initial_velocity: Vector3 = (
		direction * launch_speed
		+ body.velocity * 0.25
	)

	_spawn_projectile(
		origin,
		initial_velocity,
		body,
		true
	)

	_cooldown_left = cooldown

	bomb_launched.emit(
		origin,
		initial_velocity
	)

	return true


func spawn_remote(
	origin: Vector3,
	initial_velocity: Vector3,
	owner_body: CharacterBody3D
) -> void:

	_spawn_projectile(
		origin,
		initial_velocity,
		owner_body,
		false
	)


func _spawn_projectile(
	origin: Vector3,
	initial_velocity: Vector3,
	owner_body: CharacterBody3D,
	report_explosion: bool
) -> void:

	var projectile: BombProjectile = (
		projectile_scene.instantiate()
		as BombProjectile
	)

	get_tree().current_scene.add_child(projectile)

	projectile.global_position = origin

	if report_explosion:
		projectile.impacted.connect(
			_on_projectile_impacted
		)

	projectile.launch(
		initial_velocity,
		owner_body
	)


func _on_projectile_impacted(
	point: Vector3
) -> void:

	bomb_exploded.emit(
		point,
		blast_radius,
		blast_force,
		falloff_exponent,
		player_center_height
	)
