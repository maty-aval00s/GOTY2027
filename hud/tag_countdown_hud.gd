class_name TagCountdownHUD
extends CanvasLayer
## Contador de la pinta: esquina superior izquierda, grande y llamativo.
## Solo se muestra en la pantalla del jugador que la lleva.
## Uso:
##   var hud := TagCountdownHUD.new()
##   add_child(hud)
##   hud.setup(nodo_con_el_script_de_la_pinta)

# Si descargas una fuente (ej. "Bangers" o "Luckiest Guy" de Google Fonts),
# ponla en esta ruta. Si no existe, usa una fuente gruesa del sistema.
const FONT_PATH := "res://fonts/Bangers-Regular.ttf"

const COLOR_NORMAL := Color("#FFD23F")   # amarillo
const COLOR_DANGER := Color("#FF3B30")   # rojo
const DANGER_TIME := 10.0                # bajo esto: rojo + decimales + latido
const MARGIN := Vector2(24, 24)

var manager: Node

var _panel: PanelContainer
var _style: StyleBoxFlat
var _title: Label
var _time_label: Label
var _local_time := 0.0
var _last_synced := -1.0
var _pulse: Tween
var _danger := false


func _ready() -> void:
	layer = 10
	_build_ui()
	_panel.visible = false


func setup(tag_manager: Node) -> void:
	manager = tag_manager
	manager.it_changed.connect(_on_it_changed)
	manager.player_exploded.connect(func(_id: int) -> void: _hide())
	manager.game_over.connect(func(_id: int) -> void: _hide())


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var font := _load_font()

	_panel = PanelContainer.new()
	_panel.position = MARGIN
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.07, 0.07, 0.11, 0.85)
	_style.set_corner_radius_all(18)
	_style.set_border_width_all(5)
	_style.border_color = COLOR_NORMAL
	_style.content_margin_left = 28
	_style.content_margin_right = 28
	_style.content_margin_top = 10
	_style.content_margin_bottom = 14
	_style.shadow_color = Color(0, 0, 0, 0.55)
	_style.shadow_size = 10
	_style.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", _style)
	# Para que el latido escale desde el centro
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size / 2.0)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", -6)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "¡LA LLEVAS!"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(_title)

	_time_label = Label.new()
	_time_label.text = "0"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.custom_minimum_size.x = 190  # evita que el panel cambie de ancho
	_time_label.add_theme_font_override("font", font)
	_time_label.add_theme_font_size_override("font_size", 84)
	_time_label.add_theme_color_override("font_color", COLOR_NORMAL)
	_time_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_time_label.add_theme_constant_override("outline_size", 14)
	vbox.add_child(_time_label)


func _load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Sans-Serif"])
	f.font_weight = 900
	return f


# ---------------------------------------------------------------- Lógica

func _process(delta: float) -> void:
	if manager == null or not _panel.visible:
		return
	# Los clientes solo reciben el tiempo 1 vez por segundo:
	# cuando llega un valor nuevo lo tomamos, si no, descontamos localmente.
	if manager.time_left != _last_synced:
		_last_synced = manager.time_left
		_local_time = manager.time_left
	elif manager.game_active:
		_local_time -= delta
	_local_time = maxf(_local_time, 0.0)
	_update_display()


func _update_display() -> void:
	var danger := _local_time <= DANGER_TIME
	_time_label.text = ("%.1f" % _local_time) if danger else str(ceili(_local_time))

	if danger == _danger:
		return
	_danger = danger
	var col := COLOR_DANGER if danger else COLOR_NORMAL
	_time_label.add_theme_color_override("font_color", col)
	_style.border_color = col
	if danger:
		_start_pulse()
	else:
		_stop_pulse()


func _on_it_changed(player_id: int, remaining: float) -> void:
	var is_me := player_id == multiplayer.get_unique_id()
	if not is_me:
		_hide()
		return
	_local_time = remaining
	_last_synced = remaining
	_danger = not (remaining <= DANGER_TIME)  # fuerza refresco de color
	_panel.visible = true
	_update_display()
	_pop_in()


func _hide() -> void:
	_stop_pulse()
	_panel.visible = false


# ---------------------------------------------------------------- Animaciones

func _pop_in() -> void:
	var was_danger := _danger
	_stop_pulse()
	_panel.scale = Vector2.ONE * 1.4
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if was_danger:
		t.tween_callback(_start_pulse)


func _start_pulse() -> void:
	_stop_pulse()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_panel, "scale", Vector2.ONE * 1.08, 0.25).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	_panel.scale = Vector2.ONE
