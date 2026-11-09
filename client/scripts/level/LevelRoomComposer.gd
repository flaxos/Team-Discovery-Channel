@tool
class_name LevelRoomComposer
extends RefCounted
const PLACEHOLDER = preload("res://scenes/level/RoomPlaceholder.tscn")


static func resolved(item: LevelModuleInstance) -> Array[LevelRoomAttachment]:
	var result: Array[LevelRoomAttachment] = []
	if item.room_preset == null:
		return result
	for attachment in item.room_preset.attachments:
		if attachment == null:
			continue
		var value := attachment.duplicate() as LevelRoomAttachment
		var disabled := false
		for override in item.attachment_overrides:
			if override != null and override.id == value.id:
				value.local_transform = override.local_transform
				disabled = override.disabled
		if not disabled:
			result.append(value)
	return result


static func pose(item: LevelModuleInstance, attachment: LevelRoomAttachment) -> Transform3D:
	var anchor: Transform3D = item.module.equipment_anchors.get(
		str(attachment.anchor), Transform3D.IDENTITY
	)
	return anchor * attachment.local_transform


static func node_path(attachment: LevelRoomAttachment) -> NodePath:
	return NodePath(
		(
			"Attachments/Interactions/" + str(attachment.anchor) + "/" + str(attachment.id)
			if attachment.anchor != &""
			else "Attachments/RoomContent/" + str(attachment.id)
		)
	)


static func warnings(layout: LevelLayout) -> PackedStringArray:
	var result := PackedStringArray()
	for item in layout.instances:
		var ids := {}
		if item.room_preset != null:
			for attachment in item.room_preset.attachments:
				if attachment != null:
					ids[attachment.id] = true
		for override in item.attachment_overrides:
			if override != null and not ids.has(override.id):
				result.append("Inactive attachment override: %s/%s" % [item.id, override.id])
	return result


static func validate(item: LevelModuleInstance) -> PackedStringArray:
	var errors := PackedStringArray()
	var overrides := {}
	for override in item.attachment_overrides:
		if override == null or override.id == &"" or overrides.has(override.id):
			errors.append("Duplicate/empty attachment override: " + str(item.id))
		else:
			overrides[override.id] = override
	if item.room_preset == null:
		return errors
	var preset := item.room_preset
	if preset.id == &"" or not str(item.module.id) in preset.compatible_modules:
		errors.append(
			"Incompatible room preset: %s/%s on %s" % [item.id, preset.id, item.module.id]
		)
	var seen := {}
	for attachment in preset.attachments:
		if attachment == null:
			errors.append("Null preset attachment: " + str(item.id))
			continue
		if (
			attachment.id == &""
			or str(attachment.id).validate_node_name() != str(attachment.id)
			or seen.has(attachment.id)
		):
			errors.append("Duplicate/invalid attachment ID: %s/%s" % [item.id, attachment.id])
		seen[attachment.id] = true
		if (
			overrides.has(attachment.id)
			and overrides[attachment.id].disabled
			and attachment.required
		):
			errors.append("Missing required attachment: %s/%s" % [item.id, attachment.id])
	for attachment in resolved(item):
		var label := "%s/%s" % [item.id, attachment.id]
		var local := attachment.local_transform
		var basis := local.basis
		if (
			not local.is_finite()
			or absf(basis.determinant() - 1) > .001
			or not basis.is_equal_approx(basis.orthonormalized())
			or basis.y.distance_to(Vector3.UP) > .001
		):
			errors.append("Unsupported attachment transform: " + label)
			continue
		if (
			attachment.anchor != &""
			and not item.module.equipment_anchors.has(str(attachment.anchor))
		):
			errors.append("Unknown equipment anchor: " + label)
			continue
		if attachment.component == &"rings" and not local.is_equal_approx(Transform3D.IDENTITY):
			errors.append("Rings must retain slot transform: " + label)
		var bounds := attachment.bounds
		var physical := bounds.size != Vector3.ZERO
		if (
			not bounds.position.is_finite()
			or not bounds.size.is_finite()
			or (physical and (bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.z <= 0))
			or not attachment.placeholder_size.is_finite()
			or not attachment.approach.is_finite()
			or (
				attachment.placeholder_size != Vector3.ZERO
				and (
					attachment.placeholder_size.x <= 0
					or attachment.placeholder_size.y <= 0
					or attachment.placeholder_size.z <= 0
				)
			)
			or (
				(attachment.scene != null or attachment.placeholder_size != Vector3.ZERO)
				and not physical
			)
		):
			errors.append("Invalid attachment bounds: " + label)
			continue
		if (
			attachment.placeholder_size != Vector3.ZERO
			and not bounds.grow(.001).encloses(
				AABB(
					Vector3(
						-attachment.placeholder_size.x / 2, 0, -attachment.placeholder_size.z / 2
					),
					attachment.placeholder_size
				)
			)
		):
			errors.append("Placeholder exceeds attachment bounds: " + label)
		var placement := pose(item, attachment)
		var placed := placement * bounds
		if attachment.reachable:
			var approach := placement * attachment.approach
			var standing := AABB(approach + Vector3(-.6, .02, -.6), Vector3(1.2, 1.86, 1.2))
			if not item.module.occupied.grow(-.2).grow(.001).encloses(standing):
				errors.append("Attachment approach outside module clearance: " + label)
		if (
			not item.module.occupied.grow(.001).encloses(placed)
			if physical
			else not item.module.occupied.grow(.001).has_point(placement.origin)
		):
			errors.append("Attachment outside module: " + label)
		if attachment.anchor != &"" and physical:
			var zone: AABB = item.module.equipment_clearances.get(str(attachment.anchor), AABB())
			if not zone.grow(.05).encloses(placed):
				errors.append("Attachment exceeds equipment clearance: " + label)
		if physical and (attachment.blocks_movement or attachment.placeholder_size != Vector3.ZERO):
			for socket in item.module.sockets:
				var opening := AABB(
					Vector3(-socket.width / 2, 0, 0),
					Vector3(socket.width, minf(1.9, socket.height), 2)
				)
				var overlap := opening.intersection(
					socket.local_transform.affine_inverse() * placed
				)
				if overlap.size.x > .001 and overlap.size.y > .001 and overlap.size.z > .001:
					errors.append("Attachment blocks doorway: %s (%s)" % [label, socket.id])
	var attachments := resolved(item)
	for i in range(attachments.size()):
		if attachments[i].bounds.size == Vector3.ZERO:
			continue
		var a := pose(item, attachments[i]) * attachments[i].bounds
		for j in range(i + 1, attachments.size()):
			if attachments[j].bounds.size == Vector3.ZERO:
				continue
			var overlap := a.intersection(pose(item, attachments[j]) * attachments[j].bounds)
			if overlap.size.x > .001 and overlap.size.y > .001 and overlap.size.z > .001:
				errors.append(
					(
						"Overlapping attachments: %s/%s / %s"
						% [item.id, attachments[i].id, attachments[j].id]
					)
				)
	return errors


