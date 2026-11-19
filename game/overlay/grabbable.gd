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

# --- helpers de dibujo para placeholders
static func make_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	m.material_override = mat
	return m

static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return make_mesh(b, color)

static func label(text: String, size := 32, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 6
	return l
