class_name LevelTopology
extends RefCounted
## Optional gameplay-level checks on a layout's room graph. Separate from structural
## validity: a linear map is a valid build even when a mission wants two approaches.
## Everything here is connectivity only; it says nothing about cover or stealth quality.


## {room: [{to, type, locked, security_id}]}
static func graph(layout: LevelLayout) -> Dictionary:
	var result := {}
	for item in layout.instances:
		result[str(item.id)] = []
	for edge in layout.connections:
		var a := str(edge.from_instance)
		var b := str(edge.to_instance)
		if not result.has(a) or not result.has(b):
			continue
		for pair: Array in [[a, b], [b, a]]:
			result[pair[0]].append(
				{
					"to": pair[1],
					"type": edge.state,
					"locked": edge.initially_locked,
					"security_id": str(edge.security_id)
				}
			)
	return result


## Rooms reachable from `start`. `removed` rooms and, optionally, locked doors are impassable.
static func reach(
	links: Dictionary, start: String, removed: Array = [], unlocked_only: bool = false
) -> Dictionary:
	var seen := {}
	if not links.has(start) or start in removed:
		return seen
	var queue: Array[String] = [start]
	seen[start] = true
	while not queue.is_empty():
		var room: String = queue.pop_front()
		for edge: Dictionary in links[room]:
			if seen.has(edge.to) or edge.to in removed or (unlocked_only and edge.locked):
				continue
			seen[edge.to] = true
			queue.append(edge.to)
	return seen


static func path(
	links: Dictionary, start: String, goal: String, removed: Array = [], unlocked_only: bool = false
) -> Array:
	var previous := {start: ""}
	var queue: Array[String] = [start]
	if not links.has(start) or not links.has(goal) or start in removed or goal in removed:
		return []
	while not queue.is_empty():
		var room: String = queue.pop_front()
		if room == goal:
			var result: Array = []
			while room != "":
				result.push_front(room)
				room = previous[room]
			return result
		for edge: Dictionary in links[room]:
			if previous.has(edge.to) or edge.to in removed or (unlocked_only and edge.locked):
				continue
			previous[edge.to] = room
			queue.append(edge.to)
	return []


## Routes between two rooms that share no intermediate room, found by repeated
## augmenting search (rooms have capacity one). Small graphs only.
static func distinct_routes(
	links: Dictionary, start: String, goal: String, unlocked_only: bool = false
) -> Array:
	var routes: Array = []
	if start == goal or not links.has(start) or not links.has(goal):
		return routes
	# Residual graph over split nodes: "room|in" -> "room|out" has capacity one.
	var capacity := {}
	var adjacency := {}
	var add := func(a: String, b: String, amount: int) -> void:
		for pair: Array in [[a, b, amount], [b, a, 0]]:
			if not adjacency.has(pair[0]):
				adjacency[pair[0]] = []
			if not capacity.has(pair[0] + ">" + pair[1]):
				adjacency[pair[0]].append(pair[1])
				capacity[pair[0] + ">" + pair[1]] = 0
			capacity[pair[0] + ">" + pair[1]] += pair[2]
	for room: String in links:
		add.call(room + "|in", room + "|out", 99 if room in [start, goal] else 1)
		for edge: Dictionary in links[room]:
			if not (unlocked_only and edge.locked):
				add.call(room + "|out", edge.to + "|in", 1)
	var source := start + "|in"
	var sink := goal + "|out"
	while routes.size() < 16:
		var previous := {source: ""}
		var queue: Array[String] = [source]
		while not queue.is_empty() and not previous.has(sink):
			var node: String = queue.pop_front()
			for other: String in adjacency.get(node, []):
				if not previous.has(other) and capacity[node + ">" + other] > 0:
					previous[other] = node
					queue.append(other)
		if not previous.has(sink):
			break
		var node := sink
		while previous[node] != "":
			capacity[previous[node] + ">" + node] -= 1
			capacity[node + ">" + previous[node]] += 1
			node = previous[node]
		routes.append(true)
	# Decompose the final flow into room lists.
	var flow := {}
	for room: String in links:
		for edge: Dictionary in links[room]:
			var key: String = room + "|out>" + edge.to + "|in"
			if capacity.has(key) and capacity.get(edge.to + "|in>" + room + "|out", 0) > 0:
				if not flow.has(room):
					flow[room] = []
				if not edge.to in flow[room]:
					flow[room].append(edge.to)
	var count := routes.size()
	routes.clear()
	for i in range(count):
		var route: Array = [start]
		var room := start
		while room != goal and flow.has(room) and not flow[room].is_empty() and route.size() < 99:
			room = flow[room].pop_front()
			route.append(room)
		routes.append(route)
	return routes


## Descriptive facts for an agent: derived from connections only.
static func summary(layout: LevelLayout) -> Dictionary:
	var links := graph(layout)
	var dead_ends: Array = []
	var junctions: Array = []
	var edges := 0
	for room: String in links:
		var neighbours := {}
		for edge: Dictionary in links[room]:
			neighbours[edge.to] = true
		edges += links[room].size()
		if neighbours.size() <= 1:
			dead_ends.append(room)
		elif neighbours.size() >= 3:
			junctions.append(room)
	edges /= 2
	var components := 0
	var seen := {}
	for room: String in links:
		if not seen.has(room):
			components += 1
			seen.merge(reach(links, room))
	var entry := str(layout.entry_instance)
	var everything := reach(links, entry)
	var cut_rooms: Array = []
	for room: String in links:
		if room != entry and reach(links, entry, [room]).size() < everything.size() - 1:
			cut_rooms.append(room)
	var doors: Array = []
	var roles := {}
	for item in layout.instances:
		if item.room_preset != null:
			roles[str(item.room_preset.id)] = roles.get(str(item.room_preset.id), []) + [str(item.id)]
	for edge in layout.connections:
		if edge.state == "security_door":
			doors.append(
				{
					"between": [str(edge.from_instance), str(edge.to_instance)],
					"security_id": str(edge.security_id),
					"locked": edge.initially_locked
				}
			)
	return {
		"rooms": links.size(),
		"links": edges,
		"separate_areas": components,
		"loops": edges - links.size() + components,
		"dead_ends": dead_ends,
		"junctions": junctions,
		"chokepoint_rooms": cut_rooms,
		"security_doors": doors,
		"roles": roles,
		"entry": entry,
		"destination": str(layout.destination_instance),
		"basis": "Connectivity only. Does not assess cover, sightlines or stealth."
	}


