class_name Desktop
extends Node
## El "sistema operativo" del juego. Reparte el input del jugador local entre
## ventanas > overlay de su espacio > mundo, y maneja el arrastre universal de ítems.
##
## Regla única de soltar: soltás un ítem sobre un destino y el destino decide si lo acepta.
## Si pasás arrastrando sobre una entidad del mundo, se abre su ventana (como la barra de tareas).
## Si nadie lo acepta, el ítem vuelve a donde estaba.
##
## E = salir del espacio (bajarse de la cabina / irse de la caja). Mientras estás en un espacio,
## hacer clic en el mundo no te saca (solo se pueden abrir ventanas de personajes).
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

	# Cosas iniciales. Tablero: de costado con gravedad. Caja: desde arriba.
	var dash := cabin.dash_surface
	dash.spawn(ItemData.make_food("Empanada", "round", Vector3(0.15, 0.07, 0.1), Color(0.85, 0.6, 0.3), 30), Vector2(1.0, -2.4))
	dash.spawn(ItemData.make_food("Gaseosa", "can", Vector3(0.066, 0.125, 0.066), Color(0.75, 0.1, 0.1), 10), Vector2(2.0, -2.4))
	var map := ItemData.new()
	map.display_name = "Mapa"
	map.kind = "document"
	map.shape = "flat"
	map.dims = Vector3(0.22, 0.12, 0.012)
	map.color = Color(0.85, 0.82, 0.65)
	map.weight = 0.2
	dash.spawn(map, Vector2(6.5, -2.4))
	var bed := cargo.surface
	var cy := CargoOverlay.CENTER_Y
	bed.spawn(ItemData.make_package("Paquete chico", Vector3(0.45, 0.3, 0.35), 4.0), Vector2(-2.4, cy + 0.6))
	bed.spawn(ItemData.make_package("Paquete", Vector3(0.6, 0.4, 0.45), 12.0), Vector2(-1.0, cy - 0.5))
	bed.spawn(ItemData.make_package("Caja pesada", Vector3(0.7, 0.55, 0.6), 35.0), Vector2(0.6, cy + 0.3))
	bed.spawn(ItemData.make_package("Paquete", Vector3(0.5, 0.35, 0.4), 8.0), Vector2(2.1, cy))
	bed.spawn(ItemData.make_package("Sobre", Vector3(0.35, 0.04, 0.25), 1.0), Vector2(2.5, cy + 1.2))

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
	var inside := van.occupied_seats() > 0
	for p in players:
		inside = inside or p.space == "cargo"
	van.interior.set_occupied(inside)
	world_camera.target = local.character
	_update_lifted()
	var ov := active_overlay()
	world_camera.screen_focus = ov.world_focus_y / (Overlay.VIEW_HEIGHT * 0.5) if ov else 0.0
	_hint.position = Vector2(12, get_viewport().get_visible_rect().size.y - 24) if local.space == "" else Vector2(12, 40)
	_hint.text = "%s  ·  F2: cambiar de jugador  ·  %s" % [local.display_name, _space_hint()]

func _space_hint() -> String:
	match local.space:
		"cabin":
			return "todo con el mouse · E: bajarse"
		"cargo":
			return "arrastrá y tirá paquetes · E: irte"
	return "clic en el piso: caminar · clic en la cabina: subir · clic en la caja: abrirla"

# ---------------------------------------------------------------- input

var _lifted: ItemNode = null
var _hovered: Object = null

## Lo que tenés agarrado se dibuja arriba de todo (sobre las ventanas), verde si se puede
## soltar donde está el mouse y rojo si no.
func _update_lifted() -> void:
	var hand := local.hand
	var mouse := get_viewport().get_mouse_position()
	var node := hand.held as ItemNode if hand.held is ItemNode else null
	if node != _lifted:
		if is_instance_valid(_lifted):
			_lifted.visible = true
		if hand.carrying == null:
			drag_layer.hide_item(hand)
		_lifted = node
	if _lifted:
		var s := _lifted.surface
		drag_layer.show_item(hand, _lifted.data, s.units_per_meter, s.view)
		_lifted.visible = false
		drag_layer.place_local(hand, _lifted.position, _lifted.rotation.z)
		drag_layer.set_tint(hand, _can_drop_held(_lifted, mouse))
	elif hand.carrying:
		var s := _surface_under(mouse)
		if s:
			drag_layer.show_item(hand, hand.carrying, s.units_per_meter, s.view)
		else:
			drag_layer.show_item(hand, hand.carrying)
		drag_layer.move_item(hand, mouse)
		drag_layer.set_tint(hand, _can_drop_carry(hand.carrying, mouse))

func _surface_under(screen: Vector2) -> ItemSurface:
	var ov := active_overlay()
	if ov == null or windows.window_at(screen):
		return null
	return ov.surface_at(ov.screen_to_plane(screen))

func _can_drop_held(node: ItemNode, screen: Vector2) -> bool:
	var w := windows.window_at(screen)
	if w:
		return w.can_accept(node.data, screen)
	return node.can_drop_here()

func _can_drop_carry(item: ItemData, screen: Vector2) -> bool:
	var w := windows.window_at(screen)
	if w:
		return w.can_accept(item, screen)
	var s := _surface_under(screen)
	if s:
		return s.can_place(item, s.local_at(active_overlay().screen_to_plane(screen)))
	return false

