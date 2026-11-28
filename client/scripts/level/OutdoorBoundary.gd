class_name OutdoorBoundary
extends Node3D
## Separate exterior terrain host joining a modular LevelAssembly strictly at a declared
## doorway socket (roadmap OW-0, decision D-006).
##
## Lifecycle:
## 1. `_enter_tree()` registers the exterior doorway portal and marker resolver on the sibling
##    `LevelAssembly` before its `_ready()` runs `validate_and_bake()`.
## 2. `LevelAssembly` still runs `LevelEnclosureValidator` on the fully sealed modular interior
##    first, then opens only the declared exterior portal(s) and bakes interior navigation.
## 3. `_ready()` awaits `level.navigation_ready`, bakes an independent `ExteriorNavigation`
##    `NavigationRegion3D` using `LevelNavigation.profile()`, joins it to `level.navigation_map`,
##    connects the doorway threshold with a bidirectional `NavigationLink3D`, and validates
##    round-trip outdoor <-> interior walkability.
##
## Intentionally never references its own `class_name` inside this script (avoids exit leaks).

signal navigation_ready

@export var level_path: NodePath = NodePath("../Level")
@export var doorway_instance: StringName = &"bunker_entry"
@export var doorway_socket: StringName = &"south"
@export var arrival_marker: StringName = &"gate_arrival"
@export var exterior_sector_id: String = "EXTERIOR_GATE_SITE"
@export var exterior_bounds: AABB = AABB(Vector3(-34.0, -4.0, 4.0), Vector3(68.0, 24.0, 44.0))
@export var doorway_mount_door: bool = true
@export var threshold_outward_offset: float = 1.6

var level: LevelAssembly = null
var navigation: NavigationRegion3D = null
var doorway_link: NavigationLink3D = null
var ready_for_navigation: bool = false
var last_errors: PackedStringArray = PackedStringArray()


func _enter_tree() -> void:
	level = get_node_or_null(level_path) as LevelAssembly
	if level != null:
		if doorway_instance != &"" and doorway_socket != &"":
			level.register_exterior_portal(doorway_instance, doorway_socket, doorway_mount_door)
		level.exterior_marker_resolver = Callable(self, &"marker_position")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	await attach_to_level()


func marker_node(marker_id: StringName) -> Node3D:
	return get_node_or_null("Markers/" + str(marker_id)) as Node3D


func has_marker(marker_id: StringName) -> bool:
	return marker_node(marker_id) != null


func marker_position(marker_id: StringName) -> Vector3:
	var node := marker_node(marker_id)
	return node.global_position if node != null else global_position


func exterior_door() -> ModularDoor:
	if level == null:
		return null
	return level.get_node_or_null(
		"ExteriorDoor_%s_%s" % [doorway_instance, doorway_socket]
	) as ModularDoor


func contains_point(world_pos: Vector3) -> bool:
	return exterior_bounds.has_point(to_local(world_pos))


func attach_to_level() -> PackedStringArray:
	ready_for_navigation = false
	var errors := PackedStringArray()
	if level == null:
		level = get_node_or_null(level_path) as LevelAssembly
	if level == null or level.layout == null:
		errors.append("OutdoorBoundary requires a sibling LevelAssembly with a LevelLayout")
		_finish(errors)
		return errors
	if not level.ready_for_navigation:
		if level.last_errors.is_empty():
			await level.navigation_ready
		if not level.ready_for_navigation:
			errors.append("Interior LevelAssembly failed navigation bake")
			errors.append_array(level.last_errors)
			_finish(errors)
			return errors
	if not level.navigation_map.is_valid():
		errors.append("Interior LevelAssembly has no valid navigation_map")
		_finish(errors)
		return errors

	var item := level.layout.instance(doorway_instance)
	if item == null or item.module == null:
		errors.append("Unknown doorway interior instance: %s" % doorway_instance)
		_finish(errors)
		return errors
	var socket := item.module.socket(doorway_socket)
	if socket == null:
		errors.append("Unknown doorway socket: %s/%s" % [doorway_instance, doorway_socket])
		_finish(errors)
		return errors
	for edge in level.layout.connections:
		if (
			(edge.from_instance == doorway_instance and edge.from_socket == doorway_socket)
			or (edge.to_instance == doorway_instance and edge.to_socket == doorway_socket)
		):
			errors.append(
				"Exterior doorway socket is already connected indoors: %s/%s"
				% [doorway_instance, doorway_socket]
			)
			_finish(errors)
			return errors
	var module := level.get_node_or_null(str(doorway_instance)) as LevelModule
	if module == null:
		errors.append("Missing built doorway module node: %s" % doorway_instance)
		_finish(errors)
		return errors
	if doorway_mount_door and exterior_door() == null:
		errors.append("Missing runtime exterior ModularDoor for %s/%s" % [doorway_instance, doorway_socket])
		_finish(errors)
		return errors

	# Rebuild exterior NavigationRegion3D strictly from exterior static colliders.
	var old_nav := get_node_or_null("ExteriorNavigation")
	if old_nav != null:
		old_nav.free()
	var old_link := get_node_or_null("OutdoorDoorwayLink")
	if old_link != null:
		old_link.free()
	await get_tree().physics_frame

	navigation = NavigationRegion3D.new()
	navigation.name = "ExteriorNavigation"
	navigation.navigation_mesh = LevelNavigation.bake(self)
	navigation.set_navigation_map(level.navigation_map)
	var iter_before := NavigationServer3D.map_get_iteration_id(level.navigation_map)
	add_child(navigation)

	await _wait_region_synced(navigation.get_rid(), iter_before)

	var inside_target := module.to_global(socket.approach)
	var socket_world := module.global_transform * socket.local_transform
	var outward := socket_world.origin - inside_target
	outward.y = 0.0
	if outward.length_squared() < 0.0001:
		outward = -socket_world.basis.z
		outward.y = 0.0
	outward = outward.normalized()
	var outside_target := socket_world.origin + outward * threshold_outward_offset

	var inside_snap := NavigationServer3D.map_get_closest_point(level.navigation_map, inside_target)
	var outside_snap := NavigationServer3D.map_get_closest_point(level.navigation_map, outside_target)
	if inside_snap.distance_to(inside_target) > 0.65:
		errors.append("Interior doorway approach off navmesh: %s -> %s" % [inside_target, inside_snap])
	if outside_snap.distance_to(outside_target) > 0.65:
		errors.append("Exterior doorway landing off navmesh: %s -> %s" % [outside_target, outside_snap])

	if errors.is_empty():
		doorway_link = NavigationLink3D.new()
		doorway_link.name = "OutdoorDoorwayLink"
		doorway_link.bidirectional = true
		doorway_link.enter_cost = 0.0
		doorway_link.travel_cost = 1.0
		doorway_link.navigation_layers = 1
		doorway_link.start_position = to_local(outside_snap)
		doorway_link.end_position = to_local(inside_snap)
		doorway_link.set_navigation_map(level.navigation_map)
		add_child(doorway_link)
		var iter_link := NavigationServer3D.map_get_iteration_id(level.navigation_map)
		await _wait_map_iteration(iter_link)
		await get_tree().physics_frame
		errors.append_array(validate_boundary())

	_finish(errors)
	return errors


