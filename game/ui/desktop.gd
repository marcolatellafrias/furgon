class_name Desktop
extends Node
## El "sistema operativo" del juego. Reparte el input del jugador local entre
## ventanas > overlay de su espacio > mundo, y maneja el arrastre universal de ítems.
##
## Regla única de soltar: soltás un ítem sobre un destino y el destino decide si lo acepta.
## Si pasás arrastrando sobre una entidad del mundo, se abre su ventana (como la barra de tareas).
## Si nadie lo acepta, el ítem vuelve a donde estaba.
##
## Debug: F2 cambia de jugador (hot-seat) para probar el cooperativo con un solo mouse.

static var instance: Desktop

var van: Van
var world_camera: Camera3D
var players: Array[Player] = []
var local: Player

var cabin: CabinOverlay
var cargo: CargoOverlay
var drag_layer: DragLayer
var hands_layer: HandsLayer
var windows: WindowManager

var _hover_opened := {}   # entidades cuyas ventanas ya se abrieron en este arrastre
var _hint: Label

func setup(p_van: Van, p_camera: Camera3D, world: Node3D) -> void:
	instance = self
	van = p_van
	world_camera = p_camera

	cabin = CabinOverlay.new()
	cabin.van = van
	cabin.space_id = "cabin"
	add_child(cabin)
	cargo = CargoOverlay.new()
	cargo.van = van
	cargo.space_id = "cargo"
	add_child(cargo)
	for ov: Overlay in [cabin, cargo]:
		ov.item_grab_requested.connect(_on_item_grab_requested)

	windows = WindowManager.new()
	add_child(windows)
	drag_layer = DragLayer.new()
	add_child(drag_layer)
	hands_layer = HandsLayer.new()
	hands_layer.desktop = self
	add_child(hands_layer)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 4)
	var hint_layer := CanvasLayer.new()
	hint_layer.layer = 30
	hint_layer.add_child(_hint)
	add_child(hint_layer)

	# Dos jugadores: uno al volante y otro de acompañante.
	var specs := [["Jugador 1", Color(0.25, 0.55, 0.9)], ["Jugador 2", Color(0.85, 0.3, 0.35)]]
	for i in specs.size():
		var p := Player.new(i + 1, specs[i][0], specs[i][1])
		var ch := Character.new()
		ch.display_name = p.display_name
		ch.color = p.color
		world.add_child(ch)
		ch.global_position = van.door_point(van.driver_seat) + Vector3(0, 0, -i * 1.0)
		p.character = ch
		players.append(p)
		_enter_cabin(p)
	local = players[0]

	# Cosas iniciales
	cabin.dash_surface.place_at_local_x(ItemData.make_food("Empanada", "round", Vector2(0.9, 0.45), Color(0.85, 0.6, 0.3), 30), 1.0)
	cabin.dash_surface.place_at_local_x(ItemData.make_food("Gaseosa", "can", Vector2(0.4, 0.75), Color(0.75, 0.1, 0.1), 10), 2.0)
	var map := ItemData.new()
	map.display_name = "Mapa"
	map.kind = "document"
	map.shape = "flat"
	map.size = Vector2(1.3, 0.7)
	map.depth = 0.08
	map.color = Color(0.85, 0.82, 0.65)
	map.weight = 0.2
	cabin.dash_surface.place_at_local_x(map, 6.5)
	var x := 3.6
	for spec in [["Paquete chico", Vector2(1.0, 0.8), 4.0], ["Paquete", Vector2(1.4, 1.1), 12.0],
			["Caja pesada", Vector2(1.6, 1.3), 35.0], ["Paquete", Vector2(1.2, 0.9), 8.0]]:
		cargo.surface.place_at_local_x(ItemData.make_package(spec[0], spec[1], spec[2]), x)
		x -= 1.7
	cargo.surface.place_at_local_x(ItemData.make_package("Sobre", Vector2(0.9, 0.3), 1.0), 1.9)

# ---------------------------------------------------------------- estado

func overlay_for(space: String) -> Overlay:
	match space:
		"cabin": return cabin
		"cargo": return cargo
	return null

func active_overlay() -> Overlay:
	return overlay_for(local.space)

func _process(_delta: float) -> void:
	cabin.visible = local.space == "cabin"
	cargo.visible = local.space == "cargo"
	cabin.feet_enabled = local.space == "cabin" and local.character.seat == van.driver_seat
	var inside := van.occupied_seats() > 0
	for p in players:
		inside = inside or p.space == "cargo"
	van.interior.set_occupied(inside)
	world_camera.target = local.character
	var ov := active_overlay()
	world_camera.screen_focus = ov.world_focus_y / (Overlay.VIEW_HEIGHT * 0.5) if ov else 0.0
	_hint.position = Vector2(12, get_viewport().get_visible_rect().size.y - 24) if local.space == "" else Vector2(12, 40)
	_hint.text = "%s  ·  F2: cambiar de jugador  ·  %s" % [local.display_name, _space_hint()]

