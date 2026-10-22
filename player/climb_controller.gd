class_name ClimbController
extends Node

@export var forward_offset: float = -0.9
@export var up_offset: float = 0.3
var cooldown: float = 0.5
var cooldown_left: float = 0.0
var is_climbing: bool = false

# signals
signal climb_started(duration: float)
signal climb_finished

func start_climb(body: CharacterBody3D, ledge_point: Vector3) -> void:
	is_climbing = true
	var forward: Vector3 = (body.global_transform.basis * Vector3(0, 0, forward_offset))
	var target_pos: Vector3 = Vector3(
		body.global_position.x + forward.x,
		ledge_point.y + up_offset,
		body.global_position.z + forward.z
	)

	var duration: float = 0.5
	climb_started.emit(duration)
	var tween: Tween = create_tween()

	tween.tween_property(self, "global_position", target_pos, duration)
	tween.finished.connect(_on_climb_finished)


func _on_climb_finished(body: CharacterBody3D, ledge_point: Vector3) -> void:
	is_climbing = false
	cooldown_left = cooldown

	body.velocity = Vector3.ZERO
	body.move_and_slide()
	
	climb_finished.emit()

	
