class_name BombProjectile
extends CharacterBody3D


signal impacted(point: Vector3)


@export var gravity: float = 30.0
@export var life_time: float = 4.0
@export var explosion_depth: float = 0.45

# Capas con las que la bomba puede chocar.
# Layer 1 = mundo, según tu configuración actual.
@export_flags_3d_physics var world_collision_mask: int = 1


var _time_left: float = 0.0
var _active: bool = false


func _ready() -> void:
	# La bomba puede detectar el mundo, pero no debe ser
	# detectada por raycasts de escalada ni otros jugadores.
	collision_layer = 0
	collision_mask = world_collision_mask


func launch(
	initial_velocity: Vector3,
	owner_body: CollisionObject3D
) -> void:

	velocity = initial_velocity
	_time_left = life_time
	_active = true

	if owner_body:
		add_collision_exception_with(owner_body)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	velocity += Vector3.DOWN * gravity * delta

	var collision: KinematicCollision3D = move_and_collide(
		velocity * delta
	)

	_time_left -= delta

	if collision:
		_explode_at(
			collision.get_position(),
			collision.get_normal()
		)
		return

	if _time_left <= 0.0:
		queue_free()


func _explode_at(
	contact_point: Vector3,
	surface_normal: Vector3
) -> void:

	_active = false

	var normal: Vector3 = surface_normal.normalized()

	# En un piso, la normal apunta arriba.
	# Restarla mueve el centro de explosión bajo el suelo.
	var explosion_center: Vector3 = (
		contact_point
		- normal * explosion_depth
	)

	impacted.emit(explosion_center)

	queue_free()
