class_name GearLeverControl
extends Grabbable
## Palanca de cambios en H. Arrastrás la perilla por la ranura.
##   1   3   R
##   |---N---|
##   2   4
## Sin el embrague pisado la marcha no entra (se traba a mitad de camino).

@export var step := 0.5   ## distancia entre columnas/filas

var controls: VanControls
var knob := Vector2.ZERO  ## en unidades de grilla: x -1..1, y -1..1
var grinding := 0.0       ## >0 durante un rato cuando se trabó (el tablero lo muestra)

const GATES := {
	Vector2i(-1, 1): 1, Vector2i(-1, -1): 2,
	Vector2i(0, 1): 3, Vector2i(0, -1): 4,
	Vector2i(1, 1): -1,
}

var _knob_mesh: MeshInstance3D
var _grab_offset := Vector2.ZERO

func _ready() -> void:
	grab_radius = 0.45
	priority = 1
	var plate := box(Vector3(step * 2 + 0.7, step * 2 + 1.2, 0.1), Color(0.16, 0.16, 0.18))
	plate.position.z = -0.1
	add_child(plate)
	var slot_color := Color(0.05, 0.05, 0.05)
	var h := box(Vector3(step * 2 + 0.12, 0.12, 0.05), slot_color)
	add_child(h)
	for g in GATES:
		var v := box(Vector3(0.12, step + 0.06, 0.05), slot_color)
		v.position = Vector3(g.x * step, g.y * step * 0.5, 0)
		add_child(v)
		var l := label(VanControls.gear_name(GATES[g]), 24, Color(0.8, 0.8, 0.8))
		l.position = Vector3(g.x * step, g.y * (step + 0.32), 0.05)
		add_child(l)
	_knob_mesh = LowPoly.sphere(0.2, Color(0.1, 0.1, 0.1), 8, 5)
	_knob_mesh.position.z = 0.2
	add_child(_knob_mesh)

func grab_point() -> Vector2:
	return Vector2(global_position.x, global_position.y) + knob * step

func _to_grid(p: Vector2) -> Vector2:
	return (p - Vector2(global_position.x, global_position.y)) / step

func on_grab(_hand: Hand, p: Vector2) -> void:
	_grab_offset = knob - _to_grid(p)

func on_drag(_hand: Hand, p: Vector2) -> void:
	_move_toward(_to_grid(p) + _grab_offset)

func on_release(_hand: Hand, _p: Vector2) -> void:
	# Se acomoda: o queda en la marcha o vuelve a punto muerto.
	knob.y = signf(knob.y) if absf(knob.y) > 0.6 else 0.0
	if knob.y == 0.0:
		knob.x = clampf(knob.x, -1.0, 1.0)

## Para pruebas / red: poner una marcha directamente.
func force_gear(g: int) -> void:
	knob = Vector2.ZERO
	for cell in GATES:
		if GATES[cell] == g:
			knob = Vector2(cell)

func _move_toward(d: Vector2) -> void:
	var k := knob
	if absf(k.y) < 0.12:
		# Fila neutra: se mueve horizontal; puede entrar a una columna si está alineado.
		var nx := clampf(d.x, -1.0, 1.0)
		var col := roundi(nx)
		if absf(nx - col) < 0.25 and absf(d.y) > 0.12:
			k = Vector2(col, _clamp_y(col, d.y))
		else:
			k = Vector2(nx, 0.0)
	else:
		var col := roundi(k.x)
		var ny := _clamp_y(col, d.y)
		if signf(ny) != signf(k.y):
			ny = 0.0  # cruzó por el medio: queda en neutro
		k = Vector2(col, ny)

	# El embrague manda: sin pisarlo no entra una marcha nueva.
	var col_i := roundi(k.x)
	var target: int = GATES.get(Vector2i(col_i, int(signf(k.y))), 0)
	if absf(k.y) > 0.45 and target != _current_gear() and controls and controls.clutch_enabled and controls.clutch < 0.6:
		k.y = signf(k.y) * 0.45
		grinding = 0.4
	knob = k

func _clamp_y(col: int, y: float) -> float:
	var top := 1.0 if GATES.has(Vector2i(col, 1)) else 0.0
	var bottom := -1.0 if GATES.has(Vector2i(col, -1)) else 0.0
	return clampf(y, bottom, top)

func _current_gear() -> int:
	if absf(knob.y) < 0.8:
		return 0
	return GATES.get(Vector2i(roundi(knob.x), int(signf(knob.y))), 0)

func _process(delta: float) -> void:
	grinding = maxf(grinding - delta, 0.0)
	_knob_mesh.position.x = knob.x * step
	_knob_mesh.position.y = knob.y * step
	if controls:
		controls.gear = _current_gear()
