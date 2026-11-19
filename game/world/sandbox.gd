extends Node3D
## Sandbox para probar cómo se siente manejar. Sin loop de juego.
## Argumentos de línea de comando (después de "--"):
##   --selftest         maneja solo unos segundos, imprime datos y saca captura
##   --shot=ruta.png    dónde guardar la captura del autotest

var van: Van
var cabin: CabinOverlay
var desktop: Desktop

func _ready() -> void:
	randomize()
	_build_props()

	van = preload("res://game/van/van.gd").new()
	van.name = "Van"
	van.position = Vector3(0, 1.0, 0)
	add_child(van)

	desktop = Desktop.new()
	desktop.name = "Desktop"
	add_child(desktop)
	desktop.setup(van, $IsoCamera, self)
	cabin = desktop.cabin

	if "--selftest" in OS.get_cmdline_user_args():
		_selftest()

func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Calles: franjas oscuras en cuadrícula
	for i in range(-3, 4):
		_static_box(Vector3(8, 0.02, 200), Vector3(i * 30, 0.01, 0), Color(0.3, 0.3, 0.32))
		_static_box(Vector3(200, 0.02, 8), Vector3(0, 0.012, i * 30), Color(0.3, 0.3, 0.32))
	# Edificios en las manzanas
	for bx in range(-3, 3):
		for bz in range(-3, 3):
			var center := Vector3(bx * 30 + 15, 0, bz * 30 + 15)
			if center.length() < 20:
				continue  # dejar libre el lugar de inicio
			var h := rng.randf_range(3, 9)
			var s := Vector3(rng.randf_range(10, 18), h, rng.randf_range(10, 18))
			_static_box(s, center + Vector3(0, h / 2, 0),
				Color(0.75, 0.68, 0.6).lerp(Color(0.6, 0.65, 0.75), rng.randf()), true)
	# Conos que se pueden chocar
	for i in 30:
		var cone := RigidBody3D.new()
		cone.mass = 4
		cone.position = Vector3(rng.randf_range(-12, 12), 0.4, rng.randf_range(-40, 40))
		if cone.position.length() < 6:
			cone.position.z += 10
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25
		shape.height = 0.8
		col.shape = shape
		cone.add_child(col)
		var m := LowPoly.cone(0.28, 0.8, Color(1, 0.45, 0.1), 7)
		cone.add_child(m)
		add_child(cone)

func _static_box(size: Vector3, pos: Vector3, color: Color, collide := false) -> void:
	var n: Node3D = StaticBody3D.new() if collide else Node3D.new()
	n.position = pos
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	n.add_child(m)
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		n.add_child(col)
	add_child(n)

# ---------------------------------------------------------------- autotest

