@tool
class_name LevelAssembly
extends Node3D
signal navigation_ready
@export var layout: LevelLayout
@export var moving_instance: StringName
@export var moving_socket: StringName
@export var target_instance: StringName
@export var target_socket: StringName
@export var capture_destination: String = ""
@export var discard_uncaptured_edits: bool = false
@export_tool_button("Snap sockets (capture to save)") var snap_action: Callable = snap_selected
@export_tool_button("Capture placed modules") var capture_action: Callable = capture
@export_tool_button("Rebuild from layout") var rebuild_action: Callable = rebuild
@export_tool_button("Validate and bake") var validate_action: Callable = validate_and_bake
var navigation_map: RID
var navigation: NavigationRegion3D
var ready_for_navigation := false
var last_errors := PackedStringArray()


func _ready() -> void:
	if not Engine.is_editor_hint() and layout != null:
		await validate_and_bake()


func report(errors: PackedStringArray) -> void:
	last_errors = errors
	for error in errors:
		push_warning(error)


func rebuild() -> void:
	if get_child_count() > 0 and not discard_uncaptured_edits:
		report(
			PackedStringArray(
				["Capture edits first, or explicitly enable discard_uncaptured_edits"]
			)
		)
		return
	var errors := LevelLayoutValidator.validate(layout, false)
	if not errors.is_empty():
		report(errors)
		return
	for child in get_children():
		remove_child(child)
		child.free()
	navigation = null
	ready_for_navigation = false
	LevelAssembler.assemble(layout, self)
	discard_uncaptured_edits = false


func capture() -> void:
	if capture_destination.is_empty():
		report(PackedStringArray(["Set explicit capture_destination .tres path"]))
		return
	var candidate := layout.duplicate(true) as LevelLayout if layout != null else LevelLayout.new()
	candidate.instances.clear()
	for child in get_children():
		if not child is LevelModule:
			continue
		var node := child as LevelModule
		var previous := layout.instance(node.instance_id) if layout != null else null
		var item := (
			previous.duplicate() as LevelModuleInstance
			if previous != null
			else LevelModuleInstance.new()
		)
		item.id = node.instance_id
		item.module = node.definition
		item.deck = node.deck
		item.position = Vector2(node.position.x, node.position.z)
		item.quarter_turn = posmod(roundi(node.rotation.y / (PI / 2)), 4)
		if (
			not candidate.decks.has(str(item.deck))
			or absf(node.position.y - float(candidate.decks[str(item.deck)])) > 0.001
			or node.scale.distance_to(Vector3.ONE) > 0.001
			or absf(node.rotation.x) > 0.001
			or absf(node.rotation.z) > 0.001
			or absf(angle_difference(node.rotation.y, item.quarter_turn * PI / 2)) > 0.001
		):
			report(PackedStringArray(["Unsupported manual transform: " + str(item.id)]))
			return
		item.available_sockets = node.available_sockets.duplicate()
		candidate.instances.append(item)
	var errors := LevelLayoutValidator.validate(candidate, false)
	if not errors.is_empty():
		report(errors)
		return
	if ResourceSaver.save(candidate, capture_destination) != OK:
		report(PackedStringArray(["Could not save capture"]))
		return
	layout = candidate
	for child in get_children():
		if child is LevelModule:
			child.name = str(child.instance_id)
	report(PackedStringArray())


func snap_selected() -> void:
	# Capture new manual modules first; snapping updates the layout and its scene view.
	var errors := LevelAssembler.snap(
		layout, moving_instance, moving_socket, target_instance, target_socket
	)
	if not errors.is_empty():
		report(errors)
		return
	var node := get_node_or_null(str(moving_instance)) as LevelModule
	if node != null:
		node.transform = layout.instance(moving_instance).placement(
			float(layout.decks[str(node.deck)])
		)
	for c in layout.connections:
		var a := get_node_or_null(str(c.from_instance)) as LevelModule
		var b := get_node_or_null(str(c.to_instance)) as LevelModule
		if a != null:
			a.set_portal(c.from_socket, true)
		if b != null:
			b.set_portal(c.to_socket, true)
	report(errors)


func validate_and_bake() -> void:
	var errors := LevelLayoutValidator.validate(layout)
	if not errors.is_empty():
		report(errors)
		return
	if get_child_count() == 0:
		LevelAssembler.assemble(layout, self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	errors = LevelEnclosureValidator.validate(self)
	if not errors.is_empty():
		report(errors)
		return
	navigation = get_node_or_null("Navigation") as NavigationRegion3D
	if navigation != null:
		navigation.free()
	navigation = NavigationRegion3D.new()
	navigation.name = "Navigation"
	navigation.navigation_mesh = LevelNavigation.bake(self)
	if not navigation_map.is_valid():
		navigation_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(navigation_map, true)
	NavigationServer3D.map_set_cell_size(navigation_map, 0.15)
	navigation.set_navigation_map(navigation_map)
	add_child(navigation)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	while NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame
	ready_for_navigation = true
	report(PackedStringArray())
	navigation_ready.emit()


func local_path(start: Vector3, goal: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(navigation_map, start, goal, true)


func marker(instance_id: StringName, marker_id: StringName) -> Vector3:
	return (get_node(str(instance_id) + "/Markers/" + str(marker_id)) as Node3D).global_position


func _exit_tree() -> void:
	if navigation_map.is_valid():
		NavigationServer3D.free_rid(navigation_map)
