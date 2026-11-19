class_name CargoOverlay
extends Overlay
## Overlay del espacio "caja de atrás", visto DESDE ARRIBA y ortográfico puro (sin ángulo),
## en el plano XZ de la van, horizontal:
## la cabina queda a la izquierda y la puerta de atrás a la derecha.
## Los paquetes son una sola capa con física 2D sin gravedad; la inercia de la van los empuja.
## Lo que ves acá es exactamente lo que hay adentro de la van en el mundo.

var van: Van
var surface: ItemSurface

const UPM := 2.0                 ## unidades de overlay por metro
const BED_FRONT_Z := 0.75        ## caja de la van, en coordenadas locales (m)
const BED_BACK_Z := -2.5
const BED_HALF_X := 0.92
const CENTER_Y := -2.55          ## centro vertical de la caja en el overlay

const WALL := Color(0.86, 0.86, 0.84)

static func half_len() -> float:
	return (BED_FRONT_Z - BED_BACK_Z) * UPM * 0.5

## Overlay (x, y) → posición local en la van (x, z). x del overlay crece hacia la puerta (-Z).
static func to_van(o: Vector2) -> Vector2:
	var z := BED_FRONT_Z - (o.x + half_len()) / UPM
	var x := -(o.y - CENTER_Y) / UPM
	return Vector2(x, z)

func _init() -> void:
	oblique = false

func build() -> void:
	world_focus_y = 2.2
	var hl := half_len()
	var hw := BED_HALF_X * UPM
	var floor_plate := LowPoly.box(Vector3(hl * 2, hw * 2, 0.1), Color(0.36, 0.34, 0.31))
	floor_plate.position = Vector3(0, CENTER_Y, -0.05)
	root3d.add_child(floor_plate)
	var h := 1.0
	for sy in [-1.0, 1.0]:
		var side := LowPoly.box(Vector3(hl * 2 + 0.4, 0.2, h), WALL)
		side.position = Vector3(0, CENTER_Y + sy * (hw + 0.1), h * 0.5)
		root3d.add_child(side)
	var cabin_wall := LowPoly.box(Vector3(0.2, hw * 2 + 0.4, h * 1.3), Color(0.7, 0.7, 0.68))
	cabin_wall.position = Vector3(-hl - 0.1, CENTER_Y, h * 0.65)
	root3d.add_child(cabin_wall)
	var door := LowPoly.box(Vector3(0.2, hw * 2 + 0.4, h * 0.3), Color(0.95, 0.55, 0.1))
	door.position = Vector3(hl + 0.1, CENTER_Y, h * 0.15)
	root3d.add_child(door)
	var l1 := LowPoly.label("cabina", 20, Color(0.95, 0.95, 0.95))
	l1.position = Vector3(-hl + 0.5, CENTER_Y + hw + 0.45, 1.0)
	root3d.add_child(l1)
	var l2 := LowPoly.label("puerta", 20, Color(0.95, 0.95, 0.95))
	l2.position = Vector3(hl - 0.5, CENTER_Y + hw + 0.45, 1.0)
	root3d.add_child(l2)

	var s := ItemSurface.new()
	s.view = "top"
	s.units_per_meter = UPM
	s.x_min = -hl
	s.x_max = hl
	s.floor_y = CENTER_Y - hw
	s.ceiling_y = CENTER_Y + hw
	s.z = 0.0
	surface = add_surface(s)   # recién acá se arman las paredes físicas
	surface.changed.connect(sync_to_van)

func _physics_process(_delta: float) -> void:
	if surface and Engine.get_physics_frames() % 2 == 0:
		sync_to_van()

## Muestra los paquetes en la van del mundo, en la misma posición y giro que en el overlay.
func sync_to_van() -> void:
	var entries := []
	for e in surface.snapshot():
		var v := to_van(Vector2(e.x, e.y))
		entries.append({"data": e.data, "x": v.x, "z": v.y, "yaw": PI / 2.0 + float(e.rot)})
	van.set_cargo(entries)
