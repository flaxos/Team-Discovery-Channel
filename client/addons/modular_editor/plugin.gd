@tool
extends EditorPlugin
const Model = preload("model.gd")
const Canvas = preload("canvas.gd")
const RoomControls = preload("room_controls.gd")
var room_controls: HFlowContainer
var model := Model.new()
var panel: VBoxContainer
var canvas: Control
var results: RichTextLabel
var path: LineEdit
var dirty := false
var busy := false
var deck_picker: OptionButton
var deck_height: SpinBox
var new_deck: LineEdit
var socket_picker: OptionButton


func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.name = "ModularMap"
	var toolbar := HFlowContainer.new()
	panel.add_child(toolbar)
	path = LineEdit.new()
	path.text = "res://resources/levels/automatic_doors_demo.tres"
	path.custom_minimum_size.x = 330
	toolbar.add_child(path)
	for title: String in [
		"New",
		"Open",
		"Frame layout",
		"Save",
		"Validate",
		"Rebuild",
		"Preview 3D",
		"Validate room",
		"Preview room 3D"
	]:
		var button := Button.new()
		button.text = title
		toolbar.add_child(button)
		button.pressed.connect(action.bind(title))
	var decks := HFlowContainer.new()
	panel.add_child(decks)
	var deck_label := Label.new()
	deck_label.text = "Active deck"
	decks.add_child(deck_label)
	deck_picker = OptionButton.new()
	decks.add_child(deck_picker)
	deck_picker.item_selected.connect(select_deck)
	deck_height = SpinBox.new()
	deck_height.min_value = -10000
	deck_height.max_value = 10000
	deck_height.step = .1
	deck_height.suffix = " m"
	decks.add_child(deck_height)
	new_deck = LineEdit.new()
	new_deck.placeholder_text = "New deck ID"
	new_deck.custom_minimum_size.x = 130
	decks.add_child(new_deck)
	for title: String in ["Add deck", "Set elevation", "Move room to deck"]:
		var button := Button.new()
		button.text = title
		button.pressed.connect(deck_action.bind(title))
		decks.add_child(button)
	socket_picker = OptionButton.new()
	decks.add_child(socket_picker)
	var bind_button := Button.new()
	bind_button.text = "Bind socket to active deck"
	bind_button.pressed.connect(deck_action.bind("Bind socket"))
	decks.add_child(bind_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 38
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var tools := HBoxContainer.new()
	scroll.add_child(tools)
	for name: String in LevelCatalogue.all_modules():
		var button := Button.new()
		button.text = (
			{
				"Room01Straight": "Straight corridor",
				"Room02Corner": "Corner corridor",
				"Room03TJunction": "T-junction",
				"Room04Chamber": "Chamber"
			}
			. get(name, name.substr(6))
		)
		tools.add_child(button)
		button.pressed.connect(choose.bind(name))
	for title: String in [
		"Select / Move",
		"Open passage",
		"Standard door",
		"Security door",
		"Connect touching rooms",
		"Connect sockets",
		"Rotate (R)",
		"Remove room + links",
		"Disconnect selected",
		"Entry",
		"Destination"
	]:
		var button := Button.new()
		button.text = title
		tools.add_child(button)
		button.pressed.connect(tool_action.bind(title))
	canvas = Canvas.new()
	canvas.model = model
	panel.add_child(canvas)
	canvas.edit_requested.connect(commit)
	canvas.selection_changed.connect(refresh)
	model.changed.connect(refresh)
	room_controls = RoomControls.new()
	room_controls.model = model
	room_controls.canvas = canvas
	panel.add_child(room_controls)
	room_controls.edit_requested.connect(commit)
	results = RichTextLabel.new()
	results.custom_minimum_size.y = 85
	panel.add_child(results)
	add_control_to_bottom_panel(panel, "Modular Map")
	refresh()


func _exit_tree() -> void:
	get_undo_redo().clear_history(get_undo_redo().get_object_history_id(panel))
	remove_control_from_bottom_panel(panel)
	panel.queue_free()


func select_deck(index: int) -> void:
	model.active_deck = StringName(deck_picker.get_item_text(index))
	canvas.drag = false
	canvas.first_socket.clear()
	canvas.selected_connection = -1
	refresh()


func deck_action(title: String) -> void:
	if busy:
		return
	if title == "Add deck":
		var id := new_deck.text.strip_edges()
		if id.is_empty() or model.layout.decks.has(id):
			model.errors = PackedStringArray(["Enter a unique, non-empty deck ID."])
			refresh()
			return
		commit(model.deck_changed(id, deck_height.value), title)
	elif title == "Set elevation":
		commit(model.deck_changed(str(model.active_deck), deck_height.value), title)
	elif title == "Move room to deck":
		commit(model.redecked(canvas.selected, model.active_deck), title)
	elif title == "Bind socket" and socket_picker.selected >= 0:
		commit(
			model.socket_bound(
				canvas.selected,
				StringName(socket_picker.get_item_text(socket_picker.selected)),
				model.active_deck
			),
			title
		)


func choose(name: String) -> void:
	canvas.palette = (
		load("res://resources/level_modules/" + name + ".tres") as LevelModuleDefinition
	)
	canvas.placing = true
	canvas.connecting = false
	canvas.queue_redraw()


func tool_action(title: String) -> void:
	if busy:
		return
	if title == "Select / Move":
		canvas.placing = false
		canvas.connecting = false
	elif title in ["Open passage", "Standard door", "Security door"]:
		if (
			canvas.selected_connection < 0
			or canvas.selected_connection >= model.layout.connections.size()
		):
			model.errors = PackedStringArray(
				["Click a linked doorway marker to select its connection first."]
			)
			refresh()
			return
		var candidate := Model.copy(model.layout)
		candidate.connections[canvas.selected_connection].state = (
			"open"
			if title == "Open passage"
			else "security_door" if title == "Security door" else "door"
		)
		candidate.connections[canvas.selected_connection].initially_locked = false
		commit(candidate, title)
	elif title == "Connect touching rooms":
		var candidate := Model.copy(model.layout)
		var errors := LevelAssembler.connect_touching(candidate)
		if not errors.is_empty():
			model.errors = errors
			refresh()
			return
		var changed := candidate.connections.size() != model.layout.connections.size()
		for i in range(mini(candidate.connections.size(), model.layout.connections.size())):
			if candidate.connections[i].state != model.layout.connections[i].state:
				changed = true
		if not changed:
			model.errors = PackedStringArray(
				[
					"No unlinked matching doorways touch. Rotate/move rooms until their amber doorway markers meet and face each other."
				]
			)
			refresh()
			return
		commit(candidate, title)
	elif title == "Connect sockets":
		canvas.placing = false
		canvas.connecting = true
		canvas.first_socket.clear()
	elif title == "Rotate (R)":
		canvas.rotate_selected()
	elif title == "Remove room + links":
		commit(model.removed(canvas.selected), title)
	elif title == "Disconnect selected":
		var candidate := Model.copy(model.layout)
		for i in range(candidate.connections.size() - 1, -1, -1):
			var edge := candidate.connections[i]
			if edge.from_instance == canvas.selected or edge.to_instance == canvas.selected:
				candidate.connections.remove_at(i)
		commit(candidate, title)
	else:
		if model.layout.instance(canvas.selected) == null:
			return
		var candidate := Model.copy(model.layout)
		if title == "Entry":
			candidate.entry_instance = canvas.selected
		else:
			candidate.destination_instance = canvas.selected
		commit(candidate, title)
	refresh()


func commit(candidate: LevelLayout, title: String) -> void:
	if busy:
		return
	if not model.accepted(candidate):
		refresh()
		return
	var before := Model.copy(model.layout)
	var undo := get_undo_redo()
	undo.create_action(title, UndoRedo.MERGE_DISABLE, panel)
	undo.add_do_method(self, "restore", candidate)
	undo.add_undo_method(self, "restore", before)
	undo.commit_action()


func restore(value: LevelLayout) -> void:
	dirty = true
	var key := ""
	if (
		canvas.selected_connection >= 0
		and canvas.selected_connection < model.layout.connections.size()
	):
		key = connection_key(model.layout.connections[canvas.selected_connection])
	canvas.selected_connection = -1
	model.restore(value)
	canvas.first_socket.clear()
	for i in range(model.layout.connections.size()):
		if connection_key(model.layout.connections[i]) == key:
			canvas.selected_connection = i
	refresh()


func connection_key(edge: LevelModuleConnection) -> String:
	return (
		"%s/%s -> %s/%s" % [edge.from_instance, edge.from_socket, edge.to_instance, edge.to_socket]
	)


func refresh() -> void:
	if results == null:
		return
	room_controls.refresh()
	deck_picker.clear()
	for id: String in model.layout.decks:
		deck_picker.add_item(id)
		if id == str(model.active_deck):
			deck_picker.select(deck_picker.item_count - 1)
	deck_height.set_value_no_signal(float(model.layout.decks.get(str(model.active_deck), 0.0)))
	var old_socket := (
		socket_picker.get_item_text(socket_picker.selected) if socket_picker.selected >= 0 else ""
	)
	socket_picker.clear()
	var selected := model.layout.instance(canvas.selected)
	if selected != null:
		for socket in selected.module.sockets:
			socket_picker.add_item(str(socket.id))
			if str(socket.id) == old_socket:
				socket_picker.select(socket_picker.item_count - 1)
	results.text = (
		("Unsaved changes. " if dirty else "Saved. ") + "Selected: " + str(canvas.selected) + "\n"
	)
	if (
		canvas.selected_connection >= 0
		and canvas.selected_connection < model.layout.connections.size()
	):
		var edge := model.layout.connections[canvas.selected_connection]
		results.text += (
			"Connection: %s/%s → %s/%s (%s)\n"
			% [edge.from_instance, edge.from_socket, edge.to_instance, edge.to_socket, edge.state]
		)
	results.text += (
		"\n".join(model.errors)
		if not model.errors.is_empty()
		else "Compatible corridor joins create open passages; room entrances create doors. Click a linked doorway to change its type. [E] opens/closes in 3D. · 8 m grid · MMB pan · wheel zoom · choose palette to place · select/drag to move · R rotate · connect: click source then destination socket (may snap destination)."
	)
	var notices := LevelRoomComposer.warnings(model.layout)
	if not notices.is_empty():
		results.text += "\n" + "\n".join(notices)
	canvas.queue_redraw()


func action(title: String) -> void:
	if title == "Frame layout":
		canvas.frame_layout()
		return
	if busy:
		return
	if title in ["New", "Open"]:
		if dirty:
			model.errors = PackedStringArray(
				["Save changes before New/Open; nothing was discarded."]
			)
			refresh()
			return
		if title == "New":
			commit(LevelLayout.new(), "New layout")
			return
		if not ResourceLoader.exists(path.text):
			model.errors = PackedStringArray(["Layout not found: " + path.text])
			refresh()
			return
		var loaded := (
			ResourceLoader.load(path.text, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as LevelLayout
		)
		if loaded == null:
			model.errors = PackedStringArray(["Not a LevelLayout"])
			refresh()
			return
		if not model.accepted(loaded):
			refresh()
			return
		commit(loaded, "Open layout")
		dirty = false
		refresh()
		canvas.frame_layout.call_deferred()
		return
	if title == "Save":
		if not path.text.begins_with("res://resources/levels/") or not path.text.ends_with(".tres"):
			model.errors = PackedStringArray(["Save under res://resources/levels/ as .tres"])
			refresh()
			return
		if ResourceSaver.save(model.layout, path.text) != OK:
			model.errors = PackedStringArray(["Save failed"])
		else:
			dirty = false
			model.errors.clear()
		refresh()
		return
	var selected_only := title in ["Validate room", "Preview room 3D"]
	var build_layout := (
		model.room_layout(canvas.selected) if selected_only else Model.copy(model.layout)
	)
	if build_layout == null:
		model.errors = PackedStringArray(
			["Select a room using Select / Move, then click Validate room or Preview room 3D."]
		)
		refresh()
		return
	var errors := LevelLayoutValidator.validate(build_layout)
	if not errors.is_empty():
		model.errors = errors
		if "Disconnected instance" in str(errors):
			(
				model
				. errors
				. append(
					"Full-map build requires connected doorways. Click Connect touching rooms to link compatible doorway markers already touching. Markers must coincide and face opposite directions; use R to rotate unconnected rooms. New placements link automatically. Touching solid walls do not create doors. To inspect one room, select it and use Validate room or Preview room 3D."
				)
			)
		refresh()
		return
	busy = true
	var token := str(Time.get_ticks_usec())
	var snapshot := "user://modular_editor_" + token + ".tres"
	var logfile := "user://modular_editor_" + token + ".log"
	if ResourceSaver.save(build_layout, snapshot) != OK:
		model.errors = PackedStringArray(["Could not save build snapshot"])
		busy = false
		refresh()
		return
	var args := PackedStringArray(
		[
			"--headless",
			"--fixed-fps",
			"60",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--log-file",
			ProjectSettings.globalize_path(logfile),
			"--script",
			"res://scripts/level/build_level.gd",
			"--",
			"--layout",
			snapshot,
			"--validate"
		]
	)
	if title not in ["Validate", "Validate room"]:
		args.append_array(
			PackedStringArray(
				[
					"--build",
					"--output",
					"res://scenes/level/EditorPreview.tscn",
					"--nav-output",
					"res://resources/levels/editor_preview_navigation.res"
				]
			)
		)
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid < 0:
		model.errors = PackedStringArray(["Could not start headless builder"])
	else:
		var started := Time.get_ticks_msec()
		while OS.is_process_running(pid) and Time.get_ticks_msec() - started < 60000:
			await get_tree().create_timer(0.1).timeout
		if OS.is_process_running(pid):
			OS.kill(pid)
			model.errors = PackedStringArray(["Build timed out"])
		else:
			var log := (
				FileAccess.get_file_as_string(logfile)
				if FileAccess.file_exists(logfile)
				else "Missing builder log"
			)
			if not "PASS modular build and navigation" in log or "ERROR:" in log:
				model.errors = PackedStringArray([log])
			else:
				model.errors.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(snapshot))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(logfile))
	busy = false
	refresh()
	if model.errors.is_empty():
		results.text = (
			"PASS full layout, enclosure and navigation validation. "
			+ ("Rebuilt EditorPreview.tscn" if title not in ["Validate", "Validate room"] else "")
		)
		if title in ["Preview 3D", "Preview room 3D"]:
			get_editor_interface().get_resource_filesystem().scan()
			get_editor_interface().play_custom_scene("res://addons/modular_editor/preview.tscn")
