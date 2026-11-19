class_name ItemData
extends Resource
## Un ítem: la "cosa" que se mueve entre contenedores (tablero, caja, mano, ventana…).
## Hay UNA sola versión de cada ítem a la vez. Cada contenedor crea su propio dibujo
## con make_visual(); el dato es siempre el mismo.
##
## Medidas reales en metros: dims = (ancho, alto, profundidad).

@export var display_name := "Paquete"
@export var kind := "package"           ## "food", "package", "document"…
@export var dims := Vector3(0.4, 0.3, 0.3)
@export var color := Color(0.72, 0.55, 0.36)
@export var shape := "box"              ## "box", "can", "round", "flat"
@export var nutrition := 0.0            ## >0 = se puede comer
@export var weight := 5.0               ## kg

func is_food() -> bool:
	return nutrition > 0.0

## Tamaño en el plano de una vista: "side" = (ancho, alto), "top" = (ancho, profundidad).
func footprint(view: String) -> Vector2:
	return Vector2(dims.x, dims.z) if view == "top" else Vector2(dims.x, dims.y)

## Dibujo low poly centrado en el origen.
## units_per_meter escala las medidas reales. view:
##   "side": alto en +Y, profundidad hacia la cámara (+Z)  → tablero, ventanas, mundo
##   "top":  visto desde arriba: profundidad en -Y, alto hacia la cámara (+Z) → caja de atrás
func make_visual(units_per_meter := 1.0, view := "side") -> Node3D:
	var s := units_per_meter
	var d := dims * s
	var model := Node3D.new()
	match shape:
		"can":
			model.add_child(LowPoly.cylinder(d.x * 0.5, d.y, color, 8))
			model.add_child(LowPoly.cylinder(d.x * 0.51, d.y * 0.35, Color.WHITE, 8))
		"round":
			var sp := LowPoly.sphere(0.5, color, 7, 4)
			sp.scale = d
			model.add_child(sp)
		"flat":
			model.add_child(LowPoly.box(d, color))
			for i in 3:
				var line := LowPoly.box(Vector3(d.x * 0.7, d.y * 0.06, maxf(d.z * 0.3, 0.005)), color.darkened(0.4))
				line.position = Vector3(0, d.y * (0.25 - i * 0.25), d.z * 0.5)
				model.add_child(line)
		_:
			model.add_child(LowPoly.box(d, color))
			var tape := LowPoly.box(Vector3(d.x * 0.18, d.y * 1.01, d.z * 1.01), color.lightened(0.35))
			model.add_child(tape)
			var tape2 := LowPoly.box(Vector3(d.x * 1.01, d.y * 1.01, d.z * 0.14), color.lightened(0.35))
			model.add_child(tape2)
	if view == "top":
		model.rotation_degrees.x = 90   # el alto apunta a la cámara
	var root := Node3D.new()
	root.add_child(model)
	return root

static func make_food(p_name: String, p_shape: String, p_dims: Vector3, p_color: Color, p_nutrition: float) -> ItemData:
	var d := ItemData.new()
	d.display_name = p_name
	d.kind = "food"
	d.shape = p_shape
	d.dims = p_dims
	d.color = p_color
	d.nutrition = p_nutrition
	d.weight = 0.4
	return d

static func make_package(p_name: String, p_dims: Vector3, p_weight: float) -> ItemData:
	var d := ItemData.new()
	d.display_name = p_name
	d.dims = p_dims
	d.weight = p_weight
	d.color = Color(0.72, 0.55, 0.36).lerp(Color(0.6, 0.45, 0.3), randf())
	return d
