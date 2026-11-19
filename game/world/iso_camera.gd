extends Camera3D
## Cámara isométrica ortográfica. Sigue a un objetivo con suavizado.

@export var target: Node3D
@export var distance := 40.0
@export var zoom := 20.0
@export var follow_speed := 6.0

## Fracción de media pantalla que el objetivo se corre hacia arriba (lo pone el Desktop
## según el overlay abierto, para que el personaje quede en la zona libre).
var screen_focus := 0.0

var _center := Vector3.ZERO

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = zoom
	far = 200.0
	if target:
		_center = target.global_position
	_update()

func _process(delta: float) -> void:
	if target:
		_center = _center.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
	v_offset = lerpf(v_offset, -screen_focus * size * 0.5, 1.0 - exp(-follow_speed * delta))
	_update()

func _update() -> void:
	# Ángulo isométrico clásico: 45° en Y, ~35.26° hacia abajo.
	var offset := Vector3(1, 0.8165, 1).normalized() * distance
	look_at_from_position(_center + offset, _center, Vector3.UP)
