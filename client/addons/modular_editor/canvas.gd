@tool
extends Control
signal edit_requested(candidate: LevelLayout, title: String)
signal selection_changed
const Model = preload("model.gd")
var model: Model
var selected: StringName
var selected_connection := -1
var palette: LevelModuleDefinition
var placing := false
var connecting := false
var first_socket := PackedStringArray()
var turn := 0
var zoom := 12.0
var pan := Vector2(400, 250)
var mouse := Vector2.ZERO
var drag := false
var panning := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(700, 420)


func world(point: Vector2) -> Vector2:
	return (point - pan) / zoom


func grid(point: Vector2) -> Vector2:
	return world(point).snapped(Vector2(8, 8))


func screen(point: Vector2) -> Vector2:
	return pan + point * zoom


func socket_position(item: LevelModuleInstance, socket: LevelSocketDefinition) -> Vector2:
	var p := (
		item.placement(float(model.layout.decks[str(item.deck)])) * socket.local_transform.origin
	)
	return Vector2(p.x, p.z)


func footprint(item: LevelModuleInstance, at: Vector2) -> Rect2:
	var pose := item.placement(0)
	pose.origin = Vector3(at.x, 0, at.y)
	var bounds := pose * item.module.occupied
	return Rect2(
		Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)
	)


func draw_footprint(rect: Rect2, color: Color, filled: bool = true, width: float = 1) -> void:
	draw_rect(
		Rect2(screen(rect.position), rect.size * zoom), color, filled, -1 if filled else width
	)


func socket_visible(item: LevelModuleInstance, socket: LevelSocketDefinition) -> bool:
	var deck := item.socket_deck(socket.id)
	return deck == model.active_deck or (deck == &"" and item.deck == model.active_deck)


func interactive(item: LevelModuleInstance) -> bool:
	if item.deck == model.active_deck:
		return true
	for socket in item.module.sockets:
		if item.socket_deck(socket.id) == model.active_deck:
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.065, 0.08))
	var a := world(Vector2.ZERO).snapped(Vector2(8, 8))
	var b := world(size)
	for x in range(floori(a.x / 8) - 1, ceili(b.x / 8) + 1):
		draw_line(
			screen(Vector2(x * 8, a.y - 8)),
			screen(Vector2(x * 8, b.y + 8)),
			Color(0.15, 0.19, 0.23)
		)
	for z in range(floori(a.y / 8) - 1, ceili(b.y / 8) + 1):
		draw_line(
			screen(Vector2(a.x - 8, z * 8)),
			screen(Vector2(b.x + 8, z * 8)),
			Color(0.15, 0.19, 0.23)
		)
	if model == null:
		return
	for item in model.layout.instances:
		if not interactive(item):
			draw_footprint(footprint(item, item.position), Color(.2, .24, .28), false)
			continue
		var at := grid(mouse) if drag and item.id == selected else item.position
		var color := Color(0.3, 0.4, 0.5)
		for error: String in model.errors:
			if str(item.id) in error:
				color = Color(0.8, 0.2, 0.2)
		if item.id == selected:
			color = color.lightened(0.25)
		draw_footprint(footprint(item, at), color)
		draw_footprint(
			footprint(item, at),
			Color.WHITE if item.id == selected else Color(0.4, 0.5, 0.6),
			false,
			2
		)
		draw_string(
			ThemeDB.fallback_font,
			screen(at) + Vector2(-35, 4),
			str(item.id) + (" ↑4m" if "vertical" in item.module.tags else ""),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12
		)
		for socket in item.module.sockets:
			if not socket_visible(item, socket):
				continue
			var pos := screen(socket_position(item, socket))
			draw_circle(pos, 5, Color(1, 0.75, 0.25))
			if item.id == selected:
				draw_string(
					ThemeDB.fallback_font,
					pos + Vector2(7, -5),
					str(socket.id),
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					11
				)
			var normal := -(item.placement(0).basis * socket.local_transform.basis.z)
			var direction := Vector2(normal.x, normal.z)
			draw_line(pos, pos + direction.normalized() * 10, Color(1, 0.75, 0.25), 2)
	for index in range(model.layout.connections.size()):
		var edge := model.layout.connections[index]
		var ia := model.layout.instance(edge.from_instance)
		var ib := model.layout.instance(edge.to_instance)
		if ia.socket_deck(edge.from_socket) != model.active_deck:
			continue
		draw_line(
			screen(ia.position),
			screen(ib.position),
			Color.WHITE if index == selected_connection else Color(0.3, 0.9, 0.7),
			3
		)
	for edge in model.layout.connections:
		if (
			edge.state == "door"
			and (
				model.layout.instance(edge.from_instance).socket_deck(edge.from_socket)
				== model.active_deck
			)
		):
			var item := model.layout.instance(edge.from_instance)
			var point := screen(socket_position(item, item.module.socket(edge.from_socket)))
			draw_rect(Rect2(point - Vector2(4, 6), Vector2(8, 12)), Color(0.3, 1, 0.65))
	if placing and palette != null:
		var candidate := model.placed(palette, grid(mouse), turn) as LevelLayout
		var valid := LevelLayoutValidator.validate(candidate, false).is_empty()
		draw_footprint(
			footprint(candidate.instances[-1], grid(mouse)),
			Color(0.2, 1, 0.5, 0.4) if valid else Color(1, 0.15, 0.15, 0.5)
		)

		for socket in palette.sockets:
			var pos := (
				grid(mouse)
				+ Vector2(
					(Basis(Vector3.UP, turn * PI / 2) * socket.local_transform.origin).x,
					(Basis(Vector3.UP, turn * PI / 2) * socket.local_transform.origin).z
				)
			)
			draw_circle(screen(pos), 5, Color(0.7, 1, 0.8))


