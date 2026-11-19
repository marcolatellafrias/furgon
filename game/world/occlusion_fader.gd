class_name OcclusionFader
extends Node
## Regla: tu personaje siempre se ve. Cada cuadro tira rayos desde la cámara hacia unos
## puntos (tu personaje) y todo lo "desvanecible" que quede en el medio se vuelve transparente.
## Para que algo se pueda desvanecer: OcclusionFader.make_fadeable(cuerpo, malla).

const META := "fade_mesh"

@export var faded_alpha := 0.18
@export var fade_speed := 6.0

var camera: Camera3D
var targets: Callable          ## () -> Array[Vector3]

var _alpha := {}               # MeshInstance3D -> alpha actual

## Marca un cuerpo con colisión como desvanecible: si tapa al personaje, su malla se vuelve transparente.
static func make_fadeable(body: CollisionObject3D, mesh: MeshInstance3D) -> void:
	body.set_meta(META, mesh)

func _physics_process(delta: float) -> void:
	if camera == null or not targets.is_valid():
		return
	var blocking := {}
	var space := camera.get_world_3d().direct_space_state
	var to_cam := camera.global_basis.z   # cámara ortográfica: misma dirección para todos los rayos
	for t: Vector3 in targets.call():
		var exclude: Array[RID] = []
		for i in 6:   # puede haber varias cosas en el medio
			var q := PhysicsRayQueryParameters3D.create(t + to_cam * 200.0, t, 1)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var col: Object = hit.collider
			exclude.append(hit.rid)
			if col.has_meta(META):
				blocking[col.get_meta(META)] = true

	for m in blocking:
		if not _alpha.has(m):
			_alpha[m] = 1.0
	for m: MeshInstance3D in _alpha.keys():
		if not is_instance_valid(m):
			_alpha.erase(m)
			continue
		var target := faded_alpha if blocking.has(m) else 1.0
		var a := move_toward(_alpha[m], target, fade_speed * delta)
		_alpha[m] = a
		var mat := m.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = a
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if a >= 1.0 \
				else BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		if a >= 1.0 and not blocking.has(m):
			_alpha.erase(m)

## Cuántas cosas están desvanecidas ahora (para pruebas).
func faded_count() -> int:
	var n := 0
	for m in _alpha:
		if _alpha[m] < 0.5:
			n += 1
	return n
