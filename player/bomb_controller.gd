class_name BombController
extends Node


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

	if projectile_scene == null or camera == null or body == null:
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

	# El dueño crea su proyectil local y es el único que informa el impacto.
	if not _spawn_projectile(
		origin,
		initial_velocity,
		body,
		true
	):
		return false

	_cooldown_left = cooldown

	# El resto de peers crea la representación visual/física remota.
	_spawn_bomb_on_peers.rpc(
		origin,
		initial_velocity
	)

	return true


func _spawn_projectile(
	origin: Vector3,
	initial_velocity: Vector3,
	owner_body: CharacterBody3D,
	report_explosion: bool
) -> bool:
	if projectile_scene == null or owner_body == null:
		return false

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		push_error("BombController: no hay una escena actual para agregar el proyectil.")
		return false

	var projectile: BombProjectile = (
		projectile_scene.instantiate()
		as BombProjectile
	)
	if projectile == null:
		push_error("BombController: projectile_scene no instancia un BombProjectile.")
		return false

	scene_root.add_child(projectile)
	projectile.global_position = origin

	if report_explosion:
		projectile.impacted.connect(
			_on_projectile_impacted
		)

	projectile.launch(
		initial_velocity,
		owner_body
	)

	return true


@rpc("authority", "call_remote", "reliable")
func _spawn_bomb_on_peers(
	origin: Vector3,
	initial_velocity: Vector3
) -> void:
	var owner_body: CharacterBody3D = get_parent() as CharacterBody3D
	if owner_body == null:
		push_error("BombController debe ser hijo de un CharacterBody3D.")
		return

	_spawn_projectile(
		origin,
		initial_velocity,
		owner_body,
		false
	)


func _on_projectile_impacted(
	explosion_center: Vector3
) -> void:
	if not is_multiplayer_authority():
		return

	_apply_explosion_on_peers.rpc(
		explosion_center,
		blast_radius,
		blast_force,
		falloff_exponent,
		player_center_height
	)


@rpc("authority", "call_local", "reliable")
func _apply_explosion_on_peers(
	explosion_center: Vector3,
	radius: float,
	force: float,
	exponent: float,
	center_height: float
) -> void:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player == null or not player.is_multiplayer_authority():
			continue

		player.receive_explosion_impulse(
			explosion_center,
			radius,
			force,
			exponent,
			center_height
		)
