@tool
class_name LevelEnclosureValidator
extends RefCounted


static func validate(root: LevelAssembly) -> PackedStringArray:
	var errors := PackedStringArray()
	var volumes: Array[AABB] = []
	var labels: Array[String] = []
	var connected := {}
	var portal_planes := {}
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
		portal_planes[str(item.id)] = []
		for s in item.module.sockets:
			var key := str(item.id) + "/" + str(s.id)
			var cap := (
				node.get_node_or_null("Structure/PortalClosures/" + str(s.id)) as StaticBody3D
			)
			var visual := node.get_node_or_null("Visuals/Closures/" + str(s.id)) as Node3D
			var open: bool = connected.has(key)
			if open:
				portal_planes[str(item.id)].append(
					[node.global_transform * s.local_transform, s.width, s.height]
				)
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
		for patch in item.module.boundary_patches:
			if patch.socket != &"" and connected.has(str(item.id) + "/" + str(patch.socket)):
				continue
			var failed := false
			var count_u := ceili(patch.span_u.length() / .25)
			var count_v := ceili(patch.span_v.length() / .25)
			for u in range(count_u):
				for v in range(count_v):
					if failed:
						continue
					var local := (
						patch.origin
						+ patch.span_u * ((u + .5) / count_u)
						+ patch.span_v * ((v + .5) / count_v)
					)
					var point := node.global_transform * local
					var normal := node.global_basis * patch.normal
					var hit := root.get_world_3d().direct_space_state.intersect_ray(
						PhysicsRayQueryParameters3D.create(
							point - normal * .4, point + normal * .4, 129
						)
					)
					if hit.is_empty():
						errors.append(
							"Exposed module boundary %s patch %s at %s" % [item.id, patch.id, point]
						)
						failed = true
		for id: Variant in item.module.equipment_anchors:
			var anchor := node.get_node_or_null("Attachments/Interactions/" + str(id)) as Node3D
			if (
				anchor == null
				or not anchor.transform.is_equal_approx(item.module.equipment_anchors[id])
			):
				errors.append("Equipment anchor scene mismatch: %s/%s" % [item.id, id])
		for id: Variant in item.module.equipment_clearances:
			var box: AABB = item.module.equipment_clearances[id]
			var shape := BoxShape3D.new()
			shape.size = (box.size - Vector3.ONE * .04).max(Vector3.ONE * .001)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = node.global_transform * Transform3D(Basis.IDENTITY, box.get_center())
			query.collision_mask = 129
			for hit: Dictionary in root.get_world_3d().direct_space_state.intersect_shape(
				query, 128
			):
				var body := hit.collider as Node
				# Equipment may occupy its reserved slot; only structural obstructions fail.
				for instance in root.layout.instances:
					var structure := root.get_node_or_null(str(instance.id) + "/Structure")
					if structure != null and structure.is_ancestor_of(body):
						errors.append("Blocked equipment clearance: %s/%s" % [item.id, id])
						break
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
						if inside or on_open_portal(p, normal, portal_planes[labels[index]]):
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


static func on_open_portal(point: Vector3, normal: Vector3, planes: Array) -> bool:
	for plane: Array in planes:
		var pose: Transform3D = plane[0]
		var local := pose.affine_inverse() * point
		if (
			absf(local.z) < .001
			and absf(local.x) < float(plane[1]) / 2 + .001
			and local.y >= -.001
			and local.y <= float(plane[2]) + .001
			and absf(normal.dot(pose.basis.z)) > .999
		):
			return true
	return false
