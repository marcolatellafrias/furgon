class_name Hand
extends RefCounted
## Una mano = un jugador dentro de un overlay. Hoy la mueve el mouse local;
## más adelante, la red. Agarra una sola cosa a la vez.

var id := 0
var pos := Vector2.ZERO      ## posición en el plano del overlay
var held: Grabbable = null

func _init(p_id := 0) -> void:
	id = p_id
