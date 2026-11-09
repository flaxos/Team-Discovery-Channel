@tool
class_name LevelLayoutValidator
extends RefCounted


static func validate(layout: LevelLayout, require_route: bool = true) -> PackedStringArray:
	var errors := PackedStringArray()
	if layout == null:
		return PackedStringArray(["Missing layout"])
	if layout.schema_version != 1:
		errors.append("Unsupported layout schema")
	for id: Variant in layout.decks:
		var value: Variant = layout.decks[id]
		if (
			not id is String
			or str(id).is_empty()
			or not (value is float or value is int)
			or not is_finite(float(value))
		):
			errors.append("Invalid deck elevation: " + str(id))
	if not errors.is_empty():
		return errors
	errors.append_array(LevelThemeResolver.validate_layout(layout))
	var seen := {}
	for item in layout.instances:
		if item == null:
			errors.append("Null instance")
			continue
		if item.id == &"" or seen.has(item.id):
			errors.append("Duplicate/empty instance ID: " + str(item.id))
		seen[item.id] = true
		if item.module == null or item.module.scene == null:
			errors.append("Missing module scene: " + str(item.id))
			continue
		if (
			not layout.decks.has(str(item.deck))
			or item.quarter_turn < 0
			or item.quarter_turn > 3
			or not item.position.is_finite()
		):
			errors.append("Invalid placement: " + str(item.id))
		if not layout.decks.has(str(item.deck)):
			continue
		for error in validate_geometry(item):
			errors.append(error)
		var sockets := {}
		for s in item.module.sockets:
			if s == null:
				errors.append("Null socket: " + str(item.id))
				continue
			if s.id == &"" or sockets.has(s.id):
				errors.append("Duplicate/empty socket: %s/%s" % [item.id, s.id])
			sockets[s.id] = true
			var deck_id := item.socket_deck(s.id)
			if deck_id == &"":
				if require_route:
					errors.append("Unbound socket deck: %s/%s" % [item.id, s.id])
			elif (
				not layout.decks.has(str(deck_id))
				or (
					absf(
						(
							float(layout.decks.get(str(deck_id), 0.0))
							- float(layout.decks[str(item.deck)])
							- s.local_transform.origin.y
						)
					)
					> 0.001
				)
			):
				errors.append(
					"Socket deck elevation mismatch: %s/%s (%s)" % [item.id, s.id, deck_id]
				)
			# -Z is the socket's outward normal. Test both sides of the occupied
			# boundary independently of the scene marker, which can share a bad basis.
			var outward := -s.local_transform.basis.z
			var boundary := item.module.occupied.grow(0.001)
			if (
				not s.local_transform.is_finite()
				or not outward.is_normalized()
				or boundary.has_point(s.local_transform.origin + outward * 0.05)
				or not boundary.has_point(s.local_transform.origin - outward * 0.05)
			):
				errors.append(
					"Socket must face outward from occupied boundary: %s/%s" % [item.id, s.id]
				)
			if s.width < 1.2 or s.height < 2.0:
				errors.append("Insufficient clearance: %s/%s" % [item.id, s.id])
		for id: Variant in item.socket_decks:
			if not sockets.has(StringName(id)):
				errors.append("Unknown socket deck binding: %s/%s" % [item.id, id])
		for id: Variant in item.available_sockets:
			if not sockets.has(StringName(id)):
				errors.append("Unknown available socket: %s/%s" % [item.id, id])
	for item in layout.instances:
		if item != null and item.module != null:
			errors.append_array(LevelRoomComposer.validate(item))
	errors.append_array(validate_transports(layout, require_route))
	if not errors.is_empty():
		return errors
	for i in range(layout.instances.size()):
		var a := layout.instances[i]
		var box := a.placement(float(layout.decks[str(a.deck)])) * a.module.occupied
		for j in range(i + 1, layout.instances.size()):
			var b := layout.instances[j]
			var overlap := box.intersection(
				b.placement(float(layout.decks[str(b.deck)])) * b.module.occupied
			)
			if overlap.size.x > 0.001 and overlap.size.y > 0.001 and overlap.size.z > 0.001:
				errors.append("Occupied overlap: %s / %s" % [a.id, b.id])
	var used := {}
	var security_ids := {}
	var graph := {}
	for c in layout.connections:
		var a := layout.instance(c.from_instance)
		var b := layout.instance(c.to_instance)
		var label := "%s/%s -> %s/%s" % [c.from_instance, c.from_socket, c.to_instance, c.to_socket]
		if a == null or b == null or a == b:
			errors.append("Invalid endpoints: " + label)
			continue
		var sa := a.module.socket(c.from_socket)
		var sb := b.module.socket(c.to_socket)
		if sa == null or sb == null:
			errors.append("Unknown socket: " + label)
			continue
		for key: String in [str(a.id) + "/" + str(sa.id), str(b.id) + "/" + str(sb.id)]:
			if used.has(key):
				errors.append("Reused socket: " + key)
			used[key] = true
		if (
			not a.allows(sa.id)
			or not b.allows(sb.id)
			or c.state not in ["open", "door", "security_door"]
		):
			errors.append("Unavailable connection: " + label)
		if c.state == "security_door":
			var id := c.security_id if c.security_id != &"" else StringName(label)
			if security_ids.has(id):
				errors.append("Duplicate security access ID: " + str(id))
			security_ids[id] = true
		elif c.initially_locked:
			errors.append("Lock state requires security door: " + label)
		var ta := a.placement(float(layout.decks[str(a.deck)])) * sa.local_transform
		var tb := b.placement(float(layout.decks[str(b.deck)])) * sb.local_transform
		if (
			a.socket_deck(sa.id) == &""
			or a.socket_deck(sa.id) != b.socket_deck(sb.id)
			or ta.origin.distance_to(tb.origin) > 0.001
			or ta.basis.z.dot(tb.basis.z) > -0.999
		):
			errors.append("Misaligned sockets: " + label)
		if (
			sa.family != sb.family
			or absf(sa.width - sb.width) > 0.001
			or absf(sa.height - sb.height) > 0.001
		):
			errors.append("Incompatible sockets: " + label)
		if not graph.has(a.id):
			graph[a.id] = []
		if not graph.has(b.id):
			graph[b.id] = []
		graph[a.id].append(b.id)
		graph[b.id].append(a.id)
	if require_route:
		var visited := {}
		var queue: Array[StringName] = [layout.entry_instance]
		while not queue.is_empty():
			var id: StringName = queue.pop_front()
			if visited.has(id):
				continue
			visited[id] = true
			for other: StringName in graph.get(id, []):
				queue.append(other)
		for item in layout.instances:
			if not visited.has(item.id):
				errors.append("Disconnected instance: " + str(item.id))
		if (
			layout.instance(layout.entry_instance) == null
			or layout.instance(layout.destination_instance) == null
		):
			errors.append("Missing entry/destination instance")
	return errors