func _space_hint() -> String:
	match local.space:
		"cabin":
			return "W/S/Espacio: pedales (solo conductor) · clic en el piso: bajarse" if local.character.seat == van.driver_seat \
				else "acompañante: usá las manos · clic en el piso: bajarse"
		"cargo":
			return "arrastrá paquetes · clic en el piso: irte"
	return "clic en el piso: caminar · clic en la cabina: subir · clic en la caja: abrirla"

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# El arrastre de ítems se resuelve antes que la interfaz, porque puede terminar sobre una ventana.
	var hand := local.hand
	if hand.carrying == null:
		return
	if event is InputEventMouseMotion:
		drag_layer.move_item(hand, event.position)
		var ov := active_overlay()
		if ov:
			hand.pos = ov.screen_to_plane(event.position)
		_hover_world(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		switch_player()
		return
	var ov := active_overlay()
	var hand := local.hand
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if hand.carrying:
				return
			if ov and ov.hand_press(hand, ov.screen_to_plane(event.position)):
				get_viewport().set_input_as_handled()
				return
			_world_click(event.position)
		elif ov and ov.hand_release(hand, ov.screen_to_plane(event.position)):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var shape := Input.CURSOR_ARROW
		if ov:
			var p := ov.screen_to_plane(event.position)
			if ov.hand_move(hand, p):
				shape = Input.CURSOR_DRAG
			elif ov.grabbable_at(p, hand):
				shape = Input.CURSOR_POINTING_HAND
		if hand.carrying:
			shape = Input.CURSOR_DRAG
		Input.set_default_cursor_shape(shape)

func switch_player() -> void:
	var i := (players.find(local) + 1) % players.size()
	local = players[i]

# ---------------------------------------------------------------- arrastre universal

func begin_carry(item: ItemData, return_to: Callable) -> void:
	var hand := local.hand
	hand.carrying = item
	hand.carry_return = return_to
	_hover_opened.clear()
	drag_layer.show_item(hand, item)
	drag_layer.move_item(hand, get_viewport().get_mouse_position())

func _on_item_grab_requested(node: ItemNode, hand: Hand) -> void:
	if hand != local.hand:
		return
	var surface := node.surface
	var x := node.position.x
	var item := surface.take(node)
	begin_carry(item, func(it: ItemData) -> void: surface.place_at_local_x(it, x, true))

func _drop(screen: Vector2) -> void:
	var hand := local.hand
	var item := hand.carrying
	hand.carrying = null
	drag_layer.hide_item(hand)
	var back := hand.carry_return
	hand.carry_return = Callable()

	var w := windows.window_at(screen)
	if w:
		if w.can_accept(item, screen) and w.accept_drop(item, screen):
			return
	else:
		var ov := active_overlay()
		if ov:
			var p := ov.screen_to_plane(screen)
			var s := ov.surface_at(p)
			if s and s.try_place(item, p):
				return
	back.call(item)

## Arrastrando sobre un personaje del mundo → se abre su ventana para soltar ahí.
func _hover_world(screen: Vector2) -> void:
	if windows.window_at(screen):
		return
	var hit := _ray(screen, 1 << (Character.LAYER_CHARACTERS - 1), false)
	if hit and hit.collider is Character and not _hover_opened.has(hit.collider):
		_hover_opened[hit.collider] = true
		open_character_window(hit.collider, screen)

# ---------------------------------------------------------------- mundo

func _world_click(screen: Vector2) -> void:
	var hit := _ray(screen, 1 << (Character.LAYER_CHARACTERS - 1), false)
	if hit and hit.collider is Character:
		open_character_window(hit.collider, screen)
		return
	hit = _ray(screen, 1 << (Van.LAYER_ZONES - 1), true)
	if hit:
		if hit.collider == van.cabin_zone:
			go_to_cabin(local)
		elif hit.collider == van.rear_zone:
			go_to_cargo(local)
		return
	hit = _ray(screen, 1, false)
	if hit:
		walk(local, hit.position)

func _ray(screen: Vector2, mask: int, areas: bool) -> Dictionary:
	var from := world_camera.project_ray_origin(screen)
	var to := from + world_camera.project_ray_normal(screen) * 500.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_areas = areas
	q.collide_with_bodies = not areas
	return world_camera.get_world_3d().direct_space_state.intersect_ray(q)

func open_character_window(ch: Character, near: Vector2) -> CharacterWindow:
	return windows.open("char:%d" % ch.get_instance_id(), func() -> GameWindow: return CharacterWindow.new(ch), near)

# ---------------------------------------------------------------- moverse entre espacios

func _leave_space(p: Player) -> void:
	var ov := overlay_for(p.space)
	if ov:
		ov.release_all(p.hand)
	var ch := p.character
	if ch.seat:
		var door := van.door_point(ch.seat)
		van.seat_occupant[ch.seat] = null
		ch.stand_up(door)
	p.space = ""

func walk(p: Player, point: Vector3) -> void:
	_leave_space(p)
	p.character.walk_to(point)

func go_to_cabin(p: Player) -> void:
	if p.space == "cabin":
		return
	var seat := van.free_seat()
	if seat == null:
		return
	_leave_space(p)
	p.character.walk_to(van.door_point(seat), func() -> void: _enter_cabin(p))

func _enter_cabin(p: Player) -> void:
	var seat := van.free_seat()
	if seat == null or van.speed_kmh > 4.0:
		return
	van.seat_occupant[seat] = p.character
	p.character.sit(seat)
	p.space = "cabin"

func go_to_cargo(p: Player) -> void:
	if p.space == "cargo":
		return
	_leave_space(p)
	p.character.walk_to(van.rear_point(), func() -> void:
		if p.character.global_position.distance_to(van.rear_point()) < 1.5:
			p.space = "cargo")
