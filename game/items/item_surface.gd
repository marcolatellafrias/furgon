class_name ItemSurface
extends Node3D
## Superficie de un overlay donde se apoyan ítems (tablero, piso de la caja…).
## Por ahora "gravedad" simple: cada ítem cae sobre lo que tenga abajo. Si no entra, no se acepta.
## Coordenadas en el espacio local del overlay (root3d), con profundidad fija z.

signal changed

@export var x_min := -4.0
@export var x_max := 4.0
@export var floor_y := -4.5
@export var ceiling_y := -0.5
@export var z := 0.0

var overlay: Overlay

func items() -> Array[ItemNode]:
	var out: Array[ItemNode] = []
	for c in get_children():
		if c is ItemNode:
			out.append(c)
	return out

## ¿El punto (en el plano de pantalla del overlay) cae sobre esta superficie?
func contains(plane_p: Vector2) -> bool:
	var l := overlay.plane_to_local(plane_p, z)
	return l.x >= x_min - 0.3 and l.x <= x_max + 0.3 and l.y >= floor_y - 0.6 and l.y <= ceiling_y + 0.3

func try_place(data: ItemData, plane_p: Vector2) -> bool:
	return place_at_local_x(data, overlay.plane_to_local(plane_p, z).x)

func place_at_local_x(data: ItemData, x: float, force := false) -> bool:
	var w := data.size.x
	x = clampf(x, x_min + w * 0.5, x_max - w * 0.5)
	var bottom := _support(x, w, null)
	if not force and bottom + data.size.y > ceiling_y:
		return false
	var n := ItemNode.new()
	n.setup(data)
	n.surface = self
	add_child(n)
	n.position = Vector3(x, bottom + data.size.y * 0.5, z)
	changed.emit()
	return true

## Saca un ítem (porque una mano lo agarró). Lo que estaba arriba cae.
func take(n: ItemNode) -> ItemData:
	remove_child(n)
	n.queue_free()
	settle()
	changed.emit()
	return n.data

func settle() -> void:
	var list := items()
	list.sort_custom(func(a: ItemNode, b: ItemNode) -> bool:
		return a.position.y - a.data.size.y * 0.5 < b.position.y - b.data.size.y * 0.5)
	var placed: Array[ItemNode] = []
	for n in list:
		var bottom := _support(n.position.x, n.data.size.x, placed)
		n.position.y = bottom + n.data.size.y * 0.5
		placed.append(n)

## Altura del apoyo más alto debajo del rango [x - w/2, x + w/2].
func _support(x: float, w: float, among) -> float:
	var top := floor_y
	var list: Array = items() if among == null else among
	for n: ItemNode in list:
		if absf(n.position.x - x) < (n.data.size.x + w) * 0.5 - 0.02:
			top = maxf(top, n.position.y + n.data.size.y * 0.5)
	return top

## Para mostrar el contenido en otro lado (ej. la caja de la van en el mundo 3D).
func snapshot() -> Array:
	var out := []
	for n in items():
		out.append({"data": n.data, "x": n.position.x, "y": n.position.y})
	return out