func _selftest() -> void:
	var f := cabin.feet_override
	var log := func(tag: String) -> void:
		print("[selftest] %s  t=%.1f motor=%s marcha=%s rpm=%d vel=%.1f km/h pos=%s" % [
			tag, Time.get_ticks_msec() / 1000.0, van.engine_on, van.controls.gear,
			van.rpm, van.speed_kmh, van.global_position.snapped(Vector3.ONE * 0.1)])
	f["clutch"] = 0.0; f["throttle"] = 0.0; f["brake"] = 0.0
	# Sin embrague: la palanca real tiene que dejar meter 1ra con el mouse
	var gl := cabin.gear_lever
	var g0 := gl.global_position
	_mouse(g0, true)
	_mouse(g0 + Vector3(-gl.step, 0, 0), true, true)
	_mouse(g0 + Vector3(-gl.step, gl.step, 0), true, true)
	_mouse(g0 + Vector3(-gl.step, gl.step, 0), false)
	print("[selftest] marcha con la palanca, sin embrague: ", van.controls.gear)
	await _wait(0.5)
	_mouse(cabin.key.global_position, true)   # clic real en la llave
	_mouse(cabin.key.global_position, false)
	await _wait(1.2)
	log.call("arrancado")
	cabin.gear_lever.force_gear(1)
	await _wait(0.3)
	f["throttle"] = 0.5
	for i in 10:
		f["clutch"] = 1.0 - (i + 1) / 10.0
		await _wait(0.1)
	f["throttle"] = 0.9
	await _wait(2.0)
	log.call("en 1ra")
	f["throttle"] = 0.0; f["clutch"] = 1.0
	await _wait(0.2)
	cabin.gear_lever.force_gear(2)
	await _wait(0.2)
	f["clutch"] = 0.0; f["throttle"] = 0.9
	await _wait(1.5)
	log.call("en 2da")
	var dash_x_before := _dash_xs()
	# Arrastre real del volante: agarrar arriba y girar en sentido horario.
	var c := cabin.wheel.global_position
	var r := cabin.wheel.radius
	_mouse(c + Vector3(0, r, 0), true)
	for i in 12:
		var a := PI / 2 - deg_to_rad(15.0 * (i + 1))
		_mouse(c + Vector3(cos(a), sin(a), 0) * r, true, true)
		await _wait(0.03)
	_mouse(c + Vector3(cos(PI/2 - deg_to_rad(180)), sin(PI/2 - deg_to_rad(180)), 0) * r, false)
	print("[selftest] volante: %.0f°  steer=%.2f" % [rad_to_deg(cabin.wheel.angle), van.controls.steer])
	await _wait(0.8)
	log.call("doblando a la derecha")
	print("[selftest] inercia al doblar a la derecha, x en el tablero: ", dash_x_before, " -> ", _dash_xs())
	_shot("1_manejando")
	f["throttle"] = 0.0; f["brake"] = 1.0; f["clutch"] = 1.0
	await _wait(2.5)
	log.call("frenado")
	f.clear()
	await _selftest_interaction()
	get_tree().quit()

