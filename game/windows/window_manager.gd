class_name WindowManager
extends CanvasLayer
## Maneja las ventanas abiertas y la barra de tareas (arriba a la izquierda).

var _windows := {}   # key -> GameWindow
var _desk: Control
var _taskbar: HBoxContainer

func _ready() -> void:
	layer = 20
	_desk = Control.new()
	_desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desk)
	_taskbar = HBoxContainer.new()
	_taskbar.position = Vector2(10, 4)
	_taskbar.add_theme_constant_override("separation", 4)
	add_child(_taskbar)

func find_window(key: String) -> GameWindow:
	return _windows.get(key)

## Abre (o trae al frente) la ventana con esa clave. factory crea la ventana si no existe.
func open(key: String, factory: Callable, near: Vector2) -> GameWindow:
	var w: GameWindow = _windows.get(key)
	if w == null:
		w = factory.call()
		_windows[key] = w
		_desk.add_child(w)
		w.close_requested.connect(close.bind(key))
		w.minimize_requested.connect(minimize.bind(key))
		w.reset_size()
		var vp := _desk.get_viewport_rect().size
		w.position = (near + Vector2(40, -w.size.y * 0.5)).clamp(Vector2(10, 40), vp - w.size - Vector2(10, 10))
	_restore(key)
	return w

func close(key: String) -> void:
	var w: GameWindow = _windows.get(key)
	if w:
		_windows.erase(key)
		_remove_task(key)
		w.queue_free()

func minimize(key: String) -> void:
	var w: GameWindow = _windows.get(key)
	if w == null:
		return
	w.visible = false
	_remove_task(key)
	var b := Button.new()
	b.name = "task_" + key.validate_node_name()
	b.text = w.title
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_restore.bind(key))
	_taskbar.add_child(b)

func _restore(key: String) -> void:
	var w: GameWindow = _windows.get(key)
	if w == null:
		return
	_remove_task(key)
	w.visible = true
	_desk.move_child(w, -1)

func _remove_task(key: String) -> void:
	var n := _taskbar.get_node_or_null("task_" + key.validate_node_name())
	if n:
		n.queue_free()

## La ventana visible de más arriba bajo ese punto de pantalla.
func window_at(screen: Vector2) -> GameWindow:
	for i in range(_desk.get_child_count() - 1, -1, -1):
		var w := _desk.get_child(i) as GameWindow
		if w and w.visible and w.get_global_rect().has_point(screen):
			return w
	return null
