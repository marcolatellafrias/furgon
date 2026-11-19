class_name Character
extends CharacterBody3D
## Personaje en el mundo isométrico. Camina con clic, se sienta en la van,
## tiene hambre y puede sostener UN ítem en la mano.

signal stats_changed

const LAYER_CHARACTERS := 2
const SPEED := 3.6

@export var display_name := "Personaje"
@export var color := Color(0.25, 0.55, 0.9)

var hunger := 25.0            ## 0 = lleno, 100 = muerto de hambre
var hunger_rate := 0.6        ## por segundo
var held_item: ItemData = null:
	set(v):
		held_item = v
		_refresh_held()
		stats_changed.emit()

var seat: Marker3D = null     ## si no es null, está sentado ahí

var _target := Vector3.ZERO
var _path: Array[Vector3] = []
var _walking := false
var _on_arrive: Callable
var _visual: Node3D
var _held_visual: Node3D

func _ready() -> void:
	collision_layer = 1 << (LAYER_CHARACTERS - 1)
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)
	var body := LowPoly.capsule(0.28, 1.0, color, 8)
	body.position.y = 0.6
	_visual.add_child(body)
	var head := make_head(color)
	head.position.y = 1.35
	_visual.add_child(head)

## Cabeza low poly; también la usa el retrato de la ventana.
static func make_head(p_color: Color) -> Node3D:
	var h := Node3D.new()
	h.add_child(LowPoly.sphere(0.24, Color(0.93, 0.78, 0.65), 8, 5))
	var hair := LowPoly.sphere(0.25, p_color.darkened(0.5), 8, 5)
	hair.scale = Vector3(1.0, 0.55, 1.0)
	hair.position = Vector3(0, 0.1, -0.02)
	h.add_child(hair)
	for x in [-0.08, 0.08]:
		var eye := LowPoly.box(Vector3(0.05, 0.07, 0.03), Color(0.1, 0.1, 0.12))
		eye.position = Vector3(x, 0.02, 0.22)
		h.add_child(eye)
	return h

func _physics_process(delta: float) -> void:
	hunger = minf(100.0, hunger + hunger_rate * delta)
	if Engine.get_physics_frames() % 15 == 0:
		stats_changed.emit()

	if seat:
		global_transform = seat.global_transform.translated_local(Vector3(0, -0.45, 0))
		return

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var flat := Vector3(_target.x - global_position.x, 0, _target.z - global_position.z)
	if _walking and flat.length() < 0.25 and not _path.is_empty():
		_target = _path.pop_front()
		flat = Vector3(_target.x - global_position.x, 0, _target.z - global_position.z)
	if _walking and flat.length() < 0.25:
		_walking = false
		var cb := _on_arrive
		_on_arrive = Callable()
		if cb.is_valid():
			cb.call()
	if _walking:
		var dir := flat.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

func walk_to(point: Vector3, on_arrive := Callable()) -> void:
	walk_path([point], on_arrive)

## Camina por varios puntos en orden; al llegar al último llama on_arrive.
func walk_path(points: Array[Vector3], on_arrive := Callable()) -> void:
	_path = points.duplicate()
	_target = _path.pop_front()
	_walking = true
	_on_arrive = on_arrive

func is_walking() -> bool:
	return _walking

func sit(p_seat: Marker3D) -> void:
	seat = p_seat
	_walking = false
	collision_mask = 0
	_visual.rotation.y = 0.0

func stand_up(at: Vector3) -> void:
	seat = null
	global_transform = Transform3D(Basis.IDENTITY, at)
	collision_mask = 1

func eat(item: ItemData) -> void:
	hunger = maxf(0.0, hunger - item.nutrition)
	stats_changed.emit()

func _refresh_held() -> void:
	if _held_visual:
		_held_visual.queue_free()
		_held_visual = null
	if held_item and _visual:
		_held_visual = held_item.make_visual(1.0, "side")
		_held_visual.position = Vector3(0, 0.85, 0.3 + held_item.dims.z * 0.5)
		_visual.add_child(_held_visual)
