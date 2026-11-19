class_name IgnitionKeyControl
extends Grabbable
## Llave: clic = girar. Si el motor está apagado intenta arrancar; si está prendido, lo apaga.

var controls: VanControls
var van: Van
var _key: Node3D

func _ready() -> void:
	grab_radius = 0.4
	priority = 1
	var b := LowPoly.cylinder(0.28, 0.1, Color(0.5, 0.5, 0.55), 8)
	b.rotation_degrees.x = 90
	add_child(b)
	_key = Node3D.new()
	_key.position.z = 0.1
	add_child(_key)
	var blade := box(Vector3(0.08, 0.32, 0.05), Color(0.8, 0.75, 0.5))
	_key.add_child(blade)
	var head := box(Vector3(0.3, 0.2, 0.06), Color(0.15, 0.15, 0.15))
	head.position.y = 0.25
	_key.add_child(head)
	var l := label("LLAVE", 18, Color(0.7, 0.7, 0.7))
	l.position = Vector3(0, -0.45, 0)
	add_child(l)

func on_grab(_hand: Hand, _p: Vector2) -> void:
	if controls:
		controls.turn_key()

func _process(_delta: float) -> void:
	var on := van != null and (van.engine_on or van.cranking)
	_key.rotation.z = -PI / 2.0 if on else 0.0
