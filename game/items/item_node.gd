class_name ItemNode
extends Grabbable
## Un ítem apoyado en una superficie de un overlay. Agarrarlo = empezar a arrastrarlo
## (el overlay avisa y el Desktop lo lleva en la mano).

var data: ItemData
var surface: ItemSurface

func setup(p_data: ItemData) -> void:
	data = p_data
	priority = 5
	add_child(data.make_visual())

func hit_test(p: Vector2) -> bool:
	var d := (p - grab_point()).abs()
	return d.x <= data.size.x * 0.5 + 0.05 and d.y <= data.size.y * 0.5 + 0.05
