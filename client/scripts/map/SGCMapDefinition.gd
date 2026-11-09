class_name SGCMapDefinition
extends Resource

const FLOOR_HEIGHTS: Dictionary = {28: 0.0, 27: 5.5, 26: 11.0}
const CONTROL_FLOOR_Y: float = 1.5
const GATE_DIAMETER: float = 6.7
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.8
const LIFT_ENCLOSURE := AABB(Vector3(35.4, -0.5, 16.1), Vector3(3.45, 15.7, 3.8))
const WALL_THICKNESS: float = 0.3
const REFERENCE: String = "https://rdanderson.com/stargate/cheyenne/index.htm"
@export var regions: Array[SGCRegion] = []
@export var connections: Array[SGCConnection] = []
@export var styles: Array[SGCAssetStyle] = []
@export var asset_slots: Array[SGCAssetSlot] = []


func region(id: StringName) -> SGCRegion:
	for r in regions:
		if r.id == id:
			return r
	return null


func region_at(point: Vector3) -> StringName:
	for r in regions:
		if r.contains(point, FLOOR_HEIGHTS[r.floor_number]):
			return r.id
	return &""


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for r in regions:
		if ids.has(r.id) or r.id == &"":
			errors.append("Duplicate/empty region: " + str(r.id))
		ids[r.id] = true
		if (
			r.footprint.size.x <= 0
			or r.footprint.size.y <= 0
			or r.ceiling_height < CAPSULE_HEIGHT + 0.2
		):
			errors.append("Invalid interior dimensions: " + str(r.id))
		if not FLOOR_HEIGHTS.has(r.floor_number):
			errors.append("Unsupported floor")
	for c in connections:
		if region(c.from_region) == null or region(c.to_region) == null:
			errors.append("Invalid endpoints: " + str(c.id))
			continue
		if c.width < CAPSULE_RADIUS * 2.0 + 0.2 or c.clearance_height < CAPSULE_HEIGHT + 0.2:
			errors.append("Insufficient clearance: " + str(c.id))
		if c.points.is_empty():
			errors.append("Missing portal: " + str(c.id))
			continue
		if c.kind == "walk" and not _shared_portal(c):
			errors.append("Portal exposes void or has insufficient shared clearance: " + str(c.id))
	for r in regions:
		if r != regions[0] and route(regions[0].id, r.id).is_empty():
			errors.append("Disconnected: " + str(r.id))
	return errors


func _shared_portal(c: SGCConnection) -> bool:
	var from := region(c.from_region)
	var to := region(c.to_region)
	if not FLOOR_HEIGHTS.has(from.floor_number) or not FLOOR_HEIGHTS.has(to.floor_number):
		return false
	if not is_equal_approx(floor_y(from), floor_y(to)):
		return false
	var a := from.footprint
	var b := to.footprint
	var point := Vector2(c.points[0].x, c.points[0].z)
	for axis in range(2):
		var along := 1 - axis
		var shared := (
			(absf(a.end[axis] - b.position[axis]) < 0.01 and absf(point[axis] - a.end[axis]) < 0.01)
			or (
				absf(b.end[axis] - a.position[axis]) < 0.01
				and absf(point[axis] - b.end[axis]) < 0.01
			)
		)
		if not shared:
			continue
		var lo := maxf(maxf(a.position[along], b.position[along]), point[along] - c.width / 2)
		var hi := minf(minf(a.end[along], b.end[along]), point[along] + c.width / 2)
		if hi - lo >= CAPSULE_RADIUS * 2.0 + 0.2:
			return true
	return false


func route(
	start: StringName, goal: StringName, blocked: Array[StringName] = []
) -> Array[SGCConnection]:
	var frontier: Array[StringName] = [start]
	var costs := {start: 0.0}
	var previous := {}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: StringName, b: StringName) -> bool: return costs[a] < costs[b])
		var here: StringName = frontier.pop_front()
		if here == goal:
			break
		for c in connections:
			if not c.enabled or c.id in blocked or (c.from_region != here and c.to_region != here):
				continue
			var next := c.other(here)
			var cost: float = costs[here] + c.cost
			if not costs.has(next) or cost < costs[next]:
				costs[next] = cost
				previous[next] = [here, c]
				if next not in frontier:
					frontier.append(next)
	var result: Array[SGCConnection] = []
	var cursor := goal
	while previous.has(cursor):
		result.push_front(previous[cursor][1])
		cursor = previous[cursor][0]
	if cursor != start:
		result.clear()
	return result


