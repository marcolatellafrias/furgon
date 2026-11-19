class_name SteeringWheelControl
extends Grabbable
## Volante: lo agarrás y lo girás alrededor del centro. Con velocidad vuelve solo al centro.

@export var radius := 1.45
@export var max_turn_deg := 450.0

var controls: VanControls
var van: Van
var angle := 0.0   ## radianes; positivo = antihorario en pantalla = izquierda

var _last := 0.0
var _visual: Node3D

func _ready() -> void:
	grab_radius = radius + 0.25
	_visual = Node3D.new()
	add_child(_visual)
	var ring := LowPoly.torus(radius - 0.05, 0.24, Color(0.12, 0.12, 0.13), 14, 6)
	ring.rotation_degrees.x = 90
	_visual.add_child(ring)
	for a in [0.0, 180.0, 270.0]:
		var spoke := box(Vector3(radius, 0.18, 0.08), Color(0.18, 0.18, 0.2))
		spoke.rotation_degrees.z = a
		spoke.position = Vector3(cos(deg_to_rad(a)), sin(deg_to_rad(a)), 0) * radius * 0.5
		_visual.add_child(spoke)
	var hub := box(Vector3(0.7, 0.55, 0.15), Color(0.22, 0.22, 0.25))
	hub.position.z = 0.05
	_visual.add_child(hub)
	var mark := box(Vector3(0.12, 0.22, 0.1), Color(0.95, 0.55, 0.1))
	mark.position = Vector3(0, radius - 0.05, 0.08)
	_visual.add_child(mark)

func _angle_to(p: Vector2) -> float:
	var d := p - grab_point()
	return atan2(d.y, d.x)

func on_grab(_hand: Hand, p: Vector2) -> void:
	_last = _angle_to(p)

func on_drag(_hand: Hand, p: Vector2) -> void:
	if p.distance_to(grab_point()) < 0.25:
		return  # muy cerca del centro el ángulo salta
	var a := _angle_to(p)
	angle += wrapf(a - _last, -PI, PI)
	_last = a
	var lim := deg_to_rad(max_turn_deg)
	angle = clampf(angle, -lim, lim)

func _process(delta: float) -> void:
	if held_by == null and van:
		angle = move_toward(angle, 0.0, deg_to_rad(van.speed_kmh * 9.0) * delta)
	_visual.rotation.z = angle
	if controls:
		controls.steer = clampf(-angle / deg_to_rad(max_turn_deg), -1.0, 1.0)
