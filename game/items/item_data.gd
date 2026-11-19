class_name ItemData
extends Resource
## Un ítem: la "cosa" que se mueve entre contenedores (tablero, caja, mano, ventana…).
## Los contenedores crean su propio dibujo con make_visual(); el dato es siempre el mismo.

@export var display_name := "Paquete"
@export var kind := "package"           ## "food", "package", "document"…
@export var size := Vector2(1.0, 0.8)   ## ancho y alto en unidades de overlay
@export var depth := 0.8
@export var color := Color(0.72, 0.55, 0.36)
@export var shape := "box"              ## "box", "can", "round", "flat"
@export var nutrition := 0.0            ## >0 = se puede comer
@export var weight := 5.0               ## kg

func is_food() -> bool:
	return nutrition > 0.0

## Dibujo low poly centrado en el origen, en unidades de overlay.
func make_visual() -> Node3D:
	var root := Node3D.new()
	match shape:
		"can":
			root.add_child(LowPoly.cylinder(size.x * 0.5, size.y, color, 8))
			var band := LowPoly.cylinder(size.x * 0.51, size.y * 0.35, Color.WHITE, 8)
			root.add_child(band)
		"round":
			var s := LowPoly.sphere(0.5, color, 7, 4)
			s.scale = Vector3(size.x, size.y, depth)
			root.add_child(s)
		"flat":
			root.add_child(LowPoly.box(Vector3(size.x, size.y, depth), color))
			for i in 3:
				var line := LowPoly.box(Vector3(size.x * 0.7, 0.04, 0.02), color.darkened(0.4))
				line.position = Vector3(0, size.y * (0.25 - i * 0.25), depth * 0.5 + 0.01)
				root.add_child(line)
		_:
			root.add_child(LowPoly.box(Vector3(size.x, size.y, depth), color))
			var tape := LowPoly.box(Vector3(size.x * 0.18, size.y + 0.02, depth + 0.02), color.lightened(0.35))
			root.add_child(tape)
	return root

static func make_food(p_name: String, p_shape: String, p_size: Vector2, p_color: Color, p_nutrition: float) -> ItemData:
	var d := ItemData.new()
	d.display_name = p_name
	d.kind = "food"
	d.shape = p_shape
	d.size = p_size
	d.depth = p_size.x * 0.8
	d.color = p_color
	d.nutrition = p_nutrition
	d.weight = 0.4
	return d

static func make_package(p_name: String, p_size: Vector2, p_weight: float) -> ItemData:
	var d := ItemData.new()
	d.display_name = p_name
	d.size = p_size
	d.depth = 0.9
	d.weight = p_weight
	d.color = Color(0.72, 0.55, 0.36).lerp(Color(0.6, 0.45, 0.3), randf())
	return d
