class_name GameWindow
extends PanelContainer
## Ventana estilo sistema operativo: se mueve desde la barra de título, se minimiza y se cierra.
## Cualquier ventana puede ser destino de un arrastre: decide ella si acepta el ítem.

signal close_requested
signal minimize_requested

var key := ""            ## identificador único (ej. "char:1")
var title := ""
var content: VBoxContainer
var _title_label: Label
var _dragging := false

func _init(p_key: String, p_title: String) -> void:
	key = p_key
	title = p_title
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.17, 0.96)
	sb.border_color = Color(0.95, 0.55, 0.1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_on_bar_input)
	vb.add_child(bar)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(_title_label)
	var mini := Button.new()
	mini.text = "_"
	mini.focus_mode = Control.FOCUS_NONE
	mini.pressed.connect(func() -> void: minimize_requested.emit())
	bar.add_child(mini)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: close_requested.emit())
	bar.add_child(close)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	vb.add_child(content)

func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			get_parent().move_child(self, -1)  # al frente
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		_clamp_to_screen()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_parent().move_child(self, -1)

func _clamp_to_screen() -> void:
	var vp := get_viewport_rect().size
	position = position.clamp(Vector2(-size.x + 60, 0), vp - Vector2(60, 30))

## ¿Acepta este ítem soltado en esta posición de pantalla? (para sobreescribir)
func can_accept(_item: ItemData, _screen: Vector2) -> bool:
	return false

## Recibe el ítem. Devuelve true si se lo quedó. (para sobreescribir)
func accept_drop(_item: ItemData, _screen: Vector2) -> bool:
	return false
