class_name LevelPlanner
extends RefCounted
## Turns a requested room graph into an ordinary LevelLayout. Bounded and deterministic:
## a depth-first search over existing modules and named sockets, where every placement
## is made by LevelAssembler.snap and checked by LevelLayoutValidator. It never creates
## geometry and never adds a room the request did not name; when the graph cannot be
## placed it reports the room and the reason.
const DEFAULT_BUDGET := 4000
const KINDS := ["corridor", "junction", "wide_corridor", "wide_junction", "adapter", "ramp", "chamber"]

var layout: LevelLayout
var rooms := {}
var order: Array[String] = []
var neighbours := {}
var candidates := {}
var presets := {}
var span := {}
var budget := DEFAULT_BUDGET
var attempts := 0
var deepest := -1
var blocker := {}


static func plan(request: Dictionary) -> Dictionary:
	var planner := LevelPlanner.new()
	return planner._run(request)


func _fail(code: String, reason: String, ids: Array = [], remedy: String = "") -> Dictionary:
	return {
		"ok": false,
		"errors":
		[
			LevelAuthoring.issue(
				code,
				reason,
				ids,
				[],
				remedy if remedy != "" else "Correct the plan request; see the planning guide."
			)
		]
	}


func _run(request: Dictionary) -> Dictionary:
	for key: Variant in request:
		if not str(key) in [
			"version", "theme_id", "decks", "rooms", "links", "entry", "destination",
			"requirements", "budget", "transports", "clusters"
		]:
			return _fail("unsupported_field", "Unknown plan field: " + str(key))
	if not request.get("rooms") is Array or not request.get("links", []) is Array:
		return _fail("invalid_plan", "rooms and links must be arrays")
	budget = clampi(int(request.get("budget", DEFAULT_BUDGET)), 1, 20000)
	layout = LevelLayout.new()
	if request.get("decks", {"deck0": 0.0}) is Dictionary:
		layout.decks = request.get("decks", {"deck0": 0.0}).duplicate()
	layout.default_theme = StringName(str(request.get("theme_id", "neutral")))
	if not LevelThemeResolver.registry().has(layout.default_theme):
		return _fail("unknown_theme", "Unknown theme: " + str(layout.default_theme))
	for data: Variant in request.rooms:
		if not data is Dictionary or not LevelAuthoring.identifier(str(data.get("id", ""))):
			return _fail("invalid_room", "Each room needs a node-safe id")
		if rooms.has(str(data.id)):
			return _fail("invalid_room", "Duplicate room id: " + str(data.id), [str(data.id)])
		for key: Variant in data:
			if not str(key) in ["id", "kind", "module_id", "deck", "size"]:
				return _fail("unsupported_field", "Unknown room field: " + str(key), [str(data.id)])
		if not layout.decks.has(str(data.get("deck", "deck0"))):
			return _fail("unknown_deck", "Room deck is not declared: " + str(data.id), [str(data.id)])
		rooms[str(data.id)] = data
		neighbours[str(data.id)] = []
	var link_data := {}
	for data: Variant in request.get("links", []):
		if not data is Dictionary:
			return _fail("invalid_link", "Each link needs rooms a and b")
		var a := str(data.get("a", ""))
		var b := str(data.get("b", ""))
		if not rooms.has(a) or not rooms.has(b) or a == b or b in neighbours[a]:
			return _fail("invalid_link", "Link must join two different known rooms once", [a, b])
		for key: Variant in data:
			if not str(key) in ["a", "b", "type", "security_id", "locked"]:
				return _fail("unsupported_field", "Unknown link field: " + str(key), [a, b])
		if str(data.get("type", "door")) not in ["open", "door", "security_door"]:
			return _fail("invalid_link", "Link type must be open, door or security_door", [a, b])
		if bool(data.get("locked", false)) and str(data.get("type", "")) != "security_door":
			return _fail("invalid_link", "Only a security_door can be locked", [a, b])
		neighbours[a].append(b)
		neighbours[b].append(a)
		link_data[_key(a, b)] = data
	var entry := str(request.get("entry", request.rooms[0].id if not request.rooms.is_empty() else ""))
	var destination := str(request.get("destination", entry))
	# The destination may be a room inside a cluster, which exists only after expansion.
	if not rooms.has(entry) or (not rooms.has(destination) and request.get("clusters", []).is_empty()):
		return _fail("invalid_endpoint", "entry and destination must name rooms")
	# Rooms on loops are placed first, walking round each loop so a loop that cannot close
	# is found before any side room is tried. Every later room touches an earlier one.
	var degree := {}
	var core := {}
	for id: String in rooms:
		degree[id] = neighbours[id].size()
		core[id] = true
	var peeled := true
	while peeled:
		peeled = false
		for id: String in rooms:
			if core.has(id) and degree[id] <= 1:
				core.erase(id)
				peeled = true
				for other: String in neighbours[id]:
					degree[other] -= 1
	var trail := {entry: ""}
	var queue: Array[String] = [entry]
	var gateway := ""
	while not queue.is_empty() and gateway == "":
		var room: String = queue.pop_front()
		if core.has(room):
			gateway = room
		for other: String in neighbours[room]:
			if not trail.has(other):
				trail[other] = room
				queue.append(other)
	var lead: Array[String] = []
	var step := gateway
	while step != "":
		lead.push_front(step)
		step = trail[step]
	order = lead
	if gateway == "":
		order = [entry]
	var stack: Array[String] = []
	if gateway != "":
		stack.append(gateway)
	while not stack.is_empty():
		var room: String = stack[-1]
		# Shortest run of plain two-door rooms first: a short cross-link pins both of its
		# ends before the long arms of the loop are tried.
		var next := ""
		var shortest := 9999
		for other: String in neighbours[room]:
			if not core.has(other) or other in order:
				continue
			var run := 0
			var previous := room
			var walker := other
			while degree[walker] == 2 and not walker in order and run < rooms.size():
				run += 1
				var onward := ""
				for candidate: String in neighbours[walker]:
					if core.has(candidate) and candidate != previous:
						onward = candidate
				if onward == "":
					break
				previous = walker
				walker = onward
			if run < shortest:
				shortest = run
				next = other
		if next == "":
			stack.pop_back()
		else:
			order.append(next)
			stack.append(next)
	var cursor := 0
	while cursor < order.size():
		for other: String in neighbours[order[cursor]]:
			if not other in order:
				order.append(other)
		cursor += 1
	if order.size() != rooms.size():
		var isolated: Array = []
		for id: String in rooms:
			if not id in order:
				isolated.append(id)
		return _fail(
			"disconnected_plan",
			"Rooms are not linked to the entry: " + ", ".join(isolated),
			isolated,
			"Add a link for each listed room, or remove it."
		)
	# A room that hosts clusters keeps a doorway spare for each of them.
	var hosted := {}
	for data: Variant in request.get("clusters", []):
		if data is Dictionary:
			hosted[str(data.get("attach_to", ""))] = int(hosted.get(str(data.get("attach_to", "")), 0)) + 1
	for id: String in order:
		var found := _candidates(rooms[id], neighbours[id].size() + int(hosted.get(id, 0)))
		if found.has("error"):
			return _fail("no_module", found.error, [id], found.remedy)
		candidates[id] = found.modules
		presets[id] = LevelCapabilityCatalogue.preset_by_id(StringName(str(rooms[id].get("kind", ""))))
	_measure_reach()
	layout.entry_instance = StringName(entry)
	layout.destination_instance = StringName(destination if rooms.has(destination) else entry)
	if not _place(0):
		return _unplaceable()
	for edge in layout.connections:
		var data: Dictionary = link_data[_key(str(edge.from_instance), str(edge.to_instance))]
		var a := layout.instance(edge.from_instance).module
		var b := layout.instance(edge.to_instance).module
		edge.state = str(data.get("type", LevelAssembler.connection_default(a, b)))
		edge.security_id = StringName(str(data.get("security_id", "")))
		edge.initially_locked = bool(data.get("locked", false))
	# Clusters are existing composites hung on a planned room; sockets are chosen for them.
	for data: Variant in request.get("clusters", []):
		if not data is Dictionary or not data.has("composite_id") or not data.has("prefix"):
			return _fail("invalid_cluster", "Each cluster needs composite_id, prefix and attach_to")
		for key: Variant in data:
			if not str(key) in ["composite_id", "prefix", "attach_to", "opening", "type", "deck_map"]:
				return _fail("unsupported_field", "Unknown cluster field: " + str(key))
		var host := layout.instance(StringName(str(data.get("attach_to", ""))))
		var composite := LevelCapabilityCatalogue.composite_by_id(StringName(str(data.composite_id)))
		if host == null or composite == null:
			return _fail(
				"invalid_cluster",
				"Unknown composite or attach_to room: %s -> %s" % [data.composite_id, data.get("attach_to", "")],
				[str(data.get("attach_to", ""))],
				"List composites with catalogue --kind composite --summary."
			)
		var attach: Dictionary = {"target": str(host.id)}
		for key: String in ["opening", "type"]:
			if data.has(key):
				attach[key] = data[key]
		var op: Dictionary = {
			"op": "composite", "composite_id": str(data.composite_id), "prefix": str(data.prefix),
			"attach": attach
		}
		# A single-deck cluster lands on whichever deck the host's free doorway is on
		# (a ramp's free end may be the upper deck).
		var deck_maps: Array = [data.get("deck_map", {})]
		if not data.has("deck_map") and composite.layout.decks.size() == 1:
			deck_maps.clear()
			for socket: String in LevelAuthoring.free_sockets(layout, host.id):
				var choice := {str(composite.layout.decks.keys()[0]): str(host.socket_deck(StringName(socket)))}
				if not choice in deck_maps:
					deck_maps.append(choice)
		var errors: Array = [LevelAuthoring.issue("composite_does_not_fit", "Host room has no free doorway: " + str(host.id), [str(host.id)])]
		for deck_map: Dictionary in deck_maps:
			op["deck_map"] = deck_map
			var trial := LevelAuthoring.Model.copy(layout)
			errors = LevelAuthoring.operation(trial, op)
			if errors.is_empty():
				errors = LevelAuthoring.operation(layout, op)
				break
		if not errors.is_empty():
			return {"ok": false, "errors": errors}
	if layout.instance(StringName(destination)) == null:
		return _fail(
			"invalid_endpoint",
			"destination is not a planned or cluster room: " + destination,
			[destination],
			"Cluster rooms are named <prefix>_<member>."
		)
	layout.destination_instance = StringName(destination)
	for data: Variant in request.get("transports", []):
		var errors: Array = (
			LevelAuthoring.operation(layout, data.merged({"op": "transport"}))
			if data is Dictionary
			else [LevelAuthoring.issue("invalid_transport", "transports entries must be objects")]
		)
		if not errors.is_empty():
			return {"ok": false, "errors": errors}
	var final := LevelAuthoring.messages(LevelLayoutValidator.validate(layout, false), layout)
	if not final.is_empty():
		return {"ok": false, "errors": final}
	var placed: Array = []
	for item in layout.instances:
		placed.append(
			{
				"id": str(item.id),
				"module_id": str(item.module.id),
				"preset_id": str(item.room_preset.id) if item.room_preset != null else "",
				"at": [item.position.x, item.position.y],
				"turn": item.quarter_turn,
				"deck": str(item.deck)
			}
		)
	return {"ok": true, "layout": layout, "placed": placed, "attempts": attempts}


