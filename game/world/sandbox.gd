extends Node3D
## Sandbox para probar cómo se siente manejar. Sin loop de juego.
## Argumentos de línea de comando (después de "--"):
##   --selftest         maneja solo unos segundos, imprime datos y saca captura
##   --shot=ruta.png    dónde guardar la captura del autotest

var van: Van
var cabin: CabinOverlay

func _ready() -> void:
	randomize()
	_build_props()

	van = preload("res://game/van/van.gd").new()
	van.name = "Van"
	van.position = Vector3(0, 1.0, 0)
	add_child(van)

	# Conductor sentado (placeholder). Está "adentro" → techo y paredes se desvanecen.
	var driver := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.1
	driver.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.9)
	driver.material_override = mat
	driver.position = Vector3(0, 0.6, 0)
	van.driver_seat.add_child(driver)
	van.interior.set_occupied(true)

	$IsoCamera.target = van

	cabin = CabinOverlay.new()
	cabin.van = van
	add_child(cabin)

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
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.28
		cm.height = 0.8
		m.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.45, 0.1)
		m.material_override = mat
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
	f["clutch"] = 1.0; f["throttle"] = 0.0; f["brake"] = 0.0
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
	var shot := "user://selftest.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	get_viewport().get_texture().get_image().save_png(shot)
	print("[selftest] captura: ", shot)
	f["throttle"] = 0.0; f["brake"] = 1.0
	await _wait(2.0)
	log.call("frenado")
	get_tree().quit()

## Simula el mouse sobre un punto del overlay (en coordenadas 3D del overlay).
func _mouse(overlay_point: Vector3, pressed: bool, motion := false) -> void:
	var screen := cabin.camera.unproject_position(overlay_point)
	var ev: InputEventMouse
	if motion:
		ev = InputEventMouseMotion.new()
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		ev = b
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, true).timeout
