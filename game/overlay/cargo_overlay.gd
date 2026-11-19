class_name CargoOverlay
extends Overlay
## Overlay del espacio "caja de atrás". Se ve la caja de costado (vista oblicua):
## los paquetes se apilan y lo que pongas acá aparece adentro de la van en el mundo.

var van: Van
var surface: ItemSurface

const WALL := Color(0.78, 0.78, 0.75)

func build() -> void:
	world_focus_y = 1.9
	# Se ve la caja de costado y sin techo: lo de arriba queda libre para ver el mundo.
	var back := LowPoly.box(Vector3(8.8, 3.4, 0.2), WALL)
	back.position = Vector3(0, -2.8, -1.7)
	root3d.add_child(back)
	var floor_box := LowPoly.box(Vector3(8.8, 0.25, 1.8), Color(0.35, 0.33, 0.3))
	floor_box.position = Vector3(0, -4.625, -0.8)
	root3d.add_child(floor_box)
	for x in [-4.5, 4.5]:
		var post := LowPoly.box(Vector3(0.25, 3.5, 1.8), Color(0.9, 0.9, 0.88))
		post.position = Vector3(x, -2.85, -0.8)
		root3d.add_child(post)
	var lip := LowPoly.box(Vector3(9.25, 0.18, 0.3), Color(0.9, 0.9, 0.88))
	lip.position = Vector3(0, -1.05, -1.65)
	root3d.add_child(lip)
	var title := LowPoly.label("← fondo          caja de la van          puerta →", 20, Color(0.95, 0.95, 0.95))
	title.position = Vector3(0, -0.75, -1.65)
	root3d.add_child(title)

	surface = add_surface(ItemSurface.new())
	surface.x_min = -4.35
	surface.x_max = 4.35
	surface.floor_y = -4.5
	surface.ceiling_y = -1.15
	surface.z = -0.8
	surface.changed.connect(func() -> void: van.set_cargo(surface.snapshot()))

func _physics_process(_delta: float) -> void:
	# Los paquetes se mueven con la física: la van los muestra donde están.
	if surface and Engine.get_physics_frames() % 3 == 0:
		van.set_cargo(surface.snapshot())
