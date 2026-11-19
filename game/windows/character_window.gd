class_name CharacterWindow
extends GameWindow
## Ventana de un personaje: retrato 3D, hambre y la mano (un solo ítem).
## Soltar comida en la ventana = comer. Soltar algo en "Mano" = agarrarlo.
## Arrastrar lo que hay en "Mano" = sacarlo.

var character: Character
var hunger_bar: ProgressBar
var hand_slot: PanelContainer
var _hand_view: View3D
var _hand_label: Label
var _shown_item: ItemData = null

func _init(p_character: Character) -> void:
	character = p_character
	super._init("char:%d" % p_character.get_instance_id(), p_character.display_name)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)

	var portrait := View3D.new(Vector2i(130, 130), 0.75)
	var head := Character.make_head(character.color)
	head.position.y = -0.05
	portrait.set_content(head)
	portrait.spin = 0.6
	row.add_child(portrait)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var hl := Label.new()
	hl.text = "Hambre"
	col.add_child(hl)
	hunger_bar = ProgressBar.new()
	hunger_bar.custom_minimum_size = Vector2(130, 18)
	hunger_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.55, 0.1)
	fill.set_corner_radius_all(4)
	hunger_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(hunger_bar)

	_hand_label = Label.new()
	_hand_label.text = "Mano"
	col.add_child(_hand_label)
	hand_slot = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1)
	sb.border_color = Color(0.4, 0.4, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	hand_slot.add_theme_stylebox_override("panel", sb)
	hand_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_slot.gui_input.connect(_on_slot_input)
	col.add_child(hand_slot)
	_hand_view = View3D.new(Vector2i(130, 80), 1.6)
	hand_slot.add_child(_hand_view)

	character.stats_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	hunger_bar.value = character.hunger
	if character.held_item != _shown_item:
		_shown_item = character.held_item
		var fit := 1.1 / maxf(_shown_item.dims.x, _shown_item.dims.y) if _shown_item else 1.0
		_hand_view.set_content(_shown_item.make_visual(fit, "side") if _shown_item else null)
		_hand_label.text = "Mano: " + (_shown_item.display_name if _shown_item else "vacía")

func _on_slot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if character.held_item:
			var item := character.held_item
			character.held_item = null
			Desktop.instance.begin_carry(item, func(it: ItemData) -> void: character.held_item = it)
			accept_event()

func _over_slot(screen: Vector2) -> bool:
	return hand_slot.get_global_rect().has_point(screen)

func can_accept(item: ItemData, screen: Vector2) -> bool:
	if _over_slot(screen):
		return character.held_item == null
	return item.is_food()

func accept_drop(item: ItemData, screen: Vector2) -> bool:
	if _over_slot(screen):
		character.held_item = item
	else:
		character.eat(item)
	return true