static func populate(layout: LevelLayout, root: Node3D) -> PackedStringArray:
	var errors := PackedStringArray()
	for item in layout.instances:
		var module := root.get_node(str(item.id)) as LevelModule
		var expected := {}
		for attachment in resolved(item):
			expected[str(node_path(attachment))] = true
		for node: Node in module.find_children("*", "Node3D", true, false):
			if node.has_meta("room_attachment") and not expected.has(str(module.get_path_to(node))):
				errors.append(
					"Stale room content; rebuild from layout: %s/%s" % [item.id, node.name]
				)
		if not errors.is_empty():
			continue
		for attachment in resolved(item):
			var parent := (
				(
					module.get_node("Attachments/Interactions/" + str(attachment.anchor)) as Node3D
					if attachment.anchor != &""
					else module.get_node_or_null("Attachments/RoomContent")
				)
				as Node3D
			)
			if parent == null and attachment.anchor == &"":
				parent = Node3D.new()
				parent.name = "RoomContent"
				module.get_node("Attachments").add_child(parent)
				parent.owner = root
			if parent == null:
				errors.append("Missing attachment parent: %s/%s" % [item.id, attachment.id])
				continue
			var node := parent.get_node_or_null(str(attachment.id)) as Node3D
			if node == null:
				if attachment.scene != null:
					var built := attachment.scene.instantiate()
					node = built as Node3D
					if node == null:
						built.free()
				elif attachment.placeholder_size != Vector3.ZERO:
					node = PLACEHOLDER.instantiate() as LevelPlaceholderProp
					(node as LevelPlaceholderProp).size = attachment.placeholder_size
				else:
					node = Marker3D.new()
				if node == null:
					errors.append(
						"Attachment scene must be Node3D: %s/%s" % [item.id, attachment.id]
					)
					continue
				node.name = str(attachment.id)
				node.transform = attachment.local_transform
				node.set_meta("room_attachment", true)
				node.set_meta("attachment_bounds", attachment.bounds)
				node.set_meta("placeholder_size", attachment.placeholder_size)
				node.set_meta("blocks_movement", attachment.blocks_movement)
				node.set_meta("component", attachment.component)
				node.set_meta("references", attachment.references)
				if node is TransportRings:
					node.spawn_enemies_on_beam = false
				parent.add_child(node)
				node.owner = root
				if attachment.blocks_movement and attachment.scene != null:
					var body := StaticBody3D.new()
					body.name = "RoomCollision"
					var collision := CollisionShape3D.new()
					var shape := BoxShape3D.new()
					shape.size = attachment.bounds.size
					collision.shape = shape
					collision.position = attachment.bounds.get_center()
					node.add_child(body)
					body.owner = root
					body.add_child(collision)
					collision.owner = root
			elif (
				not node.has_meta("room_attachment")
				or not node.transform.is_equal_approx(attachment.local_transform)
				or node.get_meta("attachment_bounds", AABB()) != attachment.bounds
				or node.get_meta("placeholder_size", Vector3.ZERO) != attachment.placeholder_size
				or node.get_meta("component", &"") != attachment.component
				or node.get_meta("blocks_movement", false) != attachment.blocks_movement
				or (
					attachment.scene != null
					and not attachment.scene.resource_path.is_empty()
					and node.scene_file_path != attachment.scene.resource_path
				)
			):
				errors.append("Uncaptured attachment transform: %s/%s" % [item.id, attachment.id])
		var gate: StargateRing
		var dhd: DHDDialer
		for attachment in resolved(item):
			var node := module.get_node_or_null(node_path(attachment))
			if attachment.component == &"gate":
				gate = node as StargateRing
			if attachment.component == &"dhd":
				dhd = node as DHDDialer
			if (
				attachment.component == &"rings" and not node is TransportRings
				or attachment.component == &"gate" and not node is StargateRing
				or attachment.component == &"dhd" and not node is DHDDialer
			):
				errors.append(
					(
						"Missing required component: %s/%s (%s)"
						% [item.id, attachment.id, attachment.component]
					)
				)
		if gate != null and dhd != null:
			dhd.stargate_path = dhd.get_path_to(gate)
			dhd.target_stargate = gate
		apply_theme(item, module)
	if not errors.is_empty():
		return errors
	var has_pairs := false
	for item in layout.instances:
		for endpoint in item.transport_endpoints:
			if endpoint.kind == "rings" and endpoint.target_id != &"":
				has_pairs = true
	if has_pairs:
		errors.append_array(LevelTransportBindings.bind_rings(layout, root))
	return errors