func _key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


## Modules that can play the requested part, smallest suitable first. Facts come from
## the module and preset resources; nothing is assumed from names.
func _candidates(room: Dictionary, degree: int) -> Dictionary:
	var kind := str(room.get("kind", "corridor"))
	if room.has("module_id"):
		var module := LevelCatalogue.module_by_id(StringName(str(room.module_id)))
		if module == null:
			return {
				"error": "Unknown module: " + str(room.module_id),
				"remedy": "Run catalogue --kind module --summary."
			}
		if module.sockets.size() < degree:
			return {
				"error":
				"%s needs %d connections but %s has %d sockets" % [
					room.id, degree, module.id, module.sockets.size()
				],
				"remedy": "Choose a module with more sockets or remove a link."
			}
		return {"modules": [module]}
	var preset := LevelCapabilityCatalogue.preset_by_id(StringName(kind))
	if preset == null and not kind in KINDS:
		return {
			"error": "Unknown room kind: " + kind,
			"remedy":
			"Use a preset id from catalogue --kind preset --summary, or one of: " + ", ".join(KINDS)
		}
	var wide := kind.begins_with("wide_")
	var found: Array = []
	for module in LevelCatalogue.module_definitions():
		var families := {}
		for socket in module.sockets:
			families[str(socket.family)] = true
		var suitable := false
		if preset != null:
			suitable = str(module.id) in preset.compatible_modules
		elif kind == "ramp":
			suitable = "vertical" in module.tags and "corridor" in module.tags
		elif kind == "adapter":
			suitable = "adapter" in module.tags
		elif kind == "chamber":
			suitable = "chamber" in module.tags and module.equipment_anchors.is_empty()
		else:
			suitable = (
				"corridor" in module.tags
				and not "vertical" in module.tags
				and families.keys() == ["wide_passage" if wide else "passage"]
			)
		if suitable and module.sockets.size() >= degree:
			found.append(module)
	if found.is_empty():
		return {
			"error":
			"No existing module can be a %s with %d connections (%s)" % [kind, degree, room.id],
			"remedy": "Reduce this room's links, split it with a junction, or pick another kind."
		}
	if preset != null or kind == "chamber":
		found.sort_custom(
			func(a: LevelModuleDefinition, b: LevelModuleDefinition) -> bool:
				var area_a := a.occupied.size.x * a.occupied.size.z
				var area_b := b.occupied.size.x * b.occupied.size.z
				return area_a < area_b if area_a != area_b else str(a.id) < str(b.id)
		)
		var size := str(room.get("size", "small"))
		if size == "large":
			found.reverse()
		elif size == "medium" and found.size() > 2:
			found = found.slice(1) + [found[0]]
		# One predictable shell per room keeps the search small; ask for a size or module_id
		# to change it.
		return {"modules": found.slice(0, 1)}
	# Corridor pieces: only the shapes with the fewest spare openings.
	var fewest := 99
	for module: LevelModuleDefinition in found:
		fewest = mini(fewest, module.sockets.size())
	var pieces: Array = []
	for module: LevelModuleDefinition in found:
		if module.sockets.size() == fewest:
			pieces.append(module)
	return {"modules": pieces}


