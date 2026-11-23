class_name SpectatorCamera
extends Node3D
## Modo espectador: cámara en tercera persona que sigue a los jugadores vivos.
## Se agrega como hijo del jugador muerto (solo en su propio cliente).
##   Mouse: girar la cámara
##   Clic izquierdo / derecho: siguiente / anterior jugador

const MOUSE_SENS := 0.003
const DISTANCE := 6.0
const HEIGHT := 1.6
const FOLLOW_SPEED := 10.0
const MIN_PITCH := -80.0
const MAX_PITCH := 30.0

var _me: Node
var _target: Node3D
var _yaw := 0.0
var _pitch := -0.35

var _arm: SpringArm3D
var _cam: Camera3D
var _name_label: Label


func _ready() -> void:
	top_level = true  # no hereda la posición del jugador muerto
	_me = get_parent()

	_arm = SpringArm3D.new()
	_arm.spring_length = DISTANCE
	_arm.margin = 0.2
	add_child(_arm)

	_cam = Camera3D.new()
	_arm.add_child(_cam)
	_cam.current = true

	if _me is Node3D:
		_yaw = (_me as Node3D).global_rotation.y

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_ui()
	_switch_target(1)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(
			_pitch - event.relative.y * MOUSE_SENS,
			deg_to_rad(MIN_PITCH),
			deg_to_rad(MAX_PITCH)
		)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_switch_target(1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_switch_target(-1)


func _process(delta: float) -> void:
	# Si el que estábamos mirando explotó o se desconectó, pasamos al siguiente
	if not _is_valid(_target):
		_switch_target(1)

	if _target:
		var goal := _target.global_position + Vector3.UP * HEIGHT
		global_position = global_position.lerp(goal, 1.0 - exp(-FOLLOW_SPEED * delta))

	rotation = Vector3(_pitch, _yaw, 0.0)


# ---------------------------------------------------------------- Objetivos

func _get_targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p in get_tree().get_nodes_in_group("players"):
		if p != _me and p is Node3D and _is_valid(p):
			out.append(p)
	return out


func _is_valid(node: Node3D) -> bool:
	return node != null and is_instance_valid(node) and node.is_inside_tree() and node.visible


func _switch_target(direction: int) -> void:
	var targets := _get_targets()
	if targets.is_empty():
		_target = null
		_name_label.text = "Sin jugadores para mirar"
		return

	var was_empty := _target == null or not is_instance_valid(_target)
	var i := targets.find(_target)
	i = 0 if i == -1 else wrapi(i + direction, 0, targets.size())
	_target = targets[i]

	_arm.clear_excluded_objects()
	_arm.add_excluded_object(_target.get_rid())

	if was_empty:
		global_position = _target.global_position + Vector3.UP * HEIGHT

	var target_name: String = str(_target.get("_player_name"))
	_name_label.text = "ESPECTANDO: %s" % target_name.to_upper()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var font: Font = null
	if ResourceLoader.exists(TagCountdownHUD.FONT_PATH):
		font = load(TagCountdownHUD.FONT_PATH)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	layer.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var title := _make_label("EXPLOTASTE", 26, Color("#FF3B30"), font)
	vbox.add_child(title)

	_name_label = _make_label("", 40, Color.WHITE, font)
	vbox.add_child(_name_label)

	var hint := _make_label("Clic izquierdo / derecho para cambiar de jugador", 18, Color(1, 1, 1, 0.75), null)
	vbox.add_child(hint)


func _make_label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l
