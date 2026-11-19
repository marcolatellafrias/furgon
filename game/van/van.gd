class_name Van
extends VehicleBody3D
## La van. Lee VanControls y simula motor, embrague, caja y ruedas.
## Adelante = +Z local. El lado izquierdo (conductor) = +X local.
## Por ahora la geometría se arma por código con cajas (placeholder).

signal engine_started
signal engine_stopped(reason: String)

@export var controls: VanControls

@export_group("Motor")
@export var max_torque := 260.0        ## Nm
@export var idle_rpm := 800.0
@export var max_rpm := 5200.0
@export var engine_brake_torque := 45.0
@export var stall_enabled := true
@export var crank_time := 0.7
@export var final_drive := 4.1

@export_group("Ruedas")
@export var wheel_radius := 0.42
@export var max_steer_deg := 32.0
@export var max_brake := 60.0           ## por rueda
@export var front_grip := 2.2
@export var rear_grip := 2.0

## Velocidad a la que va la van en cada marcha cuando gear_sets_speed está activo.
@export var gear_speeds_kmh := {-1: 8.0, 1: 12.0, 2: 25.0, 3: 40.0, 4: 60.0}

const RATIOS := {-1: -3.6, 0: 0.0, 1: 3.8, 2: 2.3, 3: 1.5, 4: 1.0}

## Telemetría (solo lectura para el tablero)
var engine_on := false
var cranking := false
var rpm := 0.0
var speed_kmh := 0.0
var last_message := ""  ## ej: "¡Se paró!" — el tablero lo muestra

var interior: Interior
var mirror_anchor: Marker3D
var driver_seat: Marker3D
var passenger_seat: Marker3D
var seat_occupant := {}          ## Marker3D (asiento) -> Character o null
var cabin_zone: Area3D           ## clic acá = subir a la cabina
var rear_zone: Area3D            ## clic acá = ir a la caja de atrás

const LAYER_ZONES := 3
const BASE_MASS := 1800.0
var cargo_weight := 0.0
var _cargo_visual: Node3D
var _cargo_nodes := {}            ## ItemData -> Node3D
## Aceleración que siente la van, en su espacio local (m/s²). La usan los overlays
## para que los objetos se deslicen al acelerar, frenar o doblar.
var local_accel := Vector3.ZERO
var _prev_velocity := Vector3.ZERO

var _front_wheels: Array[VehicleWheel3D] = []
var _rear_wheels: Array[VehicleWheel3D] = []
var _seen_ignition := 0
var _crank_timer := 0.0

func _ready() -> void:
	if controls == null:
		controls = VanControls.new()
	mass = BASE_MASS
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.45, 0)
	_build_body()
	_build_wheels()
	seat_occupant = {driver_seat: null, passenger_seat: null}
	cabin_zone = _zone(Vector3(2.1, 1.9, 1.9), Vector3(0, 1.6, 1.45))
	rear_zone = _zone(Vector3(2.1, 2.0, 3.4), Vector3(0, 1.7, -0.95))

# ---------------------------------------------------------------- asientos y puertas

func free_seat() -> Marker3D:
	for s in [driver_seat, passenger_seat]:
		if seat_occupant[s] == null:
			return s
	return null

func door_point(seat: Marker3D) -> Vector3:
	var side := 1.0 if seat == driver_seat else -1.0
	return to_global(Vector3(1.75 * side, 0.2, 1.3))

func rear_point() -> Vector3:
	return to_global(Vector3(0, 0.2, -3.7))

## Camino para rodear la van caminando (sin atravesarla): agrega una esquina si hace falta.
func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var lf := to_local(from)
	var lt := to_local(to)
	var out: Array[Vector3] = []
	var behind_from := lf.z < -2.6
	var behind_to := lt.z < -2.6
	if behind_from != behind_to:
		var side := signf(lf.x if not behind_from else lt.x)
		if side == 0.0:
			side = 1.0
		out.append(to_global(Vector3(side * 1.9, 0.2, -3.1)))
	out.append(to)
	return out