## Widest doorway-to-doorway distance across each room, over its candidate modules.
func _measure_reach() -> void:
	for id: String in order:
		var widest := 0.0
		for module: LevelModuleDefinition in candidates[id]:
			for a in module.sockets:
				for b in module.sockets:
					var offset := a.local_transform.origin - b.local_transform.origin
					widest = maxf(widest, absf(offset.x) + absf(offset.z))
		span[id] = widest


## For each placed room still to be joined to `id` through rooms not yet placed: the most
## those rooms can span. A placement further away than that can never be joined.
func _limits(id: String) -> Dictionary:
	var cost := {}
	var limits := {}
	var frontier: Array[String] = []
	for other: String in neighbours[id]:
		if layout.instance(StringName(other)) == null:
			cost[other] = 0.0
			frontier.append(other)
	while not frontier.is_empty():
		frontier.sort_custom(func(x: String, y: String) -> bool: return cost[x] < cost[y])
		var room: String = frontier.pop_front()
		var beyond: float = cost[room] + span[room]
		for other: String in neighbours[room]:
			if other == id:
				continue
			if layout.instance(StringName(other)) != null:
				limits[other] = minf(float(limits.get(other, INF)), beyond)
			elif not cost.has(other) or beyond < cost[other]:
				cost[other] = beyond
				if not other in frontier:
					frontier.append(other)
	return limits


