class_name ItemNode
extends Grabbable
## Un ítem dentro de un overlay, con física 2D (sin profundidad, siempre mirando al jugador).
## Regla simple: agarrado NO tiene física (sigue a la mano); al soltarlo vuelve a tenerla
## con la velocidad con que lo soltaste. Así se puede tirar y volver a agarrar en el aire.

var data: ItemData
var surface: ItemSurface
var body: RigidBody2D

var _grab_offset := Vector2.ZERO  ## del punto agarrado al centro del cuerpo (px)
var _target_px := Vector2.ZERO
var _hand_velocity := Vector2.ZERO

const MAX_SPEED_PX := 6000.0

func setup(p_data: ItemData, p_surface: ItemSurface) -> void:
	data = p_data
	surface = p_surface
	priority = 5
	add_child(data.make_visual())

	body = RigidBody2D.new()
	body.mass = maxf(data.weight, 0.2)
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.can_sleep = false   # si duerme no siente la inercia de la van
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.15
	body.physics_material_override = pm
	var col := CollisionShape2D.new()
	var px := ItemSurface.PX
	match data.shape:
		"round":
			var cap := CapsuleShape2D.new()
			cap.radius = data.size.y * 0.5 * px
			cap.height = data.size.x * px
			col.shape = cap
			col.rotation = PI / 2.0
		_:
			var r := RectangleShape2D.new()
			r.size = data.size * px
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
		var half := data.size * ItemSurface.PX * 0.5
		var lo := ItemSurface.to_px(Vector2(surface.x_min, surface.ceiling_y)) + half
		var hi := ItemSurface.to_px(Vector2(surface.x_max, surface.floor_y)) - half
		var new_pos := (_target_px + _grab_offset).clamp(lo, hi)
		_hand_velocity = _hand_velocity.lerp((new_pos - body.position) / delta, 0.5)
		body.position = new_pos
	else:
		_physics_process_safety()

func _physics_process_safety() -> void:
	# Red de seguridad: si algo se escapó de las paredes, vuelve adentro.
	var l := ItemSurface.from_px(body.position)
	if l.y < surface.floor_y - 0.3 or l.y > surface.ceiling_y + 0.3 			or l.x < surface.x_min - 0.3 or l.x > surface.x_max + 0.3:
		l.x = clampf(l.x, surface.x_min + data.size.x * 0.5, surface.x_max - data.size.x * 0.5)
		l.y = clampf(l.y, surface.floor_y + data.size.y * 0.5, surface.ceiling_y - data.size.y * 0.5)
		body.position = ItemSurface.to_px(l)
		body.linear_velocity = Vector2.ZERO

func _process(_delta: float) -> void:
	var l := ItemSurface.from_px(body.position)
	position = Vector3(l.x, l.y, surface.z)
	rotation.z = -body.rotation

func local_center() -> Vector2:
	return ItemSurface.from_px(body.position)

func hit_test(p: Vector2) -> bool:
	var q := body.to_local(ItemSurface.to_px(surface.local_at(p)))
	var half := data.size * ItemSurface.PX * 0.5 + Vector2(6, 6)
	return absf(q.x) <= half.x and absf(q.y) <= half.y

func on_grab(_hand: Hand, p: Vector2) -> void:
	var at := ItemSurface.to_px(surface.local_at(p))
	_grab_offset = body.position - at
	_target_px = at
	_hand_velocity = Vector2.ZERO
	body.freeze = true            # agarrado: sin física

func on_drag(_hand: Hand, p: Vector2) -> void:
	_target_px = ItemSurface.to_px(surface.local_at(p))

func on_release(_hand: Hand, _p: Vector2) -> void:
	body.freeze = false           # suelto: física, con la velocidad de la mano
	body.linear_velocity = _hand_velocity.limit_length(MAX_SPEED_PX)
	body.angular_velocity = clampf(_hand_velocity.x * 0.004, -12.0, 12.0)