static func validate_geometry(item: LevelModuleInstance) -> PackedStringArray:
	var errors := PackedStringArray()
	var module := item.module
	if module.interiors.is_empty() and module.boundary_patches.is_empty():
		errors.append("Missing enclosure surfaces: " + str(item.id))
	var seen := {}
	for patch in module.boundary_patches:
		if patch == null:
			errors.append("Null boundary patch: " + str(item.id))
			continue
		if (
			patch.id == &""
			or seen.has(patch.id)
			or not patch.origin.is_finite()
			or not patch.span_u.is_finite()
			or not patch.span_v.is_finite()
			or patch.span_u.length() < .01
			or patch.span_v.length() < .01
			or not patch.normal.is_normalized()
			or absf(patch.span_u.normalized().dot(patch.normal)) > .001
			or absf(patch.span_v.normalized().dot(patch.normal)) > .001
			or patch.span_u.cross(patch.span_v).length() < .001
			or (patch.socket != &"" and module.socket(patch.socket) == null)
		):
			errors.append("Invalid boundary patch: %s/%s" % [item.id, patch.id])
		seen[patch.id] = true
	for id: Variant in module.equipment_anchors:
		if (
			not module.equipment_anchors[id] is Transform3D
			or not module.equipment_anchors[id].is_finite()
		):
			errors.append("Invalid equipment anchor: %s/%s" % [item.id, id])
	for id: Variant in module.equipment_clearances:
		var box: Variant = module.equipment_clearances[id]
		if (
			not box is AABB
			or not box.position.is_finite()
			or not box.size.is_finite()
			or box.size.x <= 0
			or box.size.y <= 0
			or box.size.z <= 0
			or not module.occupied.grow(.001).encloses(box)
			or not module.equipment_anchors.has(id)
		):
			errors.append("Invalid equipment clearance: %s/%s" % [item.id, id])
	return errors


static func validate_transports(layout: LevelLayout, require_pairs: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	var endpoints := {}
	var used_slots := {}
	for item in layout.instances:
		if item == null or item.module == null:
			continue
		for endpoint in item.transport_endpoints:
			if endpoint == null:
				errors.append("Null transport endpoint: " + str(item.id))
				continue
			if (
				endpoint.id == &""
				or endpoints.has(endpoint.id)
				or endpoint.kind not in ["rings", "elevator"]
				or not item.module.equipment_anchors.has(str(endpoint.anchor))
				or not item.module.equipment_clearances.has(str(endpoint.anchor))
			):
				errors.append("Invalid transport endpoint: %s/%s" % [item.id, endpoint.id])
			var slot_key := str(item.id) + "/" + str(endpoint.anchor)
			if used_slots.has(slot_key):
				errors.append("Reused transport anchor: " + slot_key)
			used_slots[slot_key] = true
			endpoints[endpoint.id] = endpoint
	for id: Variant in endpoints:
		var endpoint: LevelTransportEndpoint = endpoints[id]
		if endpoint.target_id == &"" and not require_pairs:
			continue
		var target := endpoints.get(endpoint.target_id) as LevelTransportEndpoint
		if (
			target == null
			or target == endpoint
			or target.kind != endpoint.kind
			or target.target_id != id
		):
			errors.append("Unpaired transport endpoint: %s -> %s" % [id, endpoint.target_id])
	return errors