## World positions of a placed room's doorways that no link uses yet.
func _doorways(item: LevelModuleInstance) -> Array[Vector3]:
	var taken := {}
	for edge in layout.connections:
		if edge.from_instance == item.id:
			taken[edge.from_socket] = true
		if edge.to_instance == item.id:
			taken[edge.to_socket] = true
	var result: Array[Vector3] = []
	var pose := item.placement(float(layout.decks[str(item.deck)]))
	for socket in item.module.sockets:
		if not taken.has(socket.id):
			result.append(pose * socket.local_transform.origin)
	return result


func _gap(a: LevelModuleInstance, b: LevelModuleInstance) -> float:
	var nearest := INF
	for p in _doorways(a):
		for q in _doorways(b):
			nearest = minf(nearest, absf(p.x - q.x) + absf(p.z - q.z))
	return nearest


func _note(index: int, id: String, reason: String, other: String = "", gap: float = -1.0) -> void:
	if index < deepest:
		return
	if index > deepest:
		deepest = index
		blocker = {"room": id, "reasons": {}, "nearest_gap": {}}
	blocker.reasons[reason] = int(blocker.reasons.get(reason, 0)) + 1
	if other != "" and gap >= 0.0:
		blocker.nearest_gap[other] = minf(float(blocker.nearest_gap.get(other, INF)), gap)


