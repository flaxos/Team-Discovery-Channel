extends SceneTree
const Model = preload("res://addons/modular_editor/model.gd")
const Canvas = preload("res://addons/modular_editor/canvas.gd")
var model := Model.new()
var undo := UndoRedo.new()
var canvas: Control
var edits := 0


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
	edits += 1


func click(position: Vector2, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	canvas._gui_input(event)


func run() -> void:
	canvas = Canvas.new()
	canvas.model = model
	root.add_child(canvas)
	canvas.edit_requested.connect(edit)
	var fixture := load("res://resources/levels/modular_smoke.tres") as LevelLayout
	# Place all eight rooms via exactly the canvas mouse-event handler.
	canvas.placing = true
	for item in fixture.instances:
		canvas.palette = item.module
		canvas.turn = item.quarter_turn
		click(canvas.screen(item.position))
	assert(model.layout.instances.size() == 8 and edits == 8)
	var original := Model.copy(model.layout)
	click(canvas.screen(fixture.instances[0].position))
	assert(
		model.layout.instances.size() == 8 and not model.errors.is_empty(),
		"Overlap must reject without mutation"
	)
	undo.undo()
	assert(model.layout.instances.size() == 7)
	undo.redo()
	assert(model.layout.instances.size() == 8)
	# Reposition and rotate an unconnected instance through canvas controls, then undo.
	canvas.placing = false
	var last := model.layout.instances[-1]
	var old_position := last.position
	var old_turn := last.quarter_turn
	click(canvas.screen(old_position))
	var motion := InputEventMouseMotion.new()
	motion.position = canvas.screen(Vector2(80, 80))
	canvas._gui_input(motion)
	click(canvas.screen(Vector2(80, 80)), false)
	assert(model.layout.instances[-1].position == Vector2(80, 80))
	canvas.rotate_selected()
	assert(model.layout.instances[-1].quarter_turn == (old_turn + 1) % 4)
	undo.undo()
	undo.undo()
	assert(
		(
			model.layout.instances[-1].position == old_position
			and model.layout.instances[-1].quarter_turn == old_turn
		)
	)
	# Fixture order and generated stable IDs permit explicit socket connections.
	var names: Dictionary = {}
	for i in range(8):
		names[fixture.instances[i].id] = model.layout.instances[i].id
	canvas.placing = false
	canvas.connecting = true
	for edge in fixture.connections:
		var a := model.layout.instance(names[edge.from_instance])
		var b := model.layout.instance(names[edge.to_instance])
		click(canvas.screen(canvas.socket_position(a, a.module.socket(edge.from_socket))))
		click(canvas.screen(canvas.socket_position(b, b.module.socket(edge.to_socket))))
	assert(model.layout.connections.size() == 7)
	var connected := Model.copy(model.layout)
	var id := model.layout.instances[0].id
	assert(not model.accepted(model.moved(id, Vector2(80, 80), 0)))
	assert(
		(
			model.layout.instances[0].position == connected.instances[0].position
			and model.layout.connections.size() == 7
		)
	)
	canvas.selected = id
	canvas.rotate_selected()
	assert(model.layout.instances[0].quarter_turn == connected.instances[0].quarter_turn)
	edit(model.removed(id), "Remove room and links")
	assert(model.layout.instances.size() == 7)
	undo.undo()
	assert(model.layout.instances.size() == 8 and model.layout.connections.size() == 7)
	assert(ResourceSaver.save(model.layout, "user://gui_layout.tres") == OK)
	var loaded := (
		ResourceLoader.load("user://gui_layout.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		as LevelLayout
	)
	assert(LevelLayoutValidator.validate(loaded).is_empty())
	var assembly := LevelAssembly.new()
	assembly.layout = loaded
	root.add_child(assembly)
	await assembly.navigation_ready
	var route := assembly.local_path(
		assembly.marker(loaded.entry_instance, loaded.entry_marker),
		assembly.marker(loaded.destination_instance, loaded.destination_marker)
	)
	assert(not route.is_empty())
	# Exercise the actual CLI export, then remove its temporary source resource.
	assert(ResourceSaver.save(model.layout, "user://editor_snapshot.tres") == OK)
	var output: Array = []
	var code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray(
			[
				"--headless",
				"--path",
				ProjectSettings.globalize_path("res://"),
				"--script",
				"res://scripts/level/build_level.gd",
				"--",
				"--layout",
				"user://editor_snapshot.tres",
				"--build",
				"--output",
				"user://editor_export.tscn",
				"--nav-output",
				"user://editor_export.res"
			]
		),
		output,
		true
	)
	assert(code == 0, "Headless export failed: " + str(output))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://editor_snapshot.tres"))
	var exported := (
		ResourceLoader.load("user://editor_export.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
		as PackedScene
	)
	assert(exported != null, "Export must not depend on its removed snapshot")
	var reopened := exported.instantiate() as LevelAssembly
	root.add_child(reopened)
	await reopened.navigation_ready
	assert(reopened.last_errors.is_empty())
	reopened.queue_free()
	await process_frame
	print(
		"PASS eight mouse-placed instances, all archetypes, socket GUI connections, rejection, undo/redo, save/reload and navigation"
	)
	undo.clear_history()
	undo.free()
	await preload("res://tests/support/finish.gd").success(self)
