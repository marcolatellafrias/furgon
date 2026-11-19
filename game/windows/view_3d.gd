class_name View3D
extends SubViewportContainer
## Mini escena 3D dentro de la interfaz (retratos, ítems en ranuras).
## Usa la misma vista oblicua que los overlays para que todo se vea igual.

var viewport: SubViewport
var camera: Camera3D
var root3d: Node3D
var spin := 0.0   ## giro suave en Y (rad/s) para retratos

func _init(px_size := Vector2i(120, 120), ortho_size := 1.6, perspective := false) -> void:
	stretch = true
	custom_minimum_size = px_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = px_size
	add_child(viewport)
	camera = Camera3D.new()
	if perspective:
		camera.fov = 30
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ortho_size
	camera.position = Vector3(0, 0, 6)
	viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	root3d = Node3D.new()
	if not perspective:
		root3d.transform = Transform3D(Overlay.oblique_basis(), Vector3.ZERO)
	viewport.add_child(root3d)

func set_content(n: Node3D) -> void:
	for c in root3d.get_children():
		c.queue_free()
	if n:
		root3d.add_child(n)

func _process(delta: float) -> void:
	if spin != 0.0:
		for c in root3d.get_children():
			(c as Node3D).rotation.y = sin(Time.get_ticks_msec() / 1000.0 * spin) * 0.5
