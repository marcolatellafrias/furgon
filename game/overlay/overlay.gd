class_name Overlay
extends CanvasLayer
## Base de todos los overlays de espacio (cabina, caja de atrás, motor…).
## Es una escena 3D propia con cámara ortográfica de frente, dibujada encima del mundo.
## Todo lo interactivo vive en el plano XY y se agarra con manos.
## Regla: el overlay nunca tapa todo el mundo (fondo transparente, ocupa bordes).
## El input lo reparte el Desktop: el overlay solo sabe qué hay bajo una mano.

signal item_grab_requested(node: ItemNode, hand: Hand)

const VIEW_HEIGHT := 10.0  ## alto visible en unidades: Y va de -5 (abajo) a +5 (arriba)

## Proyección oblicua ("vista 3/4"): la cara de frente queda plana y sin deformar, y lo que
## está más cerca del jugador (Z mayor) baja un poco en pantalla, así se ve la cara de arriba.
const OBLIQUE_TOP := 0.45
const OBLIQUE_SIDE := 0.0

var space_id := ""
## Dónde tiene que quedar el foco del mundo (tu personaje) con este overlay abierto,
## en unidades del overlay (Y: -5 abajo … +5 arriba). Así el overlay nunca lo tapa.
var world_focus_y := 0.0
var viewport: SubViewport
var camera: Camera3D
var root3d: Node3D

static func oblique_basis() -> Basis:
	return Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(-OBLIQUE_SIDE, -OBLIQUE_TOP, 1))

func _ready() -> void:
	if layer == 1:
		layer = 5
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
	build()

## Para sobreescribir: arma el contenido del overlay dentro de root3d.
func build() -> void:
	pass

# ---------------------------------------------------------------- coordenadas

func screen_to_plane(screen: Vector2) -> Vector2:
	var p := camera.project_position(screen, 1.0)
	return Vector2(p.x, p.y)

func plane_to_screen(p: Vector2) -> Vector2:
	return camera.unproject_position(Vector3(p.x, p.y, 0))

## Punto del plano de pantalla → coordenadas locales de root3d a una profundidad z.
func plane_to_local(p: Vector2, z: float) -> Vector2:
	return Vector2(p.x + OBLIQUE_SIDE * z, p.y + OBLIQUE_TOP * z)

# ---------------------------------------------------------------- contenido

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

func surfaces() -> Array[ItemSurface]:
	var out: Array[ItemSurface] = []
	for c in root3d.get_children():
		if c is ItemSurface:
			out.append(c)
	return out

func surface_at(p: Vector2) -> ItemSurface:
	for s in surfaces():
		if s.contains(p):
			return s
	return null

func add_surface(s: ItemSurface) -> ItemSurface:
	s.overlay = self
	root3d.add_child(s)
	return s

func grabbable_at(p: Vector2, hand: Hand) -> Grabbable:
	for g in grabbables():
		if g.is_visible_in_tree() and g.hit_test(p) and g.can_grab(hand):
			return g
	return null

# ---------------------------------------------------------------- manos

func hand_press(hand: Hand, p: Vector2) -> bool:
	hand.pos = p
	var g := grabbable_at(p, hand)
	if g == null:
		return false
	if g is ItemNode:
		item_grab_requested.emit(g, hand)  # los ítems se arrastran, no se "sostienen" acá
		return true
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

## Si una mano se va del espacio, suelta lo que tenía.
func release_all(hand: Hand) -> void:
	if hand.held:
		hand_release(hand, hand.pos)
