class_name Overlay
extends CanvasLayer
## Base de todos los overlays de espacio (cabina, motor…).
## Es una escena 3D propia con cámara ortográfica de frente, dibujada encima del mundo.
## Todo lo interactivo vive en el plano XY y se agarra con manos.
## Regla: el overlay nunca tapa todo el mundo (fondo transparente, ocupa bordes).

const VIEW_HEIGHT := 10.0  ## alto visible en unidades: Y va de -5 (abajo) a +5 (arriba)

var viewport: SubViewport
var camera: Camera3D
var root3d: Node3D
var local_hand := Hand.new(0)
var hands: Array[Hand] = []

func _ready() -> void:
	layer = 1
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_HEIGHT
	camera.position = Vector3(0, 0, 20)
	camera.far = 60.0
	viewport.add_child(camera)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.1
	viewport.add_child(sun)

	root3d = Node3D.new()
	root3d.transform = Transform3D(oblique_basis(), Vector3.ZERO)
	viewport.add_child(root3d)
	hands.append(local_hand)
	build()

## Proyección oblicua ("vista 3/4"): la cara de frente queda plana y sin deformar, y lo que
## está más cerca del jugador (Z mayor) baja un poco en pantalla, así se ve la cara de arriba.
## top = cuánto se ve de arriba; side = cuánto se ve de costado (0 = nada).
const OBLIQUE_TOP := 0.45
const OBLIQUE_SIDE := 0.0

static func oblique_basis() -> Basis:
	return Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(-OBLIQUE_SIDE, -OBLIQUE_TOP, 1))

## Para sobreescribir: arma el contenido del overlay dentro de root3d.
func build() -> void:
	pass

func screen_to_plane(screen: Vector2) -> Vector2:
	var p := camera.project_position(screen, 1.0)
	return Vector2(p.x, p.y)

func grabbables() -> Array[Grabbable]:
	var out: Array[Grabbable] = []
	_collect(root3d, out)
	out.sort_custom(func(a: Grabbable, b: Grabbable) -> bool: return a.priority > b.priority)
	return out

func _collect(n: Node, out: Array[Grabbable]) -> void:
	for c in n.get_children():
		if c is Grabbable:
			out.append(c)
		_collect(c, out)

func grabbable_at(p: Vector2, hand: Hand) -> Grabbable:
	for g in grabbables():
		if g.hit_test(p) and g.can_grab(hand):
			return g
	return null

# ---------------------------------------------------------------- manos

func hand_press(hand: Hand, p: Vector2) -> bool:
	hand.pos = p
	var g := grabbable_at(p, hand)
	if g == null:
		return false
	hand.held = g
	g.held_by = hand
	g.on_grab(hand, p)
	return true

func hand_move(hand: Hand, p: Vector2) -> bool:
	hand.pos = p
	if hand.held:
		hand.held.on_drag(hand, p)
		return true
	return false

func hand_release(hand: Hand, p: Vector2) -> bool:
	hand.pos = p
	if hand.held == null:
		return false
	var g := hand.held
	hand.held = null
	g.held_by = null
	g.on_release(hand, p)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := screen_to_plane(event.position)
		handled = hand_press(local_hand, p) if event.pressed else hand_release(local_hand, p)
	elif event is InputEventMouseMotion:
		var p := screen_to_plane(event.position)
		handled = hand_move(local_hand, p)
		_update_cursor(p)
	if handled:
		get_viewport().set_input_as_handled()

func _update_cursor(p: Vector2) -> void:
	var shape := Input.CURSOR_ARROW
	if local_hand.held:
		shape = Input.CURSOR_DRAG
	elif grabbable_at(p, local_hand):
		shape = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(shape)