static func evaluate(layout: LevelLayout, requirements: Variant) -> Dictionary:
	var results: Array = []
	var links := graph(layout)
	if not requirements is Array:
		return {
			"ok": false,
			"results": [{"check": "", "ok": false, "detail": "requirements must be an array"}]
		}
	for requirement: Variant in requirements:
		if not requirement is Dictionary:
			results.append({"check": "", "ok": false, "detail": "Requirement must be an object"})
			continue
		var result := _check(layout, links, requirement)
		result["check"] = str(requirement.get("check", ""))
		if requirement.has("label"):
			result["label"] = str(requirement.label)
		results.append(result)
	var passed := true
	for result: Dictionary in results:
		passed = passed and result.ok
	return {"ok": passed, "results": results}


static func _room(layout: LevelLayout, data: Dictionary, key: String) -> String:
	var value := str(data.get(key, ""))
	if value == "entry":
		return str(layout.entry_instance)
	if value == "destination":
		return str(layout.destination_instance)
	return value


static func _check(layout: LevelLayout, links: Dictionary, data: Dictionary) -> Dictionary:
	var kind := str(data.get("check", ""))
	var unlocked := bool(data.get("unlocked_only", false))
	var from := _room(layout, data, "from")
	var to := _room(layout, data, "to")
	for key: String in ["from", "to", "around", "room", "via"]:
		if data.has(key) and not links.has(_room(layout, data, key)):
			return {"ok": false, "detail": "Unknown room: " + str(data[key])}
	match kind:
		"connected":
			var found := reach(links, str(layout.entry_instance))
			var missing: Array = []
			for room: String in links:
				if not found.has(room):
					missing.append(room)
			return {"ok": missing.is_empty(), "isolated": missing}
		"distinct_routes":
			var routes := distinct_routes(links, from, to, unlocked)
			var wanted := int(data.get("min", 2))
			return {"ok": routes.size() >= wanted, "found": routes.size(), "routes": routes}
		"alternate_route":
			var around := _room(layout, data, "around")
			var route := path(links, from, to, [around], unlocked)
			return {"ok": not route.is_empty(), "route": route, "avoiding": around}
		"only_via":
			# Defensible room: every way in from `from` passes through `via`.
			var room := _room(layout, data, "room")
			var via := _room(layout, data, "via")
			var bypass := path(links, from if data.has("from") else str(layout.entry_instance), room, [via])
			return {"ok": bypass.is_empty(), "bypass": bypass, "via": via}
		"reachable":
			var route := path(links, from, to, [], unlocked)
			return {"ok": not route.is_empty(), "route": route}
		"route":
			var stops: Array = data.get("through", [])
			var walked: Array = []
			for i in range(stops.size() - 1):
				var a := _room(layout, {"x": stops[i]}, "x")
				var b := _room(layout, {"x": stops[i + 1]}, "x")
				var leg := path(links, a, b, [], unlocked)
				if leg.is_empty():
					return {"ok": false, "detail": "No route from %s to %s" % [a, b]}
				walked.append(leg)
			return {"ok": stops.size() >= 2, "legs": walked}
		"min_branches":
			var junctions: Array = summary(layout).junctions
			return {"ok": junctions.size() >= int(data.get("min", 1)), "junctions": junctions}
		"dead_ends":
			var allowed: Array = data.get("allowed", [])
			var undeclared: Array = []
			var actual: Array = summary(layout).dead_ends
			for room: String in actual:
				if not room in allowed:
					undeclared.append(room)
			var missing: Array = []
			for room: Variant in allowed:
				if not str(room) in actual:
					missing.append(str(room))
			return {
				"ok": undeclared.is_empty() and missing.is_empty(),
				"dead_ends": actual,
				"undeclared": undeclared,
				"declared_but_connected": missing
			}
		"room_count":
			var count := links.size()
			return {
				"ok": count >= int(data.get("min", 0)) and count <= int(data.get("max", 9999)),
				"rooms": count
			}
		"roles":
			var have: Dictionary = summary(layout).roles
			var short := {}
			var required: Dictionary = data.get("required", {})
			for role: Variant in required:
				var count: int = have.get(str(role), []).size()
				if count < int(required[role]):
					short[str(role)] = {"required": int(required[role]), "found": count}
			return {"ok": short.is_empty(), "missing": short}
		"single_access":
			var room := _room(layout, data, "room")
			var neighbours := {}
			for edge: Dictionary in links[room]:
				neighbours[edge.to] = true
			return {
				"ok": neighbours.size() <= int(data.get("max", 1)), "entrances": neighbours.keys()
			}
	return {
		"ok": false,
		"detail":
		"Unknown check. Use connected, distinct_routes, alternate_route, reachable, route, only_via, min_branches, dead_ends, room_count, roles or single_access."
	}