func enclosure_volumes() -> Array[AABB]:
	var result: Array[AABB] = []
	for r in regions:
		result.append(
			AABB(
				Vector3(r.footprint.position.x, floor_y(r), r.footprint.position.y),
				Vector3(r.footprint.size.x, r.ceiling_height, r.footprint.size.y)
			)
		)
	for c in connections:
		if c.kind in ["stairs", "spiral"]:
			result.append(stair_enclosure(c))
	# Retained lift shaft, adjoining all three lobby portals.
	result.append(LIFT_ENCLOSURE)
	return result


func stair_enclosure(c: SGCConnection) -> AABB:
	var a := c.points[0]
	var b := c.points[-1]
	var low := a.min(b)
	var high := a.max(b)
	if c.kind == "spiral":
		for p in c.points:
			low = low.min(p)
			high = high.max(p)
		low -= Vector3(0.8, 0, 0.8)
		high += Vector3(0.8, 0, 0.8)
	else:
		var across := (
			Vector3(1.6, 0, 0.4) if absf(b.z - a.z) > absf(b.x - a.x) else Vector3(0.4, 0, 1.6)
		)
		low -= across
		high += across
	high.y = maxf(
		floor_y(region(c.from_region)) + region(c.from_region).ceiling_height,
		floor_y(region(c.to_region)) + region(c.to_region).ceiling_height
	)
	return AABB(low, high - low)


static func floor_y(r: SGCRegion) -> float:
	return FLOOR_HEIGHTS[r.floor_number] + r.floor_offset


