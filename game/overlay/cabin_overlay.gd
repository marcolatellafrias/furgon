class_name CabinOverlay
extends Overlay
## Overlay del espacio "cabina de la van". Lo ven igual los dos asientos de adelante.
## Abajo: tablero (volante, llave, instrumentos, palanca, pedales, guantera).
## Arriba: espejo retrovisor, que muestra el mundo real desde atrás de la van.
##
## Todo se maneja con las manos (mouse). Nada del tablero se usa con teclado.

var van: Van

var wheel: SteeringWheelControl
var gear_lever: GearLeverControl
var key: IgnitionKeyControl
var pedals := {}   # property -> PedalControl

## Solo para el autotest: fuerza el valor de pedales sin usar el mouse.
var feet_override := {}
var dash_surface: ItemSurface

var _speed_label: Label3D
var _rpm_label: Label3D
var _gear_label: Label3D
var _engine_light: Label3D
var _msg_label: Label3D
var _msg_timer := 0.0
var _last_msg := ""
var _mirror_cam: Camera3D

const DASH := Color(0.2, 0.2, 0.22)

func build() -> void:
	world_focus_y = 0.6
	var c := van.controls

	# Tablero y marco superior
	# El tablero tiene profundidad: con la vista oblicua se ve su superficie de arriba,
	# que es donde después van a ir los ítems (comida, mapa, papeles…).
	var dash := Grabbable.box(Vector3(40, 2.4, 2.0), DASH)
	dash.position = Vector3(0, -4.1, -1.2)
	root3d.add_child(dash)
	var dash_top := Grabbable.box(Vector3(40, 0.04, 2.0), Color(0.3, 0.3, 0.32))
	dash_top.position = Vector3(0, -2.9, -1.2)
	root3d.add_child(dash_top)
	var header := Grabbable.box(Vector3(40, 0.7, 0.5), DASH)
	header.position = Vector3(0, 4.75, -0.6)
	root3d.add_child(header)

	# Instrumentos
	var cluster := Grabbable.box(Vector3(2.6, 1.35, 0.1), Color(0.08, 0.08, 0.09))
	cluster.position = Vector3(-1.4, -3.35, -0.15)
	root3d.add_child(cluster)
	_speed_label = _add_label("0 km/h", Vector3(-1.4, -2.95, 0), 40)
	_rpm_label = _add_label("0 rpm", Vector3(-1.4, -3.3, 0), 26, Color(0.7, 0.85, 1))
	_gear_label = _add_label("N", Vector3(-2.3, -3.7, 0), 34, Color(1, 0.85, 0.4))
	_engine_light = _add_label("MOTOR", Vector3(-1.1, -3.7, 0), 22, Color(1, 0.25, 0.2))
	_msg_label = _add_label("", Vector3(0, -2.15, 0.5), 30, Color(1, 0.9, 0.3))

	# Volante (lado izquierdo: conductor)
	wheel = SteeringWheelControl.new()
	wheel.controls = c
	wheel.van = van
	wheel.position = Vector3(-4.4, -3.1, 0.5)
	root3d.add_child(wheel)

	key = IgnitionKeyControl.new()
	key.controls = c
	key.van = van
	key.position = Vector3(-1.4, -4.4, 0.1)
	root3d.add_child(key)

	gear_lever = GearLeverControl.new()
	gear_lever.controls = c
	gear_lever.position = Vector3(1.6, -3.9, 0.1)
	root3d.add_child(gear_lever)

	var x := -8.2
	for spec in [["clutch", "E"], ["brake", "F"], ["throttle", "A"]]:
		var p := PedalControl.new()
		p.property = spec[0]
		p.title = spec[1]
		p.controls = c
		p.position = Vector3(x, -4.3, 0)
		root3d.add_child(p)
		pedals[spec[0]] = p
		if spec[0] == "clutch" and not c.clutch_enabled:
			p.visible = false   # embrague automático: no hay pedal
		if spec[0] != "clutch" and c.gear_sets_speed:
			p.visible = false   # la marcha dicta la velocidad y N frena: no hay pedales
		x += 0.75

	# Guantera (todavía no se abre)
	var glove := Grabbable.box(Vector3(2.8, 1.1, 0.1), Color(0.26, 0.26, 0.28))
	glove.position = Vector3(5.6, -3.8, -0.15)
	root3d.add_child(glove)
	_add_label("guantera", Vector3(5.6, -3.8, -0.1), 22, Color(0.6, 0.6, 0.6))

	_build_mirror()

	# Superficie del tablero: acá se apoyan cosas (y más adelante tapan la vista).
	dash_surface = add_surface(ItemSurface.new())
	dash_surface.x_min = -8.6
	dash_surface.x_max = 8.6
	dash_surface.floor_y = -2.9
	dash_surface.ceiling_y = -0.4
	dash_surface.z = -1.2

func _build_mirror() -> void:
	var frame := Grabbable.box(Vector3(3.7, 1.15, 0.2), Color(0.1, 0.1, 0.1))
	frame.position = Vector3(0, 3.9, -0.3)
	root3d.add_child(frame)

	# El espejo ve el mundo real: un SubViewport que comparte el mundo de la van.
	var mirror_vp := SubViewport.new()
	mirror_vp.size = Vector2i(720, 180)
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	van.add_child(mirror_vp)
	_mirror_cam = Camera3D.new()
	_mirror_cam.fov = 45
	mirror_vp.add_child(_mirror_cam)

	var quad := QuadMesh.new()
	quad.size = Vector2(3.4, 0.85)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = mirror_vp.get_texture()
	mat.uv1_scale = Vector3(-1, 1, 1)   # los espejos invierten izquierda/derecha
	mat.uv1_offset = Vector3(1, 0, 0)
	var surface := MeshInstance3D.new()
	surface.mesh = quad
	surface.material_override = mat
	surface.position = Vector3(0, 3.9, -0.15)
	root3d.add_child(surface)

func _add_label(text: String, pos: Vector3, size := 32, color := Color.WHITE) -> Label3D:
	var l := Grabbable.label(text, size, color)
	l.position = pos
	root3d.add_child(l)
	return l

func _process(delta: float) -> void:
	if van == null:
		return
	_mirror_cam.global_transform = van.mirror_anchor.global_transform

	for prop in pedals:
		(pedals[prop] as PedalControl).foot_value = feet_override.get(prop, 0.0)

	# Tablero
	_speed_label.text = "%d km/h" % roundi(van.speed_kmh)
	_rpm_label.text = "%d rpm" % roundi(van.rpm)
	_gear_label.text = VanControls.gear_name(van.controls.gear)
	_engine_light.visible = not van.engine_on
	_engine_light.text = "arrancando…" if van.cranking else "MOTOR"

	# Mensajes: cada mensaje nuevo de la van se muestra 2.5 s.
	if van.last_message != "" and van.last_message != _last_msg:
		_msg_timer = 2.5
	_last_msg = van.last_message
	_msg_timer -= delta
	if _msg_timer <= 0.0:
		van.last_message = ""
		_last_msg = ""
	if gear_lever.grinding > 0.0:
		_msg_label.text = "¡CRRRK! Pisá el embrague"
	else:
		_msg_label.text = van.last_message
