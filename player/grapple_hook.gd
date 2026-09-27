class_name GrappleHook
extends Node


@export var max_range: float = 20.0
@export var min_range: float = 1.0
@export var pull_speed: float = 30.0
@export var cooldown: float = 1.4
@export var max_duration: float = 1.2
@export var retract_speed: float = 45.0
@export var stop_distance: float = 0.85
@export var arrive_distance: float = 0.4
@export var blocked_cancel_time: float = 0.22
@export var origin_height: float = 1.2
@export_flags_3d_physics var collision_mask: int = 1
@export var rope_radius: float = 0.035
@export var rope_color: Color = Color(0.93, 0.78, 0.32, 1.0)


enum State {
	IDLE,
	PULLING,
	RETRACTING,
}


var state: State = State.IDLE
var hit_point: Vector3 = Vector3.ZERO
var pull_target: Vector3 = Vector3.ZERO

var _cooldown_left: float = 0.0
var _pull_time: float = 0.0
var _stuck_time: float = 0.0
var _last_distance: float = 0.0
var _retract_tip: Vector3 = Vector3.ZERO

var _rope: MeshInstance3D
var _cylinder: CylinderMesh


func _ready() -> void:
	_ensure_input_action()
	_build_rope()


func is_on_cooldown() -> bool:
	return _cooldown_left > 0.0


func origin_from(body: Node3D) -> Vector3:
	return body.global_position + Vector3(0.0, origin_height, 0.0)


func is_pulling() -> bool:
	return state == State.PULLING


func is_rope_visible() -> bool:
	return state != State.IDLE


func rope_end() -> Vector3:
	if state == State.PULLING:
		return hit_point
	if state == State.RETRACTING:
		return _retract_tip
	return Vector3.ZERO


func tick_cooldown(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func tick_retract(origin: Vector3, delta: float) -> void:
	if state != State.RETRACTING:
		return

	var to_origin: Vector3 = origin - _retract_tip
	var distance: float = to_origin.length()
	var step: float = retract_speed * delta
	if distance <= step:
		state = State.IDLE
		return

	_retract_tip += to_origin / distance * step


func try_launch(role: Statics.Role, camera: Camera3D, body: Node3D) -> bool:
	if role != Statics.Role.gancho:
		return false
	if state == State.PULLING or _cooldown_left > 0.0:
		return false
	if camera == null:
		return false

	var origin: Vector3 = origin_from(body)
	var hit: Dictionary = _cast_from_camera(camera, body, origin)
	if hit.is_empty():
		return false

	var collider: Object = hit["collider"]
	if not _is_valid_target(collider):
		return false

	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var distance: float = origin.distance_to(point)
	if distance > max_range or distance < min_range:
		return false
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()

	var clearance: float = stop_distance if normal.y <= 0.55 else minf(stop_distance, 0.2)
	hit_point = point
	pull_target = point + normal * clearance
	_pull_time = 0.0
	_stuck_time = 0.0
	_last_distance = body.global_position.distance_to(pull_target)
	state = State.PULLING
	return true


func advance_pull(body: CharacterBody3D, delta: float) -> bool:
	if state != State.PULLING:
		return false

	_pull_time += delta
	var to_target: Vector3 = pull_target - body.global_position
	var distance: float = to_target.length()

	if distance <= arrive_distance or distance < 0.001 or _pull_time >= max_duration:
		_end_pull(body)
		return false

	var progress: float = _last_distance - distance
	if _pull_time > 0.08 and progress < 0.02:
		_stuck_time += delta
		if _stuck_time >= blocked_cancel_time:
			_end_pull(body)
			return false
	else:
		_stuck_time = 0.0

	_last_distance = distance
	body.velocity = to_target / distance * pull_speed
	return true


func cancel() -> void:
	if state != State.PULLING:
		return
	_begin_retract()


func draw(origin: Vector3) -> void:
	if _rope == null:
		return
	if state == State.IDLE:
		_rope.visible = false
		return
	_place_rope(origin, rope_end())


func show_synced(origin: Vector3, active: bool, point: Vector3) -> void:
	if _rope == null:
		return
	if not active:
		_rope.visible = false
		return
	_place_rope(origin, point)


func _end_pull(body: CharacterBody3D) -> void:
	body.velocity = Vector3.ZERO
	_begin_retract()


func _begin_retract() -> void:
	_retract_tip = hit_point
	_cooldown_left = cooldown
	state = State.RETRACTING


func _is_valid_target(collider: Object) -> bool:
	if collider == null or collider is CharacterBody3D:
		return false
	return collider is PhysicsBody3D


func _cast_from_camera(camera: Camera3D, body: Node3D, origin: Vector3) -> Dictionary:
	var world: World3D = body.get_world_3d()
	if world == null:
		return {}

	var forward: Vector3 = -camera.global_basis.z
	if forward.length_squared() < 0.0001:
		return {}
	forward = forward.normalized()

	var from: Vector3 = camera.global_position
	var reach: float = max_range + from.distance_to(origin)
	var exclude: Array[RID] = []
	var physics_body: CollisionObject3D = body as CollisionObject3D
	if physics_body:
		exclude.append(physics_body.get_rid())

	var mask: int = collision_mask if collision_mask != 0 else 1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from,
		from + forward * reach,
		mask,
		exclude
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	var point: Vector3 = hit["position"]
	var distance: float = origin.distance_to(point)
	if distance > max_range or distance < min_range:
		return {}
	return hit


func _ensure_input_action() -> void:
	if not InputMap.has_action("grapple"):
		InputMap.add_action("grapple", 0.5)

	var has_key: bool = false
	var has_mouse: bool = false
	for event: InputEvent in InputMap.action_get_events("grapple"):
		if event is InputEventKey and event.physical_keycode == KEY_E:
			has_key = true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_mouse = true

	if not has_key:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("grapple", key)
	if not has_mouse:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("grapple", mouse)


func _build_rope() -> void:
	_cylinder = CylinderMesh.new()
	_cylinder.top_radius = rope_radius
	_cylinder.bottom_radius = rope_radius
	_cylinder.height = 1.0
	_cylinder.radial_segments = 6

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = rope_color
	material.emission_enabled = true
	material.emission = rope_color
	material.emission_energy_multiplier = 1.4

	_rope = MeshInstance3D.new()
	_rope.name = "GrappleRope"
	_rope.mesh = _cylinder
	_rope.material_override = material
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)


func _place_rope(origin: Vector3, tip: Vector3) -> void:
	var offset: Vector3 = tip - origin
	var length: float = offset.length()
	if length < 0.05:
		_rope.visible = false
		return

	_cylinder.height = length
	var y_axis: Vector3 = offset / length
	var helper: Vector3 = Vector3.RIGHT if absf(y_axis.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis: Vector3 = helper.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	_rope.visible = true
	_rope.global_transform = Transform3D(
		Basis(x_axis, y_axis, z_axis),
		origin + offset * 0.5
	)