static func create_default() -> SGCMapDefinition:
	var m := SGCMapDefinition.new()
	(
		m
		. _style(
			&"ceiling",
			"Reinforced concrete ceiling panels with dark seams, steel beams and silo service fittings.",
			Color(0.42, 0.44, 0.45)
		)
	)
	m._style(
		&"bunker",
		"Muted cast concrete, panel seams, dark painted steel frames and exposed service conduits.",
		Color(0.30, 0.33, 0.35)
	)
	m._style(
		&"floor",
		"Worn grey non-slip flooring with restrained yellow hazard markings at thresholds.",
		Color(0.19, 0.22, 0.24)
	)
	m._style(
		&"briefing",
		"Dark charcoal briefing carpet, muted concrete walls and brushed metal fittings.",
		Color(0.18, 0.19, 0.22)
	)
	m._style(
		&"office",
		"Warm dark wood furniture, restrained grey walls and dark office carpet.",
		Color(0.24, 0.16, 0.11)
	)
	m._style(
		&"steel",
		"Painted charcoal steel handrails, open metal treads, scuffed edges, no bright white trim.",
		Color(0.20, 0.23, 0.25)
	)
	m._region(
		"GATE_ROOM",
		28,
		Rect2(-12, -22, 24, 30),
		Vector3(5, 0, 4),
		"Two-storey gate atrium; preserve gate/control/briefing sightline.",
		true
	)
	m._region(
		"CONTROL_ROOM",
		28,
		Rect2(-7, 8, 14, 14),
		Vector3(5, 1.5, 15),
		"Operations below briefing room.",
		true
	)
	m._region("FALLBACK_HALLWAY", 28, Rect2(-3, 22, 6, 20), Vector3(2.5, 0, 29))
	m._region("CONNECTOR_TUNNEL", 28, Rect2(3, 34, 14, 4), Vector3(11, 0, 36))
	m._region("ROUND_HALLWAY", 28, Rect2(17, 24, 18, 21), Vector3(29, 0, 36))
	m._region("ARMORY", 28, Rect2(35, 28, 18, 16), Vector3(43, 0, 36))
	m._region("LABORATORY", 28, Rect2(17, 45, 18, 20), Vector3(26, 0, 52))
	m._region("ELEVATOR_LOBBY", 28, Rect2(17, 10, 18.4, 14), Vector3(30, 0, 18))
	m._region("EAST_CORRIDOR", 28, Rect2(18, 0, 9, 10), Vector3(23, 0, 4))
	m._region("CONTROL_CONNECTOR", 28, Rect2(7, 13, 10, 4), Vector3(12, 0, 15))
	m._region("WEST_CORRIDOR", 28, Rect2(-28, 0, 10, 10), Vector3(-23, 0, 4))
	m._region("WEST_SERVICE", 28, Rect2(-28, 10, 6, 26), Vector3(-25, 0, 30))
	m._region("WEST_FALLBACK", 28, Rect2(-22, 31, 19, 4), Vector3(-12, 0, 33))
	m._region(
		"BRIEFING_ROOM",
		27,
		Rect2(-7, 8, 14, 14),
		Vector3(3, 5.5, 18),
		"Briefing room above control; corner spiral stair.",
		true,
		"briefing"
	)
	m._region(
		"GENERALS_OFFICE",
		27,
		Rect2(7, 8, 12, 14),
		Vector3(16, 5.5, 17),
		"Commander office adjoining briefing room.",
		true,
		"office"
	)
	m._region("SECURITY_STATION", 27, Rect2(-19, 8, 12, 14), Vector3(-13, 5.5, 15))
	m._region("UPPER_CORRIDOR", 27, Rect2(19, 10, 8, 10), Vector3(23, 5.5, 15))
	m._region("UPPER_ELEVATOR_LOBBY", 27, Rect2(27, 10, 8.4, 16), Vector3(31, 5.5, 18))
	m._region("SERVICE_STAIRWELL", 27, Rect2(27, 26, 8.4, 14), Vector3(29, 5.5, 30))
	m._region("SUPPORT_LOBBY", 26, Rect2(27, 10, 8.4, 16), Vector3(31, 11, 18))
	m._region("SUPPORT_CORRIDOR", 26, Rect2(19, 10, 8, 16), Vector3(23, 11, 18))
	m._region("STAGING", 26, Rect2(7, 10, 12, 16), Vector3(14, 11, 18))
	m._region("STORAGE", 26, Rect2(7, 26, 20, 12), Vector3(15, 11, 32))
	m._region("SERVICE_ROOM", 26, Rect2(27, 26, 8.4, 14), Vector3(29, 11, 38))
	m.region(&"CONTROL_ROOM").floor_offset = CONTROL_FLOOR_Y
	m.region(&"CONTROL_ROOM").ceiling_height = 3.5
	m.region(&"GATE_ROOM").ceiling_height = 12.0
	m._region("GATE_EAST_ACCESS", 28, Rect2(12, 2.2, 6, 3.6), Vector3(15, 0, 4))
	m._region("GATE_WEST_ACCESS", 28, Rect2(-18, 2.2, 6, 3.6), Vector3(-15, 0, 4))
	m._link(
		"CONTROL_ROOM",
		"FALLBACK_HALLWAY",
		"stairs",
		PackedVector3Array([Vector3(0, 1.5, 22.2), Vector3(0, 0, 26)]),
		2.0
	)
	m._walk("FALLBACK_HALLWAY", "CONNECTOR_TUNNEL", Vector3(3, 0, 36), 5)
	m._walk("CONNECTOR_TUNNEL", "ROUND_HALLWAY", Vector3(17, 0, 36), 5)
	m._walk("ROUND_HALLWAY", "ARMORY", Vector3(35, 0, 36), 5)
	m._walk("ROUND_HALLWAY", "LABORATORY", Vector3(26, 0, 45), 4)
	m._walk("ELEVATOR_LOBBY", "ROUND_HALLWAY", Vector3(30, 0, 24), 5)
	m._walk("GATE_ROOM", "GATE_EAST_ACCESS", Vector3(12, 0, 4), 3.6, true)
	m._walk("GATE_EAST_ACCESS", "EAST_CORRIDOR", Vector3(18, 0, 4), 3.6)
	m._walk("EAST_CORRIDOR", "ELEVATOR_LOBBY", Vector3(23, 0, 10), 5)
	m._link(
		"CONTROL_ROOM",
		"CONTROL_CONNECTOR",
		"stairs",
		PackedVector3Array([Vector3(7.2, 1.5, 15), Vector3(12, 0, 15)]),
		2.0
	)
	m._walk("CONTROL_CONNECTOR", "ELEVATOR_LOBBY", Vector3(17, 0, 15), 5)
	m._walk("GATE_ROOM", "GATE_WEST_ACCESS", Vector3(-12, 0, 4), 3.6, true)
	m._walk("GATE_WEST_ACCESS", "WEST_CORRIDOR", Vector3(-18, 0, 4), 3.6)
	m._walk("WEST_CORRIDOR", "WEST_SERVICE", Vector3(-25, 0, 10), 5)
	m._walk("WEST_SERVICE", "WEST_FALLBACK", Vector3(-22, 0, 33), 5)
	m._walk("WEST_FALLBACK", "FALLBACK_HALLWAY", Vector3(-3, 0, 33), 5)
	m._walk("BRIEFING_ROOM", "GENERALS_OFFICE", Vector3(7, 5.5, 15), 3)
	m._walk("BRIEFING_ROOM", "SECURITY_STATION", Vector3(-7, 5.5, 15), 3)
	m._walk("GENERALS_OFFICE", "UPPER_CORRIDOR", Vector3(19, 5.5, 15), 3)
	m._walk("UPPER_CORRIDOR", "UPPER_ELEVATOR_LOBBY", Vector3(27, 5.5, 15), 5)
	m._walk("UPPER_ELEVATOR_LOBBY", "SERVICE_STAIRWELL", Vector3(29, 5.5, 26), 3)
	m._walk("SUPPORT_LOBBY", "SUPPORT_CORRIDOR", Vector3(27, 11, 18), 4)
	m._walk("SUPPORT_CORRIDOR", "STAGING", Vector3(19, 11, 18), 4)
	m._walk("STAGING", "STORAGE", Vector3(14, 11, 26), 4)
	m._walk("STORAGE", "SERVICE_ROOM", Vector3(27, 11, 32), 4)
	m._walk("SUPPORT_LOBBY", "SERVICE_ROOM", Vector3(31, 11, 26), 4)
	# Canon core stair stays in the control/briefing corner, with a full-width exit.
	var spiral := PackedVector3Array()
	for i in range(121):
		var t := float(i) / 120.0
		spiral.append(
			Vector3(
				-4.5 + cos(t * TAU * 1.25 + PI / 2.0) * 1.6,
				lerpf(CONTROL_FLOOR_Y, 5.5, t),
				12 + sin(t * TAU * 1.25 + PI / 2.0) * 1.6
			)
		)
	m._link("CONTROL_ROOM", "BRIEFING_ROOM", "spiral", spiral, 2.0)
	m._link(
		"ROUND_HALLWAY",
		"UPPER_CORRIDOR",
		"stairs",
		PackedVector3Array([Vector3(23, 0, 28), Vector3(23, 5.5, 20)]),
		3.0
	)
	m._link(
		"SERVICE_STAIRWELL",
		"SERVICE_ROOM",
		"stairs",
		PackedVector3Array([Vector3(32, 5.5, 26), Vector3(32, 11, 38)]),
		4.0
	)
	for pair: Array in [
		["ELEVATOR_LOBBY", "UPPER_ELEVATOR_LOBBY"], ["UPPER_ELEVATOR_LOBBY", "SUPPORT_LOBBY"]
	]:
		var a := m.region(pair[0])
		var b := m.region(pair[1])
		m._link(
			pair[0],
			pair[1],
			"lift",
			PackedVector3Array(
				[
					Vector3(34.7, FLOOR_HEIGHTS[a.floor_number], 18),
					Vector3(34.7, FLOOR_HEIGHTS[b.floor_number], 18)
				]
			),
			12.0
		)
	return m