func validate_boundary() -> PackedStringArray:
	var errors := PackedStringArray()
	if level == null or not level.navigation_map.is_valid():
		errors.append("OutdoorBoundary cannot validate without an active LevelAssembly navigation map")
		return errors
	var markers_root := get_node_or_null("Markers")
	if markers_root == null:
		errors.append("OutdoorBoundary missing Markers container")
		return errors
	var arrival := marker_node(arrival_marker)
	if arrival == null:
		errors.append("OutdoorBoundary missing arrival marker: %s" % arrival_marker)
		return errors

	for child: Node in markers_root.get_children():
		var marker_3d := child as Node3D
		if marker_3d == null:
			continue
		var pos := marker_3d.global_position
		var snapped := NavigationServer3D.map_get_closest_point(level.navigation_map, pos)
		if snapped.distance_to(pos) > 0.55:
			errors.append("Exterior marker off walkable terrain: %s" % marker_3d.name)
		for inst in level.layout.instances:
			var mod := level.get_node_or_null(str(inst.id)) as Node3D
			if mod != null and inst.module != null and inst.module.occupied.has_point(mod.to_local(pos)):
				errors.append(
					"Exterior marker %s overlaps interior module %s" % [marker_3d.name, inst.id]
				)

	var arrival_pos := arrival.global_position
	var interior_entry := level.marker(level.layout.entry_instance, level.layout.entry_marker)
	var interior_dest := level.marker(
		level.layout.destination_instance, level.layout.destination_marker
	)
	var to_entry := level.local_path(arrival_pos, interior_entry)
	if to_entry.is_empty() or to_entry[-1].distance_to(interior_entry) > 0.65:
		errors.append("No outdoor-to-interior path across doorway to %s" % level.layout.entry_instance)
	var to_dest := level.local_path(arrival_pos, interior_dest)
	if to_dest.is_empty() or to_dest[-1].distance_to(interior_dest) > 0.65:
		errors.append(
			"No outdoor-to-interior path across doorway to destination %s"
			% level.layout.destination_instance
		)
	var back_out := level.local_path(interior_dest, arrival_pos)
	if back_out.is_empty() or back_out[-1].distance_to(arrival_pos) > 0.65:
		errors.append("No interior-to-outdoor return path across doorway to %s" % arrival_marker)
	return errors


func validate_mission_markers(required_markers: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	if level == null or not level.navigation_map.is_valid():
		return errors
	for name_str: String in required_markers:
		var marker_3d := marker_node(StringName(name_str))
		if marker_3d == null:
			errors.append("Missing exterior mission marker: " + name_str)
			continue
		var snapped := NavigationServer3D.map_get_closest_point(
			level.navigation_map, marker_3d.global_position
		)
		if snapped.distance_to(marker_3d.global_position) > 0.55:
			errors.append("Exterior mission marker off walkable terrain: " + name_str)
	return errors


func _wait_region_synced(region_rid: RID, iter_before: int) -> void:
	for _i in range(20):
		await get_tree().physics_frame
		if (
			NavigationServer3D.map_get_regions(level.navigation_map).has(region_rid)
			and NavigationServer3D.map_get_iteration_id(level.navigation_map) > iter_before
		):
			break
	await get_tree().physics_frame
	await get_tree().physics_frame


func _wait_map_iteration(previous_iteration: int) -> void:
	for _i in range(20):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(level.navigation_map) > previous_iteration:
			break


func _finish(errors: PackedStringArray) -> void:
	last_errors = errors
	ready_for_navigation = errors.is_empty()
	for err in errors:
		push_warning("OutdoorBoundary: " + err)
	navigation_ready.emit()
