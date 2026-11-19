class_name PedalControl
extends Grabbable
## Pedal. Se pisa con el pie (teclado) o agarrándolo y arrastrando hacia abajo.
## Valor final = el mayor entre pie y mano. Al soltar vuelve solo.

@export var property := "throttle"   ## campo de VanControls que escribe
@export var travel := 0.8
@export var title := "A"

var controls: VanControls
var foot_value := 0.0
var hand_value := 0.0
var value := 0.0

var _pad: MeshInstance3D
var _y0 := 0.0

func _ready() -> void:
	grab_radius = 0.42
	_pad = box(Vector3(0.55, 0.75, 0.1), Color(0.3, 0.3, 0.32))
	add_child(_pad)
	var l := label(title, 28)
	l.position = Vector3(0, 0, 0.08)
	_pad.add_child(l)

func on_grab(_hand: Hand, p: Vector2) -> void:
	_y0 = p.y
	hand_value = 0.35  # al agarrarlo ya lo pisás un poco

func on_drag(_hand: Hand, p: Vector2) -> void:
	hand_value = clampf(0.35 + (_y0 - p.y) / travel, 0.0, 1.0)

func on_release(_hand: Hand, _p: Vector2) -> void:
	hand_value = 0.0

func _process(_delta: float) -> void:
	value = maxf(foot_value, hand_value)
	_pad.position.y = -value * 0.25
	(_pad.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.3, 0.32).lerp(Color(0.95, 0.55, 0.1), value)
	if controls:
		controls.set(property, value)
