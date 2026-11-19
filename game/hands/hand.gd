class_name Hand
extends RefCounted
## La mano de un jugador. Agarra UNA cosa a la vez:
## - held: un mando de overlay que está sosteniendo (volante, palanca…)
## - carrying: un ítem que está arrastrando entre contenedores
## La posición es en el plano del overlay donde está (compartido entre jugadores del mismo espacio).

var id := 0
var pos := Vector2.ZERO
var held: Grabbable = null
var carrying: ItemData = null
var carry_return: Callable   ## devuelve el ítem a su lugar si el soltar falla

func _init(p_id := 0) -> void:
	id = p_id

func is_busy() -> bool:
	return held != null or carrying != null
