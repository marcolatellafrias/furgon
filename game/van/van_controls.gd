class_name VanControls
extends Resource
## Estado compartido de los mandos de la van.
## Lo escriben las manos (overlay), los pies (teclado) y, más adelante, la red.
## Lo lee la física de la van. Es el único punto de contacto entre la interfaz y el vehículo.

@export_range(-1.0, 1.0) var steer := 0.0     ## -1 izquierda, +1 derecha
@export_range(0.0, 1.0) var throttle := 0.0
@export_range(0.0, 1.0) var brake := 0.0
@export_range(0.0, 1.0) var clutch := 0.0     ## 1 = pisado a fondo (motor desacoplado)
@export_range(-1, 4) var gear := 0            ## -1 R, 0 N, 1..4

## Cada giro de llave suma 1. La van compara con el último que vio:
## si el motor está apagado intenta arrancar, si está prendido lo apaga.
var ignition_turns := 0

func turn_key() -> void:
	ignition_turns += 1

static func gear_name(g: int) -> String:
	match g:
		-1: return "R"
		0: return "N"
		_: return str(g)