func rotate_selected() -> void:
	if placing:
		turn = (turn + 1) % 4
		queue_redraw()
		return
	var item := model.layout.instance(selected) as LevelModuleInstance
	if item != null:
		edit_requested.emit(
			model.moved(selected, item.position, (item.quarter_turn + 1) % 4), "Rotate room"
		)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		mouse = event.position
		grab_focus()
		if (
			event.button_index == MOUSE_BUTTON_WHEEL_UP
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			var before := world(mouse)
			zoom = clampf(
				zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.15), 3, 60
			)
			pan = mouse - before * zoom
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and drag:
				drag = false
				var item := model.layout.instance(selected) as LevelModuleInstance
				edit_requested.emit(
					model.moved(selected, grid(mouse), item.quarter_turn), "Move room"
				)
			elif event.pressed:
				if placing and palette != null:
					edit_requested.emit(model.placed(palette, grid(mouse), turn), "Place room")
				elif connecting:
					pick_socket()
				else:
					selected_connection = -1
					for i in range(model.layout.connections.size()):
						var edge := model.layout.connections[i]
						var item := model.layout.instance(edge.from_instance)
						if item.socket_deck(edge.from_socket) != model.active_deck:
							continue
						if (
							(
								screen(socket_position(item, item.module.socket(edge.from_socket)))
								. distance_to(mouse)
							)
							< 10
						):
							selected_connection = i
					selected = &""
					for item in model.layout.instances:
						if (
							interactive(item)
							and footprint(item, item.position).has_point(world(mouse))
						):
							selected = item.id
							drag = true
							break
					if selected_connection >= 0:
						drag = false
					selection_changed.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		mouse = event.position
		if panning:
			pan += event.relative
		tooltip_text = ""
		for item in model.layout.instances:
			for socket in item.module.sockets:
				if not socket_visible(item, socket):
					continue
				if screen(socket_position(item, socket)).distance_to(mouse) < 12:
					tooltip_text = str(item.id) + "/" + str(socket.id)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			rotate_selected()
			accept_event()
		if event.keycode == KEY_ESCAPE:
			drag = false
			first_socket.clear()
			placing = false
			connecting = false
			queue_redraw()


func pick_socket() -> void:
	for item in model.layout.instances:
		for socket in item.module.sockets:
			if not socket_visible(item, socket):
				continue
			if screen(socket_position(item, socket)).distance_to(mouse) > 12:
				continue
			if (
				not first_socket.is_empty()
				and first_socket[0] == str(item.id)
				and first_socket[1] == str(socket.id)
			):
				continue
			if first_socket.is_empty():
				first_socket = PackedStringArray([str(item.id), str(socket.id)])
				return
			var candidate := Model.copy(model.layout)
			var errors := LevelAssembler.snap(
				candidate,
				item.id,
				socket.id,
				StringName(first_socket[0]),
				StringName(first_socket[1])
			)
			first_socket.clear()
			if not errors.is_empty():
				model.errors = errors
				selection_changed.emit()
				return
			candidate.connections[-1].state = "door"
			edit_requested.emit(candidate, "Connect and snap sockets")
			return


func frame_layout() -> void:
	if model.layout.instances.is_empty() or size.x < 80 or size.y < 80:
		return
	var bounds := footprint(model.layout.instances[0], model.layout.instances[0].position)
	for item in model.layout.instances:
		bounds = bounds.merge(footprint(item, item.position))
	zoom = clampf(minf((size.x - 80) / bounds.size.x, (size.y - 80) / bounds.size.y), 3, 60)
	pan = size / 2 - bounds.get_center() * zoom
	queue_redraw()