func _selftest_interaction() -> void:
	var p1 := desktop.players[0]
	var p2 := desktop.players[1]
	var ch := p1.character
	var hunger_before := ch.hunger

	# 1) Comer: empanada del tablero → pasar sobre el personaje (abre ventana) → soltar en la ventana
	var emp: ItemNode = null
	for n in cabin.dash_surface.items():
		if n.data.display_name == "Empanada":
			emp = n
	_mouse_screen(cabin.camera.unproject_position(emp.global_position), true)
	await _wait(0.1)
	var char_screen := desktop.world_camera.unproject_position(ch.global_position + Vector3(0, 1.0, 0))
	_mouse_screen(char_screen, true, true)
	await _wait(0.3)
	var win := desktop.windows.find_window("char:%d" % ch.get_instance_id()) as CharacterWindow
	print("[selftest] ventana abierta al pasar arrastrando: ", win != null)
	var center := win.get_global_rect().position + Vector2(70, 90)  # sobre el retrato
	_mouse_screen(center, true, true)
	await _wait(0.1)
	_mouse_screen(center, false)
	await _wait(0.2)
	print("[selftest] hambre %.1f -> %.1f ; empanada en tablero: %s" % [hunger_before, ch.hunger,
		cabin.dash_surface.items().any(func(n: ItemNode) -> bool: return n.data.display_name == "Empanada")])

	# 2) Mano del otro: el jugador 2 agarra el volante y lo deja agarrado
	desktop.switch_player()
	var wc := cabin.wheel.global_position
	_mouse_screen(cabin.camera.unproject_position(wc + Vector3(cabin.wheel.radius, 0, 0)), true)
	_mouse_screen(cabin.camera.unproject_position(wc + Vector3(cabin.wheel.radius * 0.7, cabin.wheel.radius * 0.7, 0)), true, true)
	desktop.switch_player()
	await _wait(0.3)
	print("[selftest] J2 sostiene el volante: ", p2.hand.held == cabin.wheel)
	_shot("2_comer_y_mano_j2")
	cabin.hand_release(p2.hand, p2.hand.pos)

	# 3) Tirar la gaseosa para arriba: tiene que volar, girar y caer (no volver a su lugar)
	var can: ItemNode = null
	for n in cabin.dash_surface.items():
		if n.data.display_name == "Gaseosa":
			can = n
	var c0 := can.local_center()
	var s0 := cabin.camera.unproject_position(can.global_position)
	_mouse_screen(s0, true)
	for i in 4:
		await get_tree().physics_frame
		_mouse_screen(s0 + Vector2(-12, -30) * (i + 1), true, true)
	await get_tree().physics_frame
	_mouse_screen(s0 + Vector2(-48, -120), false)
	await get_tree().physics_frame
	print("[selftest] gaseosa tirada: vel=%s" % can.body.linear_velocity.round())
	await _wait(0.25)
	_shot("2b_gaseosa_volando")
	await _wait(1.5)
	print("[selftest] gaseosa: antes %s -> ahora %s, rotación %.0f°" % [c0, can.local_center(), rad_to_deg(can.rotation.z)])

	# 4) Clic en el piso NO te baja; E sí. Después caminar a la caja de atrás
	_mouse_screen(desktop.world_camera.unproject_position(van.to_global(Vector3(5, 0, 0))), true)
	_mouse_screen(Vector2.ZERO, false)
	await _wait(0.3)
	print("[selftest] clic en el piso desde la cabina -> espacio='%s' (tiene que seguir 'cabin')" % p1.space)
	var ek := InputEventKey.new()
	ek.physical_keycode = KEY_E
	ek.pressed = true
	Input.parse_input_event(ek)
	await _wait(0.2)
	_mouse_screen(desktop.world_camera.unproject_position(van.to_global(Vector3(5, 0, 0))), true)
	_mouse_screen(Vector2.ZERO, false)
	await _wait(2.0)
	print("[selftest] J1 espacio='%s' sentado=%s" % [p1.space, ch.seat != null])
	_mouse_screen(desktop.world_camera.unproject_position(van.to_global(Vector3(0, 1.7, -1.2))), true)
	_mouse_screen(Vector2.ZERO, false)
	for i in 30:
		await _wait(0.2)
		if p1.space == "cargo":
			break
	print("[selftest] J1 espacio='%s'  masa van=%.0f kg" % [p1.space, van.mass])

	# 4) Paquete de la caja → mano del personaje (ventana)
	win.position = Vector2(1150, 330)
	var pkg: ItemNode = desktop.cargo.surface.items()[0]
	var n_before := desktop.cargo.surface.items().size()
	_mouse_screen(desktop.cargo.camera.unproject_position(pkg.global_position), true)
	await _wait(0.1)
	var slot := win.hand_slot.get_global_rect().get_center()
	_mouse_screen(slot, true, true)
	await _wait(0.1)
	_mouse_screen(slot, false)
	await _wait(0.4)
	print("[selftest] en la mano: %s ; paquetes en caja %d -> %d ; masa van=%.0f kg" % [
		ch.held_item.display_name if ch.held_item else "nada", n_before, desktop.cargo.surface.items().size(), van.mass])
	_shot("3_caja_y_mano")

	# 5) De la mano de vuelta a la caja
	_mouse_screen(slot, true)
	await _wait(0.1)
	var target := desktop.cargo.plane_to_screen(Vector2(3.0, -3.0))
	_mouse_screen(target, true, true)
	await _wait(0.1)
	_mouse_screen(target, false)
	await _wait(0.3)
	print("[selftest] mano: %s ; paquetes en caja: %d" % [
		ch.held_item.display_name if ch.held_item else "vacía", desktop.cargo.surface.items().size()])

func _dash_xs() -> Array:
	var out := []
	for n in cabin.dash_surface.items():
		out.append(n.local_center().snapped(Vector2(0.01, 0.01)))
	return out

func _shot(tag: String) -> void:
	var base := "user://selftest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			base = a.trim_prefix("--shot=").trim_suffix(".png")
	var path := "%s_%s.png" % [base, tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("[selftest] captura: ", path)

func _mouse_screen(screen: Vector2, pressed: bool, motion := false) -> void:
	var ev: InputEventMouse
	if motion:
		ev = InputEventMouseMotion.new()
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		ev = b
	if screen == Vector2.ZERO:
		screen = get_viewport().get_mouse_position()
	ev.position = screen
	ev.global_position = screen
	Input.warp_mouse(screen)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

## Simula el mouse sobre un punto del overlay de la cabina (coordenadas 3D del overlay).
func _mouse(overlay_point: Vector3, pressed: bool, motion := false) -> void:
	_mouse_screen(cabin.camera.unproject_position(overlay_point), pressed, motion)

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, true).timeout
