class_name LowPoly
extends RefCounted
## Fábrica de mallas placeholder con el estilo del juego:
## moderadamente low poly (pocas caras, se notan las facetas) y sombreado "auto smooth":
## normales suaves en superficies curvas, bordes duros en tapas y cajas.
## Nunca usar primitivas de Godot con la cantidad de segmentos por defecto.

const SEGMENTS := 8   ## segmentos radiales por defecto para cosas redondas

static func mat(color: Color, roughness := 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func instance(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	return mi

static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return instance(b, color)

static func cylinder(radius: float, height: float, color: Color, segments := SEGMENTS, top_radius := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return instance(c, color)

static func cone(radius: float, height: float, color: Color, segments := SEGMENTS) -> MeshInstance3D:
	return cylinder(radius, height, color, segments, radius * 0.15)

static func sphere(radius: float, color: Color, segments := SEGMENTS, rings := 5) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = rings
	return instance(s, color)

static func capsule(radius: float, height: float, color: Color, segments := SEGMENTS) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 2
	return instance(c, color)

## Aro (volante, neumático). ring_segments = caras del tubo.
static func torus(radius: float, thickness: float, color: Color, rings := 14, ring_segments := 6) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness * 0.5
	t.outer_radius = radius + thickness * 0.5
	t.rings = rings
	t.ring_segments = ring_segments
	return instance(t, color)

static func label(text: String, size := 32, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 6
	return l