func _style(id: StringName, description: String, color: Color) -> void:
	var s := SGCAssetStyle.new()
	s.id = id
	s.description = description
	s.palette = PackedColorArray([color])
	styles.append(s)


func _region(
	id: StringName,
	fl: int,
	rect: Rect2,
	anchor: Vector3,
	description: String = "Combat/support extension with clear passage and recessed cover.",
	canonical: bool = false,
	style: StringName = &"bunker"
) -> void:
	var r := SGCRegion.new()
	r.id = id
	r.floor_number = fl
	r.footprint = rect
	r.anchor = anchor
	r.description = description
	r.surface_style = style
	r.reference = REFERENCE if canonical else "Authored gameplay extension"
	r.confidence = "reference_relationship" if canonical else "gameplay_extension"
	regions.append(r)


func _walk(a: StringName, b: StringName, p: Vector3, width: float, door: bool = false) -> void:
	_link(a, b, "walk", PackedVector3Array([p]), 1.0)
	connections[-1].width = width
	connections[-1].door = door


func _link(
	a: StringName, b: StringName, kind: String, points: PackedVector3Array, cost: float
) -> void:
	var c := SGCConnection.new()
	c.id = StringName(str(a) + "__" + str(b))
	c.from_region = a
	c.to_region = b
	c.kind = kind
	c.points = points
	c.cost = cost
	connections.append(c)
