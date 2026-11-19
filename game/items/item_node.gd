class_name ItemNode
extends Grabbable
## Un ítem dentro de un overlay, con física 2D (sin profundidad, siempre mirando al jugador).
##
## Regla única:
##   - Agarrado es un "fantasma": sin física, no choca con nada, sigue a la mano por toda la pantalla.
##   - Al soltarlo en un lugar libre vuelve a tener física, con la velocidad del mouse.
##   - Si el lugar no es válido (encima de algo, en una pared, afuera), vuelve a donde lo agarraste.
## (Soltarlo sobre una ventana lo resuelve el Desktop antes de llegar acá.)

var data: ItemData
var surface: ItemSurface
var body: RigidBody2D

var _grab_offset := Vector2.ZERO  ## del punto agarrado al centro del cuerpo (px)
var _target_px := Vector2.ZERO
var _hand_velocity := Vector2.ZERO
var _origin_pos := Vector2.ZERO
var _origin_rot := 0.0
var _visual: Node3D

const MAX_SPEED_PX := 6000.0

func setup(p_data: ItemData, p_surface: ItemSurface) -> void:
	data = p_data
	surface = p_surface
	priority = 5
	_visual = data.make_visual(surface.units_per_meter, surface.view)
	add_child(_visual)

	body = RigidBody2D.new()
	body.mass = maxf(data.weight, 0.2)
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.can_sleep = false   # si duerme no siente la inercia de la van
	var pm := PhysicsMaterial.new()
	if surface.view == "top":
		pm.friction = 0.5
		pm.bounce = 0.1
		body.linear_damp = 2.5    # el piso de la caja los frena
		body.angular_damp = 4.0
	else:
		pm.friction = 0.6
		pm.bounce = 0.2
		body.linear_damp = 0.1
		body.angular_damp = 2.0
	body.physics_material_override = pm
	var col := CollisionShape2D.new()
	var size_px := surface.item_size(data) * ItemSurface.PX
	if data.shape == "round" and surface.view == "side":
		var cap := CapsuleShape2D.new()
		cap.radius = size_px.y * 0.5
		cap.height = size_px.x
		col.shape = cap
		col.rotation = PI / 2.0
	else:
		var r := RectangleShape2D.new()
		r.size = size_px
		col.shape = r
	body.add_child(col)
	surface.physics_root.add_child(body)

func _exit_tree() -> void:
	if is_instance_valid(body):
		body.queue_free()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body):
		return
	if held_by:
		var new_pos := _target_px + _grab_offset
		_hand_velocity = _hand_velocity.lerp((new_pos - body.position) / delta, 0.5)
		body.position = new_pos
	else:
		_keep_inside()

func _process(_delta: float) -> void:
	sync_visual()

func sync_visual() -> void:
	var l := ItemSurface.from_px(body.position)
	var lift := 0.0
	if surface.view == "top":
		lift = data.dims.y * surface.units_per_meter * 0.5   # apoyado en el piso, el alto hacia la cámara
	position = Vector3(l.x, l.y, surface.z + lift)
	rotation.z = -body.rotation

func local_center() -> Vector2:
	return ItemSurface.from_px(body.position)

func hit_test(p: Vector2) -> bool:
	var q := body.to_local(ItemSurface.to_px(surface.local_at(p)))
	var half := surface.item_size(data) * ItemSurface.PX * 0.5 + Vector2(6, 6)
	return absf(q.x) <= half.x and absf(q.y) <= half.y

## ¿Se puede soltar acá, donde está ahora?
func can_drop_here() -> bool:
	return surface.can_place(data, local_center(), rotation.z, body)

func on_grab(_hand: Hand, p: Vector2) -> void:
	var at := ItemSurface.to_px(surface.local_at(p))
	_grab_offset = body.position - at
	_target_px = at
	_hand_velocity = Vector2.ZERO
	_origin_pos = body.position
	_origin_rot = body.rotation
	body.freeze = true            # fantasma: sin física y sin chocar
	body.collision_layer = 0
	body.collision_mask = 0

func on_drag(_hand: Hand, p: Vector2) -> void:
	_target_px = ItemSurface.to_px(surface.local_at(p))

func on_release(_hand: Hand, _p: Vector2) -> void:
	var ok := can_drop_here()
	body.collision_layer = 1
	body.collision_mask = 1
	if ok:
		body.freeze = false
		body.linear_velocity = _hand_velocity.limit_length(MAX_SPEED_PX)
		body.angular_velocity = 0.0
	else:
		body.position = _origin_pos   # lugar inválido: vuelve a donde estaba
		body.rotation = _origin_rot
		body.freeze = false
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
	surface.changed.emit()

## Red de seguridad: si algo se escapó de las paredes, vuelve adentro.
func _keep_inside() -> void:
	var l := ItemSurface.from_px(body.position)
	var half := surface.item_size(data) * 0.5
	if l.y < surface.floor_y - 0.3 or l.y > surface.ceiling_y + 0.3 \
			or l.x < surface.x_min - 0.3 or l.x > surface.x_max + 0.3:
		l.x = clampf(l.x, surface.x_min + half.x, surface.x_max - half.x)
		l.y = clampf(l.y, surface.floor_y + half.y, surface.ceiling_y - half.y)
		body.position = ItemSurface.to_px(l)
		body.linear_velocity = Vector2.ZERO
