class_name Interior
extends Node3D
## Interior genérico (van, edificio…): cuando hay alguien adentro, el techo y las paredes
## que tapan la vista de la cámara se vuelven transparentes.
##
## Cada "oclusor" es una malla con una normal hacia afuera (en espacio local del interior).
## Normal cero = siempre se desvanece (techo). Si no, solo cuando esa cara mira a la cámara.

@export var faded_alpha := 0.12
@export var fade_speed := 6.0

var occupants := 0

var _occluders: Array[Dictionary] = []  # {mesh, material, outward, alpha}

func add_occluder(mesh: MeshInstance3D, outward: Vector3 = Vector3.ZERO) -> void:
	var mat := mesh.get_active_material(0)
	mat = (mat.duplicate() if mat else StandardMaterial3D.new()) as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mesh.material_override = mat
	_occluders.append({"mesh": mesh, "material": mat, "outward": outward, "alpha": 1.0})

func set_occupied(value: bool) -> void:
	occupants = 1 if value else 0

func is_occupied() -> bool:
	return occupants > 0

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_basis.z  # en ortográfica, la dirección hacia la cámara es constante
	for o in _occluders:
		var fade := false
		if is_occupied():
			var outward: Vector3 = o.outward
			fade = outward == Vector3.ZERO or (global_basis * outward).dot(to_cam) > 0.15
		var target := faded_alpha if fade else 1.0
		o.alpha = move_toward(o.alpha, target, fade_speed * delta)
		var mat: StandardMaterial3D = o.material
		mat.albedo_color.a = o.alpha
		# Si casi no se ve, que no proyecte sombra que confunda.
		(o.mesh as MeshInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if o.alpha > 0.5
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
