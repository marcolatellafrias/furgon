class_name DragLayer
extends Overlay
## Capa de arriba de todo donde se dibuja lo que una mano tiene agarrado,
## así se ve encima de overlays y ventanas. Verde = se puede soltar ahí, rojo = no.
## No recibe input. Comparte cámara y vista oblicua con los overlays.

var _visuals := {}   # Hand -> Node3D
var _style := {}     # Hand -> "view:upm"

static var _ok_mat: StandardMaterial3D
static var _bad_mat: StandardMaterial3D

func _ready() -> void:
	layer = 50
	super._ready()
	if _ok_mat == null:
		_ok_mat = _tint_mat(Color(0.3, 1.0, 0.4, 0.35))
		_bad_mat = _tint_mat(Color(1.0, 0.2, 0.2, 0.45))

static func _tint_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m

func show_item(hand: Hand, item: ItemData, upm := 6.0, view := "side") -> void:
	var key := "%s:%s:%s" % [item.get_instance_id(), view, upm]
	if _style.get(hand) == key:
		return
	hide_item(hand)
	var v := item.make_visual(upm, view)
	root3d.add_child(v)
	_visuals[hand] = v
	_style[hand] = key

func hide_item(hand: Hand) -> void:
	if _visuals.has(hand):
		(_visuals[hand] as Node3D).queue_free()
		_visuals.erase(hand)
		_style.erase(hand)

## Misma posición/giro local que el ítem en su overlay (misma cámara → mismo lugar en pantalla).
func place_local(hand: Hand, pos: Vector3, rot_z: float) -> void:
	if _visuals.has(hand):
		var v := _visuals[hand] as Node3D
		v.position = pos
		v.rotation.z = rot_z

func move_item(hand: Hand, screen: Vector2) -> void:
	if _visuals.has(hand):
		var p := screen_to_plane(screen)
		(_visuals[hand] as Node3D).position = Vector3(p.x, p.y, 0)

func set_tint(hand: Hand, ok: bool) -> void:
	if _visuals.has(hand):
		_apply_overlay(_visuals[hand], _ok_mat if ok else _bad_mat)

func _apply_overlay(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = m
	for c in n.get_children():
		_apply_overlay(c, m)
