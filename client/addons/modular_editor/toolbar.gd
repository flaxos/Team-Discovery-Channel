@tool
extends VBoxContainer
## Presentation and shortcuts only; layout edits remain in the shared editor model.
signal map_action(title: String)
signal tool_action(title: String)
signal deck_action(title: String)
signal deck_selected(index: int)
signal prefab_selected(asset: String)
var path: LineEdit
var deck_picker: OptionButton
var deck_height: SpinBox
var new_deck: LineEdit
var socket_picker: OptionButton
var shortcut_scope: Control


func button(parent: Control, title: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = title
	node.pressed.connect(callback)
	parent.add_child(node)
	return node


func menu(parent: Control, title: String, choices: Array[String], callback: Callable) -> void:
	var node := MenuButton.new()
	node.text = title
	parent.add_child(node)
	for choice in choices:
		node.get_popup().add_item(choice)
	node.get_popup().id_pressed.connect(func(index: int) -> void: callback.call(choices[index]))


func build() -> void:
	var maps := HFlowContainer.new()
	maps.name = "MapActions"
	add_child(maps)
	for title: String in ["New", "Open", "Save"]:
		button(maps, title, map_action.emit.bind(title))
	path = LineEdit.new()
	path.text = "res://resources/levels/automatic_doors_demo.tres"
	path.custom_minimum_size.x = 300
	path.tooltip_text = "Native LevelLayout resource to open or save"
	maps.add_child(path)
	for title: String in ["Validate", "Rebuild", "Preview 3D", "Validate room", "Preview room 3D"]:
		button(maps, title, map_action.emit.bind(title))
	var navigation := HFlowContainer.new()
	navigation.name = "NavigationActions"
	add_child(navigation)
	for title: String in ["Select / Move", "Rotate (R)"]:
		button(navigation, title, tool_action.emit.bind(title))
	button(navigation, "Frame layout", map_action.emit.bind("Frame layout"))
	menu(navigation, "Connections", ["Connect touching rooms", "Connect sockets", "Open passage", "Standard door", "Security door", "Disconnect selected"], tool_action.emit)
	menu(navigation, "Room actions", ["Entry", "Destination", "Remove room + links"], tool_action.emit)
	var label := Label.new()
	label.text = "Deck"
	navigation.add_child(label)
	deck_picker = OptionButton.new()
	navigation.add_child(deck_picker)
	deck_picker.item_selected.connect(deck_selected.emit)
	deck_height = SpinBox.new()
	deck_height.min_value = -10000
	deck_height.max_value = 10000
	deck_height.step = .1
	deck_height.suffix = " m"
	navigation.add_child(deck_height)
	new_deck = LineEdit.new()
	new_deck.placeholder_text = "New deck ID"
	new_deck.custom_minimum_size.x = 110
	navigation.add_child(new_deck)
	menu(navigation, "Deck actions", ["Add deck", "Set elevation", "Move room to deck"], deck_action.emit)
	socket_picker = OptionButton.new()
	socket_picker.tooltip_text = "Selected room's socket to bind"
	navigation.add_child(socket_picker)
	button(navigation, "Bind socket", deck_action.emit.bind("Bind socket"))
	var modules := LevelCatalogue.module_definitions()
	modules.sort_custom(func(a: LevelModuleDefinition, b: LevelModuleDefinition) -> bool:
		var area_a := a.occupied.size.x * a.occupied.size.z
		var area_b := b.occupied.size.x * b.occupied.size.z
		if not is_equal_approx(area_a, area_b):
			return area_a < area_b
		if not is_equal_approx(a.occupied.size.y, b.occupied.size.y):
			return a.occupied.size.y < b.occupied.size.y
		return str(a.id).naturalnocasecmp_to(str(b.id)) < 0
	)
	var split := ceili(modules.size() / 2.0)
	for row_index in range(2):
		var scroll := ScrollContainer.new()
		scroll.name = "PrefabRow%d" % (row_index + 1)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size.y = 58
		add_child(scroll)
		var row := HBoxContainer.new()
		scroll.add_child(row)
		for i in range(row_index * split, mini((row_index + 1) * split, modules.size())):
			var module := modules[i]
			var asset := module.resource_path.get_file().get_basename()
			var label_text: String = {"room01":"Straight", "room02":"Corner", "room03":"T-junction", "room04":"Chamber", "room05":"X-junction", "room06":"Wide straight", "room07":"Wide corner", "room08":"Wide junction", "room09":"Width adapter", "room10":"Long chamber", "room11":"Large chamber", "room13":"Special hall", "room14":"Ramp (4m)", "room15":"Transport", "room16":"Hangar"}.get(str(module.id), asset.substr(6))
			var size := module.occupied.size
			var item := button(row, "%s\n%s × %s m" % [label_text, String.num(size.x), String.num(size.z)], prefab_selected.emit.bind(asset))
			item.set_meta("module_id", module.id)
			item.set_meta("footprint_area", size.x * size.z)
			item.tooltip_text = "%s · %s\n%s × %s m; reserved height %s m\n%s" % [module.id, asset, String.num(size.x), String.num(size.z), String.num(size.y), module.visual_brief]


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if code != KEY_R:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var scope := shortcut_scope if shortcut_scope != null else self
	# Keep text fields, dropdowns and keyboard focus navigation native.
	if focus is BaseButton and not focus is OptionButton and scope.is_ancestor_of(focus):
		tool_action.emit("Rotate (R)")
		get_viewport().set_input_as_handled()
