class_name DragLayer
extends Overlay
## Capa de arriba de todo donde se dibuja el ítem que una mano está arrastrando,
## así se ve encima de overlays y ventanas. No recibe input.

var _visuals := {}   # Hand -> Node3D

func _ready() -> void:
	layer = 50
	super._ready()

func show_item(hand: Hand, item: ItemData, scale := 1.1) -> void:
	hide_item(hand)
	var v := item.make_visual()
	v.scale = Vector3.ONE * scale
	root3d.add_child(v)
	_visuals[hand] = v

func hide_item(hand: Hand) -> void:
	if _visuals.has(hand):
		(_visuals[hand] as Node3D).queue_free()
		_visuals.erase(hand)

func place_item(hand: Hand, screen: Vector2, rot_z: float) -> void:
	if _visuals.has(hand):
		var p := screen_to_plane(screen)
		var v := _visuals[hand] as Node3D
		v.position = Vector3(p.x, p.y, 0)
		v.rotation.z = rot_z

func move_item(hand: Hand, screen: Vector2) -> void:
	if _visuals.has(hand):
		var p := screen_to_plane(screen)
		(_visuals[hand] as Node3D).position = Vector3(p.x, p.y, 0)
