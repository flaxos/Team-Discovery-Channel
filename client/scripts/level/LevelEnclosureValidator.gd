@tool
class_name LevelEnclosureValidator
extends RefCounted


static func validate(root: LevelAssembly) -> PackedStringArray:
	var errors := PackedStringArray()
	var volumes: Array[AABB] = []
	var labels: Array[String] = []
	var connected := {}
	for connection in root.layout.connections:
		connected[str(connection.from_instance) + "/" + str(connection.from_socket)] = true
		connected[str(connection.to_instance) + "/" + str(connection.to_socket)] = true
	for item in root.layout.instances:
		var node := root.get_node_or_null(str(item.id)) as LevelModule
		if node == null:
			errors.append("Missing built instance: " + str(item.id))
			continue
		if not node.transform.is_equal_approx(
			item.placement(float(root.layout.decks[str(item.deck)]))
		):
			errors.append("Uncaptured placement: " + str(item.id))
		for s in item.module.sockets:
			var key := str(item.id) + "/" + str(s.id)
			var cap := (
				node.get_node_or_null("Structure/PortalClosures/" + str(s.id)) as StaticBody3D
			)
			var visual := node.get_node_or_null("Visuals/Closures/" + str(s.id)) as Node3D
			var open: bool = connected.has(key)
			if (
				cap == null
				or visual == null
				or (cap.collision_layer == 0) != open
				or visual.visible == open
			):
				errors.append("Portal closure disagrees with layout: " + key)
			var marker := node.get_node_or_null("Sockets/" + str(s.id)) as Node3D
			if marker == null or not marker.transform.is_equal_approx(s.local_transform):
				errors.append("Socket scene mismatch: %s/%s" % [item.id, s.id])
		for id: StringName in [root.layout.entry_marker, root.layout.destination_marker]:
			if not node.has_node("Markers/" + str(id)):
				errors.append("Missing marker: %s/%s" % [item.id, id])
		for volume in item.module.interiors:
			volumes.append(node.global_transform * volume)
			labels.append(str(item.id))
	if not errors.is_empty():
		return errors
	for index in range(volumes.size()):
		var box := volumes[index]
		for axis in range(3):
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for sign_value: float in [-1, 1]:
				var failed := false
				for i in range(ceili(box.size[u] / 0.25)):
					for j in range(ceili(box.size[v] / 0.25)):
						if failed:
							continue
						var p := box.get_center()
						p[axis] = box.position[axis] if sign_value < 0 else box.end[axis]
						p[u] = box.position[u] + (i + 0.5) * box.size[u] / ceili(box.size[u] / 0.25)
						p[v] = box.position[v] + (j + 0.5) * box.size[v] / ceili(box.size[v] / 0.25)
						var normal := Vector3.ZERO
						normal[axis] = sign_value
						var inside := false
						for volume in volumes:
							if volume.has_point(p + normal * 0.01):
								inside = true
								break
						if inside:
							continue
						if (
							root
							. get_world_3d()
							. direct_space_state
							. intersect_ray(
								PhysicsRayQueryParameters3D.create(
									p - normal * 0.4, p + normal * 0.4, 129
								)
							)
							. is_empty()
						):
							errors.append(
								(
									"Exposed module boundary %s face %d/%s at %s"
									% [labels[index], axis, sign_value, p]
								)
							)
							failed = true
	return errors
