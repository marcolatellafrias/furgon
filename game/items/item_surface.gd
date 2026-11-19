class_name ItemSurface
extends Node3D
## Superficie de un overlay donde viven ítems con física 2D.
##   view "side": vista de costado con gravedad (tablero).
##   view "top":  vista desde arriba, sin gravedad, el piso frena con rozamiento (caja de atrás).
## La física corre en el mundo 2D del SubViewport del overlay: 1 unidad de overlay = 100 px;
## en 2D la Y va hacia abajo. Configurar todo ANTES de agregarla al overlay (ahí se arman las paredes).

signal changed

const PX := 100.0

@export var view := "side"
@export var units_per_meter := 6.0
@export var x_min := -4.0
@export var x_max := 4.0
@export var floor_y := -4.5      ## en "top" es el borde de abajo
@export var ceiling_y := -0.5    ## en "top" es el borde de arriba
@export var z := 0.0

## "top": aceleración (m/s²) que hace falta para que los paquetes se empiecen a deslizar.
@export var static_friction_accel := 2.5
@export var inertia_gain := 1.6

var overlay: Overlay
var physics_root: Node2D

static func to_px(l: Vector2) -> Vector2:
	return Vector2(l.x, -l.y) * PX

static func from_px(p: Vector2) -> Vector2:
	return Vector2(p.x, -p.y) / PX

func _ready() -> void:
	physics_root = Node2D.new()
	physics_root.name = "Fisica_" + name
	overlay.viewport.add_child(physics_root)
	var walls := StaticBody2D.new()
	physics_root.add_child(walls)
	var t := 6.0  # paredes gruesas para que nada las atraviese
	var w := x_max - x_min
	var h := ceiling_y - floor_y
	var cx := (x_min + x_max) * 0.5
	var cy := (floor_y + ceiling_y) * 0.5
	_wall(walls, Vector2(cx, floor_y - t * 0.5), Vector2(w + t * 2, t))
	_wall(walls, Vector2(cx, ceiling_y + t * 0.5), Vector2(w + t * 2, t))
	_wall(walls, Vector2(x_min - t * 0.5, cy), Vector2(t, h + t * 2))
	_wall(walls, Vector2(x_max + t * 0.5, cy), Vector2(t, h + t * 2))
	set_inertia(Vector2.ZERO, 0.0)

func _wall(b: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size * PX
	col.shape = r
	col.position = to_px(center)
	b.add_child(col)

func _exit_tree() -> void:
	if is_instance_valid(physics_root):
		physics_root.queue_free()

# ---------------------------------------------------------------- medidas

## Tamaño del ítem en unidades de overlay, en esta vista.
func item_size(data: ItemData) -> Vector2:
	return data.footprint(view) * units_per_meter

func local_at(plane_p: Vector2) -> Vector2:
	return overlay.plane_to_local(plane_p, z)

func contains(plane_p: Vector2) -> bool:
	var l := local_at(plane_p)
	return l.x >= x_min and l.x <= x_max and l.y >= floor_y and l.y <= ceiling_y

func items() -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	for c in get_children():
		if c is ItemNode:
			out.append(c)
	return out

## ¿Se puede dejar este ítem acá? Tiene que quedar adentro y sin tocar a otro ítem.
func can_place(data: ItemData, local_pos: Vector2, rot := 0.0, exclude: RigidBody2D = null) -> bool:
	var half := item_size(data) * 0.5
	var xf := Transform2D(-rot, to_px(local_pos))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := from_px(xf * (corner * half * PX))
		if c.x < x_min - 0.01 or c.x > x_max + 0.01 or c.y < floor_y - 0.01 or c.y > ceiling_y + 0.01:
			return false
	var shape := RectangleShape2D.new()
	shape.size = (half * 2.0 * PX - Vector2(4, 4)).max(Vector2(2, 2))
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = xf
	if exclude:
		q.exclude = [exclude.get_rid()]
	var space := overlay.viewport.world_2d.direct_space_state
	return space.intersect_shape(q, 1).is_empty()

# ---------------------------------------------------------------- ítems

## Crea el ítem con física en ese punto (local).
func spawn(data: ItemData, local_pos: Vector2, velocity := Vector2.ZERO, rot := 0.0) -> ItemNode:
	var n := ItemNode.new()
	add_child(n)
	n.setup(data, self)
	n.body.position = to_px(local_pos)
	n.body.rotation = -rot
	n.body.linear_velocity = Vector2(velocity.x, -velocity.y) * PX
	n.sync_visual()
	changed.emit()
	return n

## Saca un ítem de la superficie (se fue a una ventana o a una mano).
func take(n: ItemNode) -> ItemData:
	remove_child(n)
	n.queue_free()
	changed.emit()
	return n.data

## Para mostrar el contenido en otro lado (la caja de la van en el mundo 3D).
func snapshot() -> Array:
	var out := []
	for n in items():
		var l := n.local_center()
		out.append({"data": n.data, "x": l.x, "y": l.y, "rot": n.rotation.z})
	return out

# ---------------------------------------------------------------- inercia

## Aceleración que sienten los ítems (m/s²), en ejes de pantalla del overlay: x a la derecha, y arriba.
## "side": force.x empuja de costado; vertical suma/resta peso (pozos).
## "top": empuja en el plano, pero solo si supera el rozamiento estático.
func set_inertia(force: Vector2, vertical: float) -> void:
	var space := overlay.viewport.world_2d.space
	var g: Vector2
	if view == "side":
		var v := Vector2(clampf(force.x / 9.8 * inertia_gain, -1.2, 1.2), clampf(1.0 + vertical / 9.8, 0.4, 1.8))
		g = v * 9.8 * units_per_meter * PX / 2.4   # gravedad "de juego" (más lenta que la real a esta escala)
	else:
		var f := Vector2(force.x, -force.y) * inertia_gain
		var mag := maxf(0.0, f.length() - static_friction_accel)
		g = f.normalized() * mag * units_per_meter * PX if mag > 0.0 else Vector2.ZERO
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, g.normalized() if g != Vector2.ZERO else Vector2.DOWN)
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY, g.length())
