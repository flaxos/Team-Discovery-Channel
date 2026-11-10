extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")
const Canvas = preload("res://addons/modular_editor/canvas.gd")
const Toolbar = preload("res://addons/modular_editor/toolbar.gd")
var model := Model.new()
var canvas: Control
var toolbar: Control
var undo := UndoRedo.new()


func _init() -> void:
	call_deferred("run")


func edit(candidate: LevelLayout, title: String) -> void:
	if not model.accepted(candidate):
		return
	var before := Model.copy(model.layout)
	undo.create_action(title)
	undo.add_do_method(model.restore.bind(candidate))
	undo.add_undo_method(model.restore.bind(before))
	undo.commit_action()


func key(code: Key, down: bool = true, physical: bool = false) -> void:
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = code
	else:
		event.keycode = code
		event.unicode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func click(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = Vector2(200,200)
	canvas._gui_input(event)


func run() -> void:
	var panel := VBoxContainer.new()
	panel.size = Vector2(1400,1000)
	toolbar = Toolbar.new()
	panel.add_child(toolbar)
	toolbar.build()
	toolbar.shortcut_scope = panel
	canvas = Canvas.new()
	canvas.model = model
	panel.add_child(canvas)
	root.add_child(panel)
	canvas.edit_requested.connect(edit)
	toolbar.tool_action.connect(func(title: String) -> void:
		if title == "Rotate (R)": canvas.rotate_selected()
	)
	toolbar.prefab_selected.connect(func(asset: String) -> void:
		canvas.palette = load("res://resources/level_modules/" + asset + ".tres")
		canvas.placing = true
	)
	await process_frame
	assert(toolbar.get_child(0).name == "MapActions")
	assert(toolbar.get_child(1).name == "NavigationActions")
	assert(toolbar.get_child(2).name == "PrefabRow1" and toolbar.get_child(3).name == "PrefabRow2")
	var areas: Array[float] = []
	var ids := {}
	for row_index: int in [2,3]:
		for button: Button in toolbar.get_child(row_index).get_child(0).get_children():
			areas.append(float(button.get_meta("footprint_area")))
			ids[button.get_meta("module_id")] = true
			button.grab_focus()
			button.pressed.emit()
			var turn: int = canvas.turn
			key(KEY_R)
			key(KEY_R, false)
			assert(canvas.turn == (turn + 1) % 4, "R must work after choosing every prefab: " + button.text)
			key(KEY_R, true, true)
			key(KEY_R, false, true)
			assert(canvas.turn == (turn + 2) % 4, "Physical R key events must work too")
	var sorted := areas.duplicate()
	sorted.sort()
	assert(areas == sorted and ids.size() == LevelCatalogue.module_definitions().size())
	# Text input retains R, WASD and arrows rather than editing the map.
	toolbar.path.grab_focus()
	var before_turn: int = canvas.turn
	var before_pan: Vector2 = canvas.pan
	key(KEY_R)
	key(KEY_R, false)
	key(KEY_D)
	key(KEY_D, false)
	assert(canvas.turn == before_turn and canvas.pan == before_pan)
	assert(toolbar.path.text.contains("R"))
	# A focused canvas receives real viewport-delivered R events for every selected archetype.
	canvas.placing = false
	for module in LevelCatalogue.module_definitions():
		model.restore(LevelLayout.new())
		edit(model.placed(module, Vector2.ZERO, 0), "Place")
		canvas.selected = model.layout.instances[0].id
		canvas.grab_focus()
		key(KEY_R)
		key(KEY_R, false)
		assert(model.layout.instances[0].quarter_turn == 1, "Selected prefab rotation: " + str(module.id))
		undo.undo()
		assert(model.layout.instances[0].quarter_turn == 0)
		undo.redo()
		assert(model.layout.instances[0].quarter_turn == 1)
		undo.clear_history()
	# Continuous keyboard movement is frame-time based and release/focus loss cannot leave it stuck.
	for pair: Array in [[KEY_W,Vector2(0,1)], [KEY_UP,Vector2(0,1)], [KEY_S,Vector2(0,-1)], [KEY_DOWN,Vector2(0,-1)], [KEY_A,Vector2(1,0)], [KEY_LEFT,Vector2(1,0)], [KEY_D,Vector2(-1,0)], [KEY_RIGHT,Vector2(-1,0)]]:
		canvas.grab_focus()
		before_pan = canvas.pan
		key(pair[0])
		canvas._process(.1)
		key(pair[0], false)
		assert(canvas.pan.is_equal_approx(before_pan + pair[1] * 50), "Keyboard pan direction")
		before_pan = canvas.pan
		canvas._process(.1)
		assert(canvas.pan == before_pan, "Key release stops movement")
	key(KEY_W)
	toolbar.path.grab_focus()
	assert(canvas.pan_keys.is_empty(), "Focus loss clears held keys")
	# Right and middle drag pan without placing/deleting rooms or changing placement rotation.
	canvas.placing = true
	before_turn = canvas.turn
	var count := model.layout.instances.size()
	for button: MouseButton in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
		click(button,true)
		before_pan = canvas.pan
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(220,230)
		motion.relative = Vector2(20,30)
		canvas._gui_input(motion)
		assert(canvas.pan == before_pan + motion.relative)
		click(button,false)
		before_pan = canvas.pan
		canvas._gui_input(motion)
		assert(canvas.pan == before_pan and not canvas.panning)
	assert(canvas.turn == before_turn and model.layout.instances.size() == count)
	# Illegal linked rotations remain transactional and report how to correct the edit.
	model.restore(load("res://resources/levels/modular_integration_demo.tres"))
	canvas.placing = false
	canvas.selected = &"cargo"
	var saved := Model.copy(model.layout)
	canvas.grab_focus()
	key(KEY_R)
	key(KEY_R,false)
	assert(model.layout.instance(&"cargo").quarter_turn == saved.instance(&"cargo").quarter_turn)
	assert(model.layout.connections.size() == saved.connections.size())
	assert(str(model.errors).contains("Rotation blocked"))
	print("PASS toolbar ordering/complete size-sorted palette; real R input for every prefab/selected room; undo/redo; text focus; WASD/arrows and RMB/MMB pan; connection-preserving rotation rejection")
	undo.clear_history()
	undo.free()
	await preload("res://tests/support/finish.gd").success(self)
