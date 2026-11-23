class_name ThrowableComponent
extends Node

@export var throw_speed: float = 14.0
@export var upward_speed: float = 3.0
@export_range(0.0, 1.0) var velocity_inheritance: float = 0.75

# ejemplo de uso:
# throwable.throw(barrel_body, -camera.global_basis.z, player.velocity)
func throw(body: RigidBody3D, direction: Vector3, source_velocity: Vector3 = Vector3.ZERO) -> bool:
	if body == null or direction.is_zero_approx(): return false
	body.sleeping = false
	body.linear_velocity = direction.normalized() * throw_speed + Vector3.UP * upward_speed + source_velocity * velocity_inheritance
	return true
