@tool
class_name LevelLayoutValidator
extends RefCounted


static func validate(layout: LevelLayout, require_route: bool = true) -> PackedStringArray:
	var errors := PackedStringArray()
	if layout == null:
		return PackedStringArray(["Missing layout"])
	if layout.schema_version != 1:
		errors.append("Unsupported layout schema")
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
		var sockets := {}
		for s in item.module.sockets:
			if s == null:
				errors.append("Null socket: " + str(item.id))
				continue
			if s.id == &"" or sockets.has(s.id):
				errors.append("Duplicate/empty socket: %s/%s" % [item.id, s.id])
			sockets[s.id] = true
			if s.width < 1.2 or s.height < 2.0:
				errors.append("Insufficient clearance: %s/%s" % [item.id, s.id])
		for id in item.available_sockets:
			if not sockets.has(StringName(id)):
				errors.append("Unknown available socket: %s/%s" % [item.id, id])
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
		if not a.allows(sa.id) or not b.allows(sb.id) or c.state != "open":
			errors.append("Unavailable connection: " + label)
		var ta := a.placement(float(layout.decks[str(a.deck)])) * sa.local_transform
		var tb := b.placement(float(layout.decks[str(b.deck)])) * sb.local_transform
		if (
			a.deck != b.deck
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
