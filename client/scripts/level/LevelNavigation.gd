@tool
class_name LevelNavigation
extends RefCounted


static func profile() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.6
	mesh.agent_height = 1.9
	mesh.agent_max_climb = 0.2
	mesh.agent_max_slope = 42
	mesh.cell_size = 0.15
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	return mesh


static func bake(root: Node3D) -> NavigationMesh:
	var mesh := profile()
	var doors: Dictionary = {}
	for door in root.get_tree().get_nodes_in_group("modular_door"):
		if root.is_ancestor_of(door) and not (door.is_security and door.locked):
			doors[door] = door.collision_layer
			door.collision_layer = 0
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, root)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	for door: StaticBody3D in doors:
		door.collision_layer = doors[door]
	return mesh


static func validate_regions(root: LevelAssembly) -> PackedStringArray:
	var errors := PackedStringArray()
	var start := root.marker(root.layout.entry_instance, root.layout.entry_marker)
	var locked := PackedStringArray()
	for i in range(root.layout.connections.size()):
		var door := root.get_node_or_null("Door_%03d" % i) as ModularDoor
		if door != null and door.is_security and door.locked:
			locked.append(str(door.security_id))
	for item in root.layout.instances:
		var goal := root.marker(item.id, &"entry")
		var path := root.local_path(start, goal)
		if path.is_empty() or path[-1].distance_to(goal) > .5:
			errors.append(
				(
					"Blocked navigation region: %s (locked connections: %s)"
					% [item.id, ", ".join(locked)]
				)
			)
	return errors
