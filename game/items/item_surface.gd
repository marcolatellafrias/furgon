class_name ItemSurface
extends Node3D
## Superficie de un overlay donde viven ítems con física 2D (tablero, caja de atrás…).
## Paredes, piso y techo son cuerpos estáticos. La física corre en el mundo 2D del
## SubViewport del overlay: 1 unidad de overlay = 100 px; en 2D la Y va hacia abajo.

signal changed

const PX := 100.0

@export var x_min := -4.0
@export var x_max := 4.0
@export var floor_y := -4.5
@export var ceiling_y := -0.5
@export var z := 0.0

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
	var t := 6.0  # grosor de las paredes, en unidades (gruesas para que nada las atraviese)
	var w := x_max - x_min
	var h := ceiling_y - floor_y
	var cx := (x_min + x_max) * 0.5
	var cy := (floor_y + ceiling_y) * 0.5
	_wall(walls, Vector2(cx, floor_y - t * 0.5), Vector2(w + t * 2, t))     # piso
	_wall(walls, Vector2(cx, ceiling_y + t * 0.5), Vector2(w + t * 2, t))   # techo
	_wall(walls, Vector2(x_min - t * 0.5, cy), Vector2(t, h + t * 2))      # izquierda
	_wall(walls, Vector2(x_max + t * 0.5, cy), Vector2(t, h + t * 2))      # derecha

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

func items() -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	for c in get_children():
		if c is ItemNode:
			out.append(c)
	return out

## Punto del plano de pantalla del overlay → coordenadas locales de esta superficie.
func local_at(plane_p: Vector2) -> Vector2:
	return overlay.plane_to_local(plane_p, z)

## ¿El punto cae dentro del espacio físico de esta superficie? margin agranda la zona
## (para que tirar algo con fuerza no lo saque del overlay sin querer).
func contains(plane_p: Vector2, margin := 0.2) -> bool:
	var l := local_at(plane_p)
	return l.x >= x_min - margin and l.x <= x_max + margin 		and l.y >= floor_y - 0.5 - margin and l.y <= ceiling_y + margin

## Crea el ítem con física en ese punto (local). Siempre entra: la física lo acomoda.
func spawn(data: ItemData, local_pos: Vector2, velocity := Vector2.ZERO) -> ItemNode:
	var half := data.size * 0.5
	local_pos.x = clampf(local_pos.x, x_min + half.x, x_max - half.x)
	local_pos.y = clampf(local_pos.y, floor_y + half.y, ceiling_y - half.y)
	var n := ItemNode.new()
	add_child(n)
	n.setup(data, self)
	n.body.position = to_px(local_pos)
	n.body.linear_velocity = Vector2(velocity.x, -velocity.y) * PX
	n.position = Vector3(local_pos.x, local_pos.y, z)
	changed.emit()
	return n

## Saca un ítem del overlay (porque se fue arrastrando a otro lado).
func take(n: ItemNode) -> ItemData:
	remove_child(n)
	n.queue_free()
	changed.emit()
	return n.data

## Para mostrar el contenido en otro lado (ej. la caja de la van en el mundo 3D).
func snapshot() -> Array:
	var out := []
	for n in items():
		var l := n.local_center()
		out.append({"data": n.data, "x": l.x, "y": l.y, "rot": n.rotation.z})
	return out