func _physics_process(_delta: float) -> void:
	# Inercia (fuerza que sienten los objetos, en ejes de pantalla de cada overlay).
	# Van: +X local = izquierda, +Z = adelante.
	# Tablero (de costado): x de pantalla = derecha de la van → doblar los empuja.
	cabin.dash_surface.set_inertia(Vector2(van.local_accel.x, 0.0), van.local_accel.y)
	# Caja (desde arriba): x = hacia la puerta (atrás), y = derecha de la van.
	cargo.surface.set_inertia(Vector2(van.local_accel.z, van.local_accel.x), 0.0)

func _input(event: InputEvent) -> void:
	# Los arrastres se resuelven antes que la interfaz, porque pueden pasar por encima de una ventana.
	var hand := local.hand
	if hand.carrying == null:
		if not hand.held is ItemNode:
			return
		var ov := active_overlay()
		var node := hand.held as ItemNode
		if event is InputEventMouseMotion:
			ov.hand_move(hand, ov.screen_to_plane(event.position))
			_hover_world(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var w := windows.window_at(event.position)
			if w and w.can_accept(node.data, event.position):
				hand.held = null
				node.held_by = null
				w.accept_drop(node.surface.take(node), event.position)
			else:
				ov.hand_release(hand, ov.screen_to_plane(event.position))   # el ítem decide: física o vuelve
		return
	if event is InputEventMouseMotion:
		var ov := active_overlay()
		if ov:
			hand.pos = ov.screen_to_plane(event.position)
		_hover_world(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F2:
				switch_player()
			KEY_E:
				if local.space != "":
					_leave_space(local)
		return
	var ov := active_overlay()
	var hand := local.hand
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if hand.carrying:
				return
			if ov and ov.hand_press(hand, ov.screen_to_plane(event.position)):
				_set_hover(null)
				get_viewport().set_input_as_handled()
				return
			_world_click(event.position)
		elif ov and ov.hand_release(hand, ov.screen_to_plane(event.position)):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var shape := Input.CURSOR_ARROW
		var on_overlay := false
		if ov:
			var p := ov.screen_to_plane(event.position)
			if ov.hand_move(hand, p):
				shape = Input.CURSOR_DRAG
				on_overlay = true
			elif ov.grabbable_at(p, hand):
				shape = Input.CURSOR_POINTING_HAND
				on_overlay = true
		if hand.is_busy():
			shape = Input.CURSOR_DRAG
		elif not on_overlay:
			_set_hover(_world_target(event.position))
			if _hovered:
				shape = Input.CURSOR_POINTING_HAND
		if on_overlay:
			_set_hover(null)
		Input.set_default_cursor_shape(shape)

func switch_player() -> void:
	var i := (players.find(local) + 1) % players.size()
	local = players[i]

# ---------------------------------------------------------------- arrastre universal

## Arrastrar algo que no está en un overlay (por ejemplo, lo que hay en la mano de un personaje).
func begin_carry(item: ItemData, return_to: Callable) -> void:
	var hand := local.hand
	hand.carrying = item
	hand.carry_return = return_to
	_hover_opened.clear()
	_update_lifted()

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
		var s := _surface_under(screen)
		if s:
			var local_p := s.local_at(active_overlay().screen_to_plane(screen))
			if s.can_place(item, local_p):
				s.spawn(item, local_p)
				return
	back.call(item)   # lugar inválido: vuelve a donde estaba

## Arrastrando sobre un personaje del mundo → se abre su ventana para soltar ahí.
func _hover_world(screen: Vector2) -> void:
	if windows.window_at(screen):
		_set_hover(null)
		return
	var ch := _character_at(screen)
	_set_hover(ch)
	if ch and not _hover_opened.has(ch):
		_hover_opened[ch] = true
		open_character_window(ch, screen)

func _character_at(screen: Vector2) -> Character:
	var hit := _ray(screen, 1 << (Character.LAYER_CHARACTERS - 1), false)
	return hit.collider as Character if hit else null

## Qué se puede usar en el mundo bajo el mouse (para el contorno).
func _world_target(screen: Vector2) -> Object:
	if windows.window_at(screen):
		return null
	var ch := _character_at(screen)
	if ch:
		return ch
	if local.space != "":
		return null
	var hit := _ray(screen, 1 << (Van.LAYER_ZONES - 1), true)
	return hit.collider if hit else null

func _set_hover(t: Object) -> void:
	if t == _hovered:
		return
	_outline(_hovered, false)
	_hovered = t
	_outline(t, true)

func _outline(t: Object, on: bool) -> void:
	if t == null or not is_instance_valid(t):
		return
	if t is Character:
		LowPoly.set_outline(t, on)
	elif t == van.cabin_zone:
		van.set_outline("cabin", on)
	elif t == van.rear_zone:
		van.set_outline("cargo", on)

# ---------------------------------------------------------------- mundo

func _world_click(screen: Vector2) -> void:
	var hit := _ray(screen, 1 << (Character.LAYER_CHARACTERS - 1), false)
	if hit and hit.collider is Character:
		open_character_window(hit.collider, screen)
		return
	if local.space != "":
		return   # dentro de un espacio, el mundo no te saca (para eso está la E)
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
	var ch := p.character
	ch.walk_path(van.route(ch.global_position, van.door_point(seat)), func() -> void: _enter_cabin(p))

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
	var ch := p.character
	ch.walk_path(van.route(ch.global_position, van.rear_point()), func() -> void:
		if p.character.global_position.distance_to(van.rear_point()) < 1.5:
			p.space = "cargo")