func occupied_seats() -> int:
	var n := 0
	for s in seat_occupant:
		if seat_occupant[s] != null:
			n += 1
	return n

# ---------------------------------------------------------------- carga

## entries: [{data: ItemData, x, y}] en coordenadas del overlay de la caja.
## Se dibuja dentro de la van y el peso cambia cómo anda.
const CARGO_SCALE := 0.36            ## unidades de overlay → metros
const CARGO_OVERLAY_FLOOR := -4.5
func set_cargo(entries: Array) -> void:
	var seen := {}
	cargo_weight = 0.0
	var moment := 0.0
	for e in entries:
		var d: ItemData = e.data
		seen[d] = true
		var pivot: Node3D = _cargo_nodes.get(d)
		if pivot == null:
			# pivot girado 90°: su +X local apunta a la puerta de atrás (-Z de la van)
			pivot = Node3D.new()
			pivot.rotation_degrees.y = 90
			var v := d.make_visual()
			v.name = "V"
			v.scale = Vector3.ONE * CARGO_SCALE
			pivot.add_child(v)
			_cargo_visual.add_child(pivot)
			_cargo_nodes[d] = pivot
		# x del overlay: izquierda = fondo (pegado a la cabina), derecha = puerta de atrás
		var z: float = 0.63 - (float(e.x) + 4.35) * CARGO_SCALE
		var y: float = 0.85 + (float(e.y) - CARGO_OVERLAY_FLOOR) * CARGO_SCALE
		pivot.position = Vector3(0, y, z)
		(pivot.get_node("V") as Node3D).rotation.z = e.rot
		cargo_weight += d.weight
		moment += d.weight * z
	for d in _cargo_nodes.keys():
		if not seen.has(d):
			_cargo_nodes[d].queue_free()
			_cargo_nodes.erase(d)
	mass = BASE_MASS + cargo_weight
	center_of_mass.z = moment / mass

