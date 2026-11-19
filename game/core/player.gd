class_name Player
extends RefCounted
## Un jugador: una mano (cursor), un personaje en el mundo y el espacio donde está.
## space: "" = afuera (sin overlay), "cabin" = cabina, "cargo" = caja de atrás.

var id := 0
var display_name := ""
var color := Color.WHITE
var hand: Hand
var character: Character
var space := ""

func _init(p_id: int, p_name: String, p_color: Color) -> void:
	id = p_id
	display_name = p_name
	color = p_color
	hand = Hand.new(p_id)
