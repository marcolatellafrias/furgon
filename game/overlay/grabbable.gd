class_name Grabbable
extends Node3D
## Algo que una mano puede agarrar dentro de un overlay (volante, palanca, pedal, ítem…).
## Regla: una cosa la agarra una sola mano a la vez.
## El overlay es pseudo-2D: todo se resuelve en el plano XY (Z es solo dibujo).

@export var grab_radius := 0.5
@export var priority := 0     ## mayor = se prueba primero al hacer clic

var held_by: Hand = null

func grab_point() -> Vector2:
	return Vector2(global_position.x, global_position.y)

func hit_test(p: Vector2) -> bool:
	return grab_point().distance_to(p) <= grab_radius

func can_grab(_hand: Hand) -> bool:
	return held_by == null

func on_grab(_hand: Hand, _p: Vector2) -> void:
	pass

func on_drag(_hand: Hand, _p: Vector2) -> void:
	pass

func on_release(_hand: Hand, _p: Vector2) -> void:
	pass

# --- atajos de dibujo (todo pasa por LowPoly)
static func box(size: Vector3, color: Color) -> MeshInstance3D:
	return LowPoly.box(size, color)

static func label(text: String, size := 32, color := Color.WHITE) -> Label3D:
	return LowPoly.label(text, size, color)