func _zone(size: Vector3, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 1 << (LAYER_ZONES - 1)
	a.collision_mask = 0
	a.monitoring = false
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	a.add_child(col)
	a.position = pos
	add_child(a)
	return a

# ---------------------------------------------------------------- simulación

func _physics_process(delta: float) -> void:
	var c := controls
	var throttle := c.throttle
	var auto_brake := 0.0
	if c.gear_sets_speed:
		# La marcha dicta la velocidad: acelera hasta llegar y frena suave si se pasa.
		var target: float = gear_speeds_kmh.get(c.gear, 0.0)
		var speed_in_gear := linear_velocity.dot(global_basis.z) * 3.6 * (-1.0 if c.gear == -1 else 1.0)
		if c.gear != 0:
			throttle = clampf((target - speed_in_gear) / 6.0, 0.0, 1.0) * (1.0 - clampf(c.brake * 2.0, 0.0, 1.0))
			auto_brake = clampf((speed_in_gear - target - 2.0) / 12.0, 0.0, 0.35)
		else:
			throttle = 0.0
			auto_brake = 0.45   # punto muerto = frenar hasta parar (no hay pedal de freno)
	var accel := (linear_velocity - _prev_velocity) / delta
	_prev_velocity = linear_velocity
	local_accel = local_accel.lerp(global_basis.inverse() * accel, 0.25)
	var fwd_speed := linear_velocity.dot(global_basis.z)
	speed_kmh = absf(fwd_speed) * 3.6

	_update_ignition(delta)

	var ratio: float = RATIOS[c.gear] * final_drive
	var engagement := 0.0 if c.gear == 0 else 1.0 - clampf(c.clutch, 0.0, 1.0)
	# Embrague automático: a poca velocidad el motor "patina" (rpm libres), después acopla.
	var rpm_engagement := engagement
	if not c.clutch_enabled and c.gear != 0:
		engagement = 1.0
		rpm_engagement = clampf(wheel_rpm_for(fwd_speed, ratio) / (idle_rpm * 2.0), 0.0, 1.0)
	# rpm que tendría el motor si estuviera acoplado del todo a las ruedas
	var wheel_rpm := fwd_speed / (TAU * wheel_radius) * 60.0 * ratio

	var force := 0.0
	if engine_on:
		var free_rpm := idle_rpm + throttle * (max_rpm - idle_rpm)
		var target_rpm := lerpf(free_rpm, maxf(wheel_rpm, idle_rpm * 0.5), rpm_engagement)
		rpm = move_toward(rpm, target_rpm, 7000.0 * delta)

		if stall_enabled and c.clutch_enabled and engagement > 0.85 and wheel_rpm < 350.0 and throttle < 0.15:
			_stop_engine("¡Se paró el motor!")
		elif c.gear != 0:
			var torque := throttle * max_torque * _torque_curve(rpm)
			if rpm >= max_rpm:
				torque = 0.0
			if throttle < 0.05:
				torque = -engine_brake_torque * clampf(rpm / max_rpm, 0.0, 1.0)
			force = torque * ratio / wheel_radius * engagement
	elif not cranking:
		rpm = move_toward(rpm, 0.0, 3000.0 * delta)

	var steer_rad := -c.steer * deg_to_rad(max_steer_deg)  # steering positivo = izquierda
	# Sin nadie al volante, freno de mano puesto (por ahora automático).
	var brake := maxf(c.brake, auto_brake) if seat_occupant.get(driver_seat) != null else 1.0
	for w in _front_wheels:
		w.steering = steer_rad
		w.brake = brake * max_brake
	for w in _rear_wheels:
		w.engine_force = force / _rear_wheels.size()
		w.brake = brake * max_brake

func _update_ignition(delta: float) -> void:
	if controls.ignition_turns != _seen_ignition:
		_seen_ignition = controls.ignition_turns
		if engine_on or cranking:
			cranking = false
			_stop_engine("Motor apagado")
		elif controls.clutch_enabled and controls.gear != 0 and controls.clutch < 0.6:
			last_message = "Pisá el embrague o poné punto muerto"
		else:
			cranking = true
			_crank_timer = crank_time
			last_message = ""
	if cranking:
		_crank_timer -= delta
		rpm = 250.0 + sin(_crank_timer * 40.0) * 80.0
		if _crank_timer <= 0.0:
			cranking = false
			engine_on = true
			rpm = idle_rpm * 1.3
			engine_started.emit()

func _stop_engine(reason: String) -> void:
	if not engine_on:
		return
	engine_on = false
	last_message = reason
	engine_stopped.emit(reason)

func wheel_rpm_for(fwd_speed: float, ratio: float) -> float:
	return fwd_speed / (TAU * wheel_radius) * 60.0 * ratio

func _torque_curve(r: float) -> float:
	var t := clampf(r / max_rpm, 0.0, 1.0)
	return 0.65 + 0.35 * sin(t * PI)

# ---------------------------------------------------------------- geometría

const WHITE := Color(0.92, 0.92, 0.9)
const DARK := Color(0.2, 0.21, 0.24)

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.8, 5.0)
	col.shape = shape
	col.position = Vector3(0, 1.6, 0)
	add_child(col)

	interior = Interior.new()
	interior.name = "Interior"
	add_child(interior)

	# Piso y frente (no se desvanecen)
	_box(Vector3(2.0, 0.2, 5.0), Vector3(0, 0.75, 0), DARK)
	_box(Vector3(2.0, 0.75, 0.7), Vector3(0, 1.2, 2.15), WHITE)          # trompa
	_box(Vector3(2.04, 0.12, 0.2), Vector3(0, 0.95, 2.5), DARK)          # paragolpes
	var glass := _box(Vector3(1.9, 0.85, 0.05), Vector3(0, 2.0, 2.2), Color(0.55, 0.75, 0.9, 0.35))
	(glass.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Cabina
	interior.add_occluder(_box(Vector3(0.08, 1.6, 1.6), Vector3(0.96, 1.65, 1.4), WHITE), Vector3.RIGHT)
	interior.add_occluder(_box(Vector3(0.08, 1.6, 1.6), Vector3(-0.96, 1.65, 1.4), WHITE), Vector3.LEFT)
	interior.add_occluder(_box(Vector3(2.0, 0.08, 1.75), Vector3(0, 2.46, 1.45), WHITE))
	# Caja de carga
	interior.add_occluder(_box(Vector3(0.08, 1.8, 3.3), Vector3(0.96, 1.75, -0.95), WHITE), Vector3.RIGHT)
	interior.add_occluder(_box(Vector3(0.08, 1.8, 3.3), Vector3(-0.96, 1.75, -0.95), WHITE), Vector3.LEFT)
	interior.add_occluder(_box(Vector3(2.0, 1.8, 0.08), Vector3(0, 1.75, -2.56), WHITE), Vector3.FORWARD)  # FORWARD = -Z = atrás de la van
	interior.add_occluder(_box(Vector3(2.0, 0.08, 3.4), Vector3(0, 2.66, -0.95), WHITE))
	# Franja de la empresa
	interior.add_occluder(_box(Vector3(0.02, 0.25, 3.2), Vector3(1.01, 1.9, -0.95), Color(0.95, 0.55, 0.1)), Vector3.RIGHT)
	interior.add_occluder(_box(Vector3(0.02, 0.25, 3.2), Vector3(-1.01, 1.9, -0.95), Color(0.95, 0.55, 0.1)), Vector3.LEFT)

	# Asientos
	driver_seat = _marker(Vector3(0.48, 1.0, 1.25))
	passenger_seat = _marker(Vector3(-0.48, 1.0, 1.25))
	for seat in [driver_seat, passenger_seat]:
		_box(Vector3(0.7, 0.25, 0.6), seat.position + Vector3(0, 0, 0), Color(0.25, 0.3, 0.4))
		_box(Vector3(0.7, 0.8, 0.15), seat.position + Vector3(0, 0.45, -0.3), Color(0.25, 0.3, 0.4))
	_cargo_visual = Node3D.new()
	_cargo_visual.name = "Carga"
	add_child(_cargo_visual)

	mirror_anchor = _marker(Vector3(0, 2.2, -2.9))
	mirror_anchor.rotation_degrees = Vector3(-8, 0, 0)  # la cámara mira hacia -Z = hacia atrás

func _build_wheels() -> void:
	var positions := {
		"FL": Vector3(0.9, 0.55, 1.7), "FR": Vector3(-0.9, 0.55, 1.7),
		"RL": Vector3(0.9, 0.55, -1.6), "RR": Vector3(-0.9, 0.55, -1.6),
	}
	for key in positions:
		var w := VehicleWheel3D.new()
		w.name = "Wheel" + key
		w.position = positions[key]
		var front: bool = key.begins_with("F")
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = wheel_radius
		w.wheel_rest_length = 0.25
		w.suspension_travel = 0.2
		w.suspension_stiffness = 45.0
		w.suspension_max_force = 30000.0
		w.damping_compression = 1.8
		w.damping_relaxation = 2.2
		w.wheel_friction_slip = front_grip if front else rear_grip
		w.wheel_roll_influence = 0.3
		add_child(w)
		var tire := LowPoly.cylinder(wheel_radius, 0.3, Color(0.1, 0.1, 0.1), 10)
		tire.rotation_degrees = Vector3(0, 0, 90)
		w.add_child(tire)
		var hub := LowPoly.cylinder(wheel_radius * 0.5, 0.32, Color(0.6, 0.6, 0.62), 6)
		hub.rotation_degrees = Vector3(0, 0, 90)
		w.add_child(hub)
		(_front_wheels if front else _rear_wheels).append(w)

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = _mat(color)
	add_child(m)
	return m

func _marker(pos: Vector3) -> Marker3D:
	var mk := Marker3D.new()
	mk.position = pos
	add_child(mk)
	return mk

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