func _place(index: int) -> bool:
	if index == order.size():
		return true
	var id := order[index]
	var room: Dictionary = rooms[id]
	var placed: Array[String] = []
	for other: String in neighbours[id]:
		if layout.instance(StringName(other)) != null:
			placed.append(other)
	for module: LevelModuleDefinition in candidates[id]:
		var item := LevelModuleInstance.new()
		item.id = StringName(id)
		item.module = module
		item.deck = StringName(str(room.get("deck", "deck0")))
		item.bind_matching_decks(layout.decks)
		var preset := presets.get(id) as LevelRoomPreset
		if preset != null:
			item.room_preset = preset
			item.role = preset.id
		layout.instances.append(item)
		if placed.is_empty():
			if _place(index + 1):
				return true
			layout.instances.pop_back()
			continue
		var anchor := layout.instance(StringName(placed[0]))
		var taken := {}
		for edge in layout.connections:
			taken[str(edge.from_instance) + "/" + str(edge.from_socket)] = true
			taken[str(edge.to_instance) + "/" + str(edge.to_socket)] = true
		for mine in module.sockets:
			for theirs in anchor.module.sockets:
				if taken.has(placed[0] + "/" + str(theirs.id)):
					continue
				if attempts >= budget:
					layout.instances.pop_back()
					return false
				attempts += 1
				var kept := layout.connections.duplicate()
				var errors := LevelAssembler.snap(layout, item.id, mine.id, anchor.id, theirs.id)
				if not errors.is_empty():
					_note(index, id, _reason(errors))
					continue
				if _joined(index, id, item, placed) and _place(index + 1):
					return true
				layout.connections = kept
		layout.instances.pop_back()
	return false


func _reason(errors: PackedStringArray) -> String:
	var text := errors[0]
	for word: String in ["Occupied overlap", "Incompatible sockets", "Socket decks", "Socket height"]:
		if text.begins_with(word):
			return word.to_lower().replace(" ", "_")
	return "invalid_placement"


## After a snap: every other already-placed neighbour must share a doorway with this
## room, and every unplaced room must still be within reach of the rooms it links to.
func _joined(index: int, id: String, item: LevelModuleInstance, placed: Array[String]) -> bool:
	if placed.size() > 1:
		var before := layout.connections.size()
		LevelAssembler.connect_touching(layout)
		var wanted := {}
		for other: String in placed:
			wanted[_key(id, other)] = true
		var kept: Array[LevelModuleConnection] = []
		for i in range(layout.connections.size()):
			var edge := layout.connections[i]
			var pair := _key(str(edge.from_instance), str(edge.to_instance))
			# Touching doorways the request did not link stay capped.
			if i < before or (wanted.has(pair) and (edge.from_instance == item.id or edge.to_instance == item.id)):
				kept.append(edge)
				wanted.erase(pair)
		layout.connections = kept
		wanted.erase(_key(id, placed[0]))
		if not wanted.is_empty():
			for pair: String in wanted:
				var other := pair.replace(id, "").replace("|", "")
				_note(index, id, "loop_not_closed", other, _gap(item, layout.instance(StringName(other))))
			return false
	var limits := _limits(id)
	for other: String in limits:
		var gap := _gap(item, layout.instance(StringName(other)))
		if gap > float(limits[other]) + 0.01:
			_note(index, id, "out_of_reach", other, gap - float(limits[other]))
			return false
	return true


func _unplaceable() -> Dictionary:
	var reasons: Dictionary = blocker.get("reasons", {})
	var room := str(blocker.get("room", order[0]))
	var remedy := "Give this room fewer links, a larger module (size or module_id), or move it to another branch."
	if attempts >= budget:
		remedy = "Search budget used. Simplify the loop, fix more module_id choices, or raise budget."
	if reasons.has("loop_not_closed") or reasons.has("out_of_reach"):
		remedy = "A loop through this room does not fit the rooms on it. Add or remove one corridor room on that loop, use a corner-capable corridor, or drop the closing link."
	elif reasons.has("incompatible_sockets"):
		remedy = "Narrow and wide passages cannot join directly; add an adapter room between them."
	elif reasons.has("socket_decks") or reasons.has("socket_height"):
		remedy = "Rooms on different decks must be joined through a ramp room whose rise equals the deck difference."
	var result := _fail(
		"plan_unplaceable",
		"Could not place %s after placing %d of %d rooms" % [room, maxi(deepest, 0), order.size()],
		[room],
		remedy
	)
	result.errors[0]["diagnosis"] = {
		"blocked_room": room,
		"placed_before_it": order.slice(0, maxi(deepest, 0)),
		"rejections": reasons,
		"nearest_gap_metres": blocker.get("nearest_gap", {}),
		"attempts": attempts,
		"budget": budget
	}
	return result