static func apply_theme(item: LevelModuleInstance, module: LevelModule) -> void:
	if item.theme == null:
		return
	if item.theme.surface_material != null:
		for node: Node in module.get_node("Visuals").find_children(
			"*", "MeshInstance3D", true, false
		):
			(node as MeshInstance3D).material_override = item.theme.surface_material
	if item.theme.prop_material != null:
		for attachment in resolved(item):
			var prop := module.get_node_or_null(node_path(attachment)) as LevelPlaceholderProp
			if prop != null:
				(prop.get_node("Visuals/Mesh") as MeshInstance3D).material_override = (
					item.theme.prop_material
				)


static func validate_world(root: LevelAssembly) -> PackedStringArray:
	var errors := PackedStringArray()
	for item in root.layout.instances:
		var module := root.get_node(str(item.id)) as LevelModule
		for attachment in resolved(item):
			var node := module.get_node_or_null(node_path(attachment)) as Node3D
			var label := "%s/%s" % [item.id, attachment.id]
			if node == null:
				errors.append("Missing built attachment: " + label)
				continue
			if node is LevelPlaceholderProp or attachment.blocks_movement:
				var body_path := (
					"Structure/Body" if node is LevelPlaceholderProp else "RoomCollision"
				)
				var body := node.get_node_or_null(body_path) as StaticBody3D
				var collision := (
					body.get_child(0) as CollisionShape3D
					if body != null and body.get_child_count() > 0
					else null
				)
				var shape := collision.shape as BoxShape3D if collision != null else null
				var expected := (
					attachment.placeholder_size
					if node is LevelPlaceholderProp
					else attachment.bounds.size
				)
				if (
					body == null
					or body.collision_layer != 1
					or shape == null
					or not shape.size.is_equal_approx(expected)
					or collision.disabled
					or not body.basis.is_equal_approx(Basis.IDENTITY)
					or not collision.basis.is_equal_approx(Basis.IDENTITY)
				):
					errors.append("Attachment collision mismatch: " + label)
			if attachment.bounds.size != Vector3.ZERO:
				var shape := BoxShape3D.new()
				shape.size = (attachment.bounds.size - Vector3.ONE * .04).max(Vector3.ONE * .001)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.transform = (
					node.global_transform
					* Transform3D(Basis.IDENTITY, attachment.bounds.get_center())
				)
				query.collision_mask = 129
				for hit: Dictionary in root.get_world_3d().direct_space_state.intersect_shape(
					query, 128
				):
					if hit.collider != node and not node.is_ancestor_of(hit.collider):
						errors.append("Attachment collision clearance blocked: " + label)
						break
			if attachment.reachable:
				var goal := node.global_transform * attachment.approach
				var capsule := CapsuleShape3D.new()
				capsule.radius = .58
				capsule.height = 1.86
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, goal + Vector3(0, .96, 0))
				query.collision_mask = 129
				if not root.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
					errors.append("Attachment approach blocked: " + label)
				var path := root.local_path(
					root.marker(root.layout.entry_instance, root.layout.entry_marker), goal
				)
				if path.is_empty() or path[-1].distance_to(goal) > .45:
					errors.append("Unreachable attachment marker: " + label)
	return errors
