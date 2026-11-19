class_name HandsLayer
extends CanvasLayer
## Dibuja las manos de los OTROS jugadores que están en tu mismo espacio.
## Mano abierta = libre; puño = agarrando algo.

var desktop: Desktop
var _canvas: Control

func _ready() -> void:
	layer = 40
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hands)
	add_child(_canvas)

func _process(_delta: float) -> void:
	_canvas.queue_redraw()

func _draw_hands() -> void:
	if desktop == null:
		return
	var me := desktop.local
	var ov := desktop.overlay_for(me.space)
	if ov == null:
		return
	for p in desktop.players:
		if p == me or p.space != me.space:
			continue
		var at := ov.plane_to_screen(p.hand.pos)
		draw_hand(_canvas, at, p.color, p.hand.is_busy())
		_canvas.draw_string(ThemeDB.fallback_font, at + Vector2(18, 30), p.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, p.color)

static func draw_hand(c: CanvasItem, at: Vector2, color: Color, closed: bool) -> void:
	var outline := Color(0.1, 0.1, 0.12)
	if closed:
		c.draw_circle(at + Vector2(0, 8), 15, outline)
		c.draw_circle(at + Vector2(0, 8), 13, color)
		for i in 4:
			var k := at + Vector2(-9 + i * 6, -3)
			c.draw_circle(k, 4.5, outline)
			c.draw_circle(k, 3.5, color.lightened(0.15))
	else:
		for i in 4:
			var r := Rect2(at + Vector2(-11 + i * 6, -20 + absf(i - 1.5) * 3), Vector2(5, 18))
			c.draw_rect(r.grow(1.5), outline)
			c.draw_rect(r, color.lightened(0.15))
		c.draw_rect(Rect2(at + Vector2(10, -2), Vector2(9, 5)).grow(1.5), outline)
		c.draw_rect(Rect2(at + Vector2(10, -2), Vector2(9, 5)), color.lightened(0.15))
		c.draw_circle(at + Vector2(0, 8), 14, outline)
		c.draw_circle(at + Vector2(0, 8), 12.5, color)
