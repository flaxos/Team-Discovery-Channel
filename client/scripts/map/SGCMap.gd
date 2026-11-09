class_name SGCMap
extends Node3D
## One authored topology drives modular geometry, AI and route tests.
signal navigation_ready
@export var definition: SGCMapDefinition
var navigation_map: RID
var nav_region: NavigationRegion3D
var ready_for_navigation: bool = false
var materials: Dictionary = {}
var passage_owners: Dictionary = {}
var overrun_stage: int = 0
var tactical_timer: float = 0.0
var room: Node3D


func _ready() -> void:
	room = get_parent()
	add_to_group("sgc_map")
	if definition == null:
		if (
			ResourceLoader.exists("res://resources/maps/sgc.tres")
			and "--bake-sgc" not in OS.get_cmdline_user_args()
		):
			definition = load("res://resources/maps/sgc.tres").duplicate(true) as SGCMapDefinition
		else:
			definition = SGCMapDefinition.create_default()
	assert(definition.validate().is_empty(), str(definition.validate()))
	for style in definition.styles:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = style.palette[0]
		mat.roughness = style.roughness
		mat.metallic = style.metallic
		if style.id == &"ceiling":
			var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
			img.fill(Color(0.42, 0.44, 0.45))
			for pixel in range(128):
				for seam in range(2):
					img.set_pixel(pixel, seam, Color(0.18, 0.20, 0.21))
					img.set_pixel(seam, pixel, Color(0.18, 0.20, 0.21))
			mat.albedo_texture = ImageTexture.create_from_image(img)
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		materials[style.id] = mat
	for r in definition.regions:
		_build_region(r)
	for c in definition.connections:
		if c.kind == "stairs":
			_build_stairs(c)
	_build_spiral()
	_build_cover()
	_build_guards()
	_build_control_front()
	_build_dressing()
	call_deferred("_bake_navigation")


func _box(
	label: String, at: Vector3, size: Vector3, style: StringName, solid: bool = true
) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = materials[style]
	body.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	var slot: SGCAssetSlot
	for existing in definition.asset_slots:
		if existing.id == StringName(label):
			slot = existing
			break
	if slot == null:
		slot = SGCAssetSlot.new()
		slot.id = StringName(label)
		slot.style_id = style
		slot.dimensions = size
		for spec in definition.styles:
			if spec.id == style:
				slot.description = spec.description
		definition.asset_slots.append(slot)
	body.set_meta("asset_slot", slot)
	if slot.texture != null:
		var material := materials[style].duplicate() as StandardMaterial3D
		material.albedo_texture = slot.texture
		mesh.material_override = material
	if slot.visual_scene != null:
		call_deferred("replace_asset_visual", slot.id, slot.visual_scene)

	return mesh


func _floor_rect(id: String, rect: Rect2, y: float, style: StringName) -> void:
	if rect.size.x <= 0.01 or rect.size.y <= 0.01:
		return
	_box(
		id,
		Vector3(rect.get_center().x, y - 0.15, rect.get_center().y),
		Vector3(rect.size.x, 0.3, rect.size.y),
		style
	)


func _floor_with_hole(r: SGCRegion, hole: Rect2) -> void:
	var rect := r.footprint
	var y: float = definition.floor_y(r)
	_floor_rect(
		str(r.id) + "FloorN",
		Rect2(rect.position, Vector2(rect.size.x, hole.position.y - rect.position.y)),
		y,
		r.surface_style
	)
	_floor_rect(
		str(r.id) + "FloorS",
		Rect2(Vector2(rect.position.x, hole.end.y), Vector2(rect.size.x, rect.end.y - hole.end.y)),
		y,
		r.surface_style
	)
	_floor_rect(
		str(r.id) + "FloorW",
		Rect2(
			Vector2(rect.position.x, hole.position.y),
			Vector2(hole.position.x - rect.position.x, hole.size.y)
		),
		y,
		r.surface_style
	)
	_floor_rect(
		str(r.id) + "FloorE",
		Rect2(Vector2(hole.end.x, hole.position.y), Vector2(rect.end.x - hole.end.x, hole.size.y)),
		y,
		r.surface_style
	)


func _build_region(r: SGCRegion) -> void:
	var y: float = definition.floor_y(r)
	if r.id == &"BRIEFING_ROOM":
		_floor_with_hole(r, Rect2(-6.9, 9.6, 4.8, 4.8))
		_floor_rect("SpiralTopLanding", Rect2(-6.8, 9.2, 1.4, 2.75), y, &"steel")
	elif r.id == &"FALLBACK_HALLWAY":
		_floor_with_hole(r, Rect2(-1.3, 22, 2.6, 4.1))
	elif r.id == &"CONTROL_CONNECTOR":
		_floor_with_hole(r, Rect2(7, 13.7, 5.1, 2.6))
	elif r.id == &"SERVICE_ROOM":
		_floor_with_hole(r, Rect2(30.6, 26, 2.8, 12.1))
	else:
		_floor_rect(
			str(r.id) + "Floor",
			r.footprint,
			y,
			&"floor" if r.floor_number == 28 else r.surface_style
		)
	for side in range(4):
		_wall(r, side)
	_build_ceiling(r)
	# Fixtures sit below the authored ceiling, independent of camera occlusion.
	var light := OmniLight3D.new()
	light.name = str(r.id) + "Light"
	light.position = r.anchor + Vector3(0, 3.3, 0)
	if r.id == &"GATE_ROOM":
		light.position.y = 10.5
		light.omni_range = 24.0
	light.light_energy = r.light_energy
	light.light_color = r.light_color
	light.omni_range = 24.0 if r.id == &"GATE_ROOM" else 10.0
	light.shadow_enabled = true
	add_child(light)
	if r.floor_number == 26:
		var alarm := OmniLight3D.new()
		alarm.name = str(r.id) + "Alarm"
		alarm.position = r.anchor + Vector3(0, 3.0, 0)
		alarm.light_color = Color(1.0, 0.12, 0.08)
		alarm.light_energy = 0.0
		alarm.omni_range = 10.0
		room.get_node("EmergencyLights").add_child(alarm)
	_box(
		str(r.id) + "LightFixture",
		light.position + Vector3(0, 0.15, 0),
		Vector3(1.8, 0.12, 0.5),
		&"steel",
		false
	)
	var sign := Label3D.new()
	sign.position = Vector3(r.footprint.get_center().x, y + 2.7, r.footprint.end.y - 0.25)
	sign.rotation.y = PI
	sign.double_sided = false
	sign.text = str(r.id).replace("_", " ") + " / " + str(r.floor_number)
	sign.font_size = 24
	sign.modulate = Color(0.6, 0.75, 0.78)
	add_child(sign)


func _wall(r: SGCRegion, side: int) -> void:
	var rect := r.footprint
	if r.id == &"GATE_ROOM" and side == 1:
		for x: float in [-9.5, 9.5]:
			_box("AtriumRearPier" + str(x), Vector3(x, 6, 8), Vector3(5, 12, 0.4), &"bunker")
		_box("AtriumRearHeader", Vector3(0, 10.65, 8), Vector3(14, 2.7, 0.4), &"bunker")
		return
	var along_x: bool = side < 2
	var fixed: float = (
		(rect.position.y if side == 0 else rect.end.y)
		if along_x
		else (rect.position.x if side == 2 else rect.end.x)
	)
	var lo: float = rect.position.x if along_x else rect.position.y
	var hi: float = rect.end.x if along_x else rect.end.y
	var openings: Array[Vector2] = []
	var y: float = definition.floor_y(r)
	for c in definition.connections:
		if c.from_region != r.id and c.to_region != r.id:
			continue
		if c.kind == "lift":
			continue
		for p in c.points:
			if absf(p.y - y) > 0.1:
				continue
			var cross: float = p.z if along_x else p.x
			var along: float = p.x if along_x else p.z
			if (
				absf(cross - fixed) < (0.3 if c.kind == "stairs" else 0.05)
				and along >= lo
				and along <= hi
			):
				openings.append(
					Vector2(maxf(lo, along - c.width / 2), minf(hi, along + c.width / 2))
				)
	# A sloping stair can cross a neighboring room boundary halfway up a flight.
	# Reserve the whole opening there, including headroom above the lower wall.
	var stair_openings: Array[Vector2] = []
	for c in definition.connections:
		if c.kind != "stairs":
			continue
		var a := c.points[0]
		var b := c.points[-1]
		var a_axis: float = a.z if along_x else a.x
		var b_axis: float = b.z if along_x else b.x
		if absf(b_axis - a_axis) < 0.01:
			continue
		if fixed < minf(a_axis, b_axis) - 0.3 or fixed > maxf(a_axis, b_axis) + 0.3:
			continue
		var t := (fixed - a_axis) / (b_axis - a_axis)
		var p := a.lerp(b, t)
		var along: float = p.x if along_x else p.z
		if along > lo and along < hi and p.y >= y - 0.1 and p.y <= y + 3.8:
			var gap := Vector2(along - 1.5, along + 1.5)
			openings.append(gap)
			stair_openings.append(gap)
	# Lift entrance is west of the cabin, never across its shaft.
	if r.id in [&"ELEVATOR_LOBBY", &"UPPER_ELEVATOR_LOBBY", &"SUPPORT_LOBBY"] and side == 3:
		openings.append(Vector2(16.5, 19.5))
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := lo
	for gap in openings:
		_wall_piece(r, side, fixed, cursor, gap.x, y, 0.0, 3.8)
		if not stair_openings.any(
			func(stair_gap: Vector2) -> bool: return stair_gap.x <= gap.y and stair_gap.y >= gap.x
		):
			_wall_piece(r, side, fixed, maxf(cursor, gap.x), gap.y, y, 2.8, 1.0)
		cursor = maxf(cursor, gap.y)
	_wall_piece(r, side, fixed, cursor, hi, y, 0.0, 3.8)


func _wall_piece(
	r: SGCRegion,
	side: int,
	fixed: float,
	lo: float,
	hi: float,
	y: float,
	bottom: float,
	height: float
) -> void:
	if hi - lo < 0.02:
		return
	# Gate atrium north-facing observation walls are retained from the scene.
	if r.id == &"CONTROL_ROOM" and side == 0:
		return
	if r.id == &"BRIEFING_ROOM" and side == 0:
		return
	if r.id == &"GATE_ROOM":
		height = r.ceiling_height - bottom
	var along_x := side < 2
	var at := (
		Vector3((lo + hi) / 2, y + bottom + height / 2, fixed)
		if along_x
		else Vector3(fixed, y + bottom + height / 2, (lo + hi) / 2)
	)
	var size := Vector3(hi - lo, height, 0.3) if along_x else Vector3(0.3, height, hi - lo)
	_box(str(r.id) + "Wall" + str(side) + "_" + str(lo) + "_" + str(bottom), at, size, &"bunker")


func _build_stairs(c: SGCConnection) -> void:
	var a := c.points[0]
	var b := c.points[-1]
	var delta := b - a
	var length := delta.length()
	var center := (a + b) / 2.0 - Vector3(0, 0.1, 0)
	var ramp := _box(str(c.id) + "WalkSurface", center, Vector3(2.4, 0.2, length + 0.2), &"steel")
	(ramp.get_parent() as Node3D).look_at(center + delta, Vector3.UP)
	for offset: float in [-1.3, 1.3]:
		var rail := _box(
			str(c.id) + "Rail" + str(offset),
			center + Vector3(-delta.z, 0, delta.x).normalized() * offset + Vector3(0, 0.65, 0),
			Vector3(0.10, 1.1, length + 0.2),
			&"steel"
		)
		(rail.get_parent() as Node3D).look_at(
			(rail.get_parent() as Node3D).position + delta, Vector3.UP
		)
	for i in range(35):
		var p := a.lerp(b, float(i) / 34.0)
		var tread := _box(
			str(c.id) + "Tread" + str(i),
			p - Vector3(0, 0.08, 0),
			Vector3(2.4, 0.12, Vector2(delta.x, delta.z).length() / 34 + 0.02),
			&"steel",
			false
		)
		(tread.get_parent() as Node3D).rotation.y = atan2(delta.x, delta.z)


func _build_spiral() -> void:
	var stair := load("res://scripts/world/SpiralStaircase.gd").new() as Node3D
	stair.name = "SpiralStairs"
	add_child(stair)


func _build_cover() -> void:
	for r in definition.regions:
		if (
			r.id
			not in [&"WEST_SERVICE", &"WEST_FALLBACK", &"EAST_CORRIDOR", &"STAGING", &"STORAGE"]
		):
			continue
		var pos := Vector3(
			r.footprint.position.x + 1.2, definition.floor_y(r) + 0.5, r.footprint.position.y + 2
		)
		if r.id == &"WEST_FALLBACK":
			pos = Vector3(-12, definition.floor_y(r) + 0.5, 32.0)
		var cover := _box(str(r.id) + "Cover", pos, Vector3(1.6, 1, 1), &"steel")
		cover.get_parent().add_to_group("cover")


func _bake_navigation() -> void:
	if not is_inside_tree():
		return
	# Bake the actual modular collision, stairs and retained gameplay props together.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.6
	mesh.agent_height = 1.9
	mesh.agent_max_climb = 0.2
	mesh.agent_max_slope = 42.0
	mesh.cell_size = 0.15
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	if (
		ResourceLoader.exists("res://resources/maps/sgc_navigation.res")
		and "--bake-sgc" not in OS.get_cmdline_user_args()
	):
		mesh = load("res://resources/maps/sgc_navigation.res") as NavigationMesh
	else:
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, source, room)
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)

	navigation_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(navigation_map, true)
	NavigationServer3D.map_set_cell_size(navigation_map, mesh.cell_size)
	nav_region.navigation_mesh = mesh
	nav_region.set_navigation_map(navigation_map)
	add_child(nav_region)
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	while NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	ready_for_navigation = true
	navigation_ready.emit()


func local_path(start: Vector3, goal: Vector3) -> PackedVector3Array:
	if not ready_for_navigation:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(navigation_map, start, goal, true)


func claim_passage(id: StringName, actor: Node) -> bool:
	var owner: WeakRef = passage_owners.get(id)
	if owner != null and owner.get_ref() != null and owner.get_ref() != actor:
		return false
	passage_owners[id] = weakref(actor)
	return true


func release_passage(id: StringName, actor: Node) -> void:
	var owner: WeakRef = passage_owners.get(id)
	if owner != null and owner.get_ref() == actor:
		passage_owners.erase(id)


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	tactical_timer += delta
	if tactical_timer < 1.0:
		return
	tactical_timer = 0.0
	var enemies := room.get_node_or_null("Enemies")
	if enemies == null:
		return
	var count := 0
	for enemy in enemies.get_children():
		if (
			enemy is JaffaAI
			and enemy.current_state != JaffaAI.State.DEAD
			and enemy.global_position.z > 8
		):
			count += 1
	var stage := mini(2, count / 3)
	if stage <= overrun_stage:
		return
	overrun_stage = stage
	var destination := definition.region(&"BRIEFING_ROOM" if stage == 1 else &"STAGING").anchor
	for ally in get_tree().get_nodes_in_group("sgc_airmen"):
		if (
			ally is SGCAirmanAI
			and (
				ally.current_state
				not in [
					SGCAirmanAI.State.DEAD,
					SGCAirmanAI.State.DOWNED,
					SGCAirmanAI.State.REVIVE_PLAYER
				]
			)
		):
			ally.order_move_to(destination + Vector3(float(ally.get_index()) * 1.2, 0, 0))


func _exit_tree() -> void:
	if navigation_map.is_valid():
		NavigationServer3D.free_rid(navigation_map)


func _build_guards() -> void:
	_box("ShaftEast", Vector3(39, 6.5, 18), Vector3(0.3, 15, 4.4), &"bunker")
	_box("ShaftNorth", Vector3(37, 6.5, 15.95), Vector3(4, 15, 0.3), &"bunker")
	_box("ShaftSouth", Vector3(37, 6.5, 20.05), Vector3(4, 15, 0.3), &"bunker")
	for x: float in [30.5, 33.5]:
		_box("ServiceHoleGuard" + str(x), Vector3(x, 11.55, 32), Vector3(0.10, 1.1, 12.1), &"steel")
	_box("ServiceHoleNorthGuard", Vector3(32, 11.55, 26), Vector3(2.8, 1.1, 0.1), &"steel")
	_box("SpiralHoleWestGuard", Vector3(-6.9, 6.05, 12), Vector3(0.1, 1.1, 4.8), &"steel")
	_box("SpiralHoleSouthGuard", Vector3(-4.5, 6.05, 14.4), Vector3(4.8, 1.1, 0.1), &"steel")
	_box("SpiralTopLandingGuard", Vector3(-5.3, 6.05, 11.0), Vector3(0.1, 1.1, 2.0), &"steel")
	_box("SpiralHoleEastGuard", Vector3(-2.1, 6.05, 12), Vector3(0.1, 1.1, 4.8), &"steel")


func replace_asset_visual(slot_id: StringName, scene: PackedScene) -> bool:
	var body := get_node_or_null(NodePath(slot_id)) as StaticBody3D
	if body == null or scene == null:
		return false
	var slot := body.get_meta("asset_slot") as SGCAssetSlot
	var replacement := scene.instantiate() as Node3D
	if replacement == null:
		return false
	body.add_child(replacement)
	if replacement is CollisionObject3D:
		replacement.collision_layer = 0
		replacement.collision_mask = 0
	var bounds := AABB()
	var has_mesh := false
	for node: Node in replacement.find_children("*", "", true, false):
		if node is CollisionObject3D:
			node.collision_layer = 0
			node.collision_mask = 0
		if node is MeshInstance3D:
			var local_bounds: AABB = (
				(body.global_transform.affine_inverse() * node.global_transform) * node.get_aabb()
			)
			bounds = bounds.merge(local_bounds) if has_mesh else local_bounds
			has_mesh = true
	if replacement is MeshInstance3D:
		bounds = replacement.transform * replacement.get_aabb()
		has_mesh = true
	var envelope := AABB(-slot.dimensions / 2.0, slot.dimensions).grow(0.02)
	if not has_mesh or not envelope.encloses(bounds):
		replacement.free()
		return false
	var previous := body.get_node_or_null("ReplacementVisual")
	if previous != null:
		previous.free()
	replacement.name = "ReplacementVisual"
	(body.get_child(0) as MeshInstance3D).hide()
	slot.visual_scene = scene
	slot.replacement_status = "replaced"
	return true


func _build_dressing() -> void:
	# Keep dressing against the outer walls, away from authored portals and tactical anchors.
	for r in definition.regions:
		var y: float = definition.floor_y(r)
		var edge := r.footprint.position
		_box(
			str(r.id) + "ServiceConduit",
			Vector3(edge.x + 0.35, y + 3.1, r.footprint.get_center().y),
			Vector3(0.12, 0.12, r.footprint.size.y - 1.0),
			&"steel",
			false
		)
		if r.id == &"STORAGE":
			for i in range(4):
				_box(
					"SupplyRack" + str(i),
					Vector3(8.2, y + 0.9, 28.2 + i * 2.5),
					Vector3(1.4, 1.8, 1.5),
					&"steel"
				)
		elif r.id == &"STAGING":
			for i in range(2):
				_box(
					"StagingBench" + str(i),
					Vector3(10 + i * 5, y + 0.35, 24.7),
					Vector3(3.5, 0.7, 0.6),
					&"steel"
				)
		elif r.id == &"SERVICE_ROOM":
			_box("ServiceCabinet", Vector3(28, y + 1.0, 28.5), Vector3(1.2, 2.0, 1.2), &"steel")


func _build_ceiling(r: SGCRegion) -> void:
	var y := definition.floor_y(r) + r.ceiling_height
	var rect := r.footprint
	var hole := Rect2()
	if r.id == &"CONTROL_ROOM":
		hole = Rect2(-6.9, 9.6, 4.8, 5.4)
	elif r.id in [&"ELEVATOR_LOBBY", &"ROUND_HALLWAY"]:
		hole = rect.intersection(Rect2(21.4, 19.6, 3.2, 9.0))
	elif r.id == &"SERVICE_STAIRWELL":
		hole = Rect2(30.4, 26, 3.2, 12.4)
	if hole.has_area():
		_ceiling_panel(
			str(r.id) + "CeilingN",
			Rect2(rect.position, Vector2(rect.size.x, hole.position.y - rect.position.y)),
			y
		)
		_ceiling_panel(
			str(r.id) + "CeilingS",
			Rect2(
				Vector2(rect.position.x, hole.end.y), Vector2(rect.size.x, rect.end.y - hole.end.y)
			),
			y
		)
		_ceiling_panel(
			str(r.id) + "CeilingW",
			Rect2(
				Vector2(rect.position.x, hole.position.y),
				Vector2(hole.position.x - rect.position.x, hole.size.y)
			),
			y
		)
		_ceiling_panel(
			str(r.id) + "CeilingE",
			Rect2(
				Vector2(hole.end.x, hole.position.y), Vector2(rect.end.x - hole.end.x, hole.size.y)
			),
			y
		)
	else:
		_ceiling_panel(str(r.id) + "Ceiling", rect, y)


func _ceiling_panel(label: String, rect: Rect2, y: float) -> void:
	if rect.size.x < 0.01 or rect.size.y < 0.01:
		return
	var mesh := _box(
		label,
		Vector3(rect.get_center().x, y + 0.12, rect.get_center().y),
		Vector3(rect.size.x, 0.24, rect.size.y),
		&"ceiling",
		false
	)
	var body := mesh.get_parent() as StaticBody3D
	body.add_to_group("sgc_ceiling")
	body.collision_layer = 128
	# Downward-facing collision prevents roofs becoming walkable navigation islands.
	var a := Vector3(-rect.size.x / 2, -0.12, -rect.size.y / 2)
	var b := Vector3(rect.size.x / 2, -0.12, -rect.size.y / 2)
	var c := Vector3(-rect.size.x / 2, -0.12, rect.size.y / 2)
	var d := Vector3(rect.size.x / 2, -0.12, rect.size.y / 2)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([a, b, c, b, d, c]))
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	# Visible underside ribs communicate the bunker/silo structure at human scale.
	for index in range(int(rect.size.y / 4)):
		_box(
			label + "Beam" + str(index),
			Vector3(rect.get_center().x, y - 0.09, rect.position.y + 2 + index * 4),
			Vector3(rect.size.x, 0.18, 0.18),
			&"steel",
			false
		)


func _build_control_front() -> void:
	_box("ControlFrontBase", Vector3(0, 1.1, 7.8), Vector3(14, 2.2, 0.4), &"bunker")
	_box("ControlFrontHeader", Vector3(0, 4.95, 7.8), Vector3(14, 0.7, 0.4), &"bunker")
	for x: float in [-6.5, 6.5]:
		_box("ControlWindowPost" + str(x), Vector3(x, 3.4, 7.8), Vector3(1, 2.4, 0.4), &"steel")
	# Deep roof and overhead reinforced shaft cover, consistent with the former silo shell.
	_box("SiloRoofHatch", Vector3(0, 11.9, -15), Vector3(9, 0.2, 9), &"steel", false)
	for z: float in [-18, -10, -2, 6]:
		_box(
			"SiloOverheadBeam" + str(z),
			Vector3(0, 11.6, z),
			Vector3(24, 0.6, 0.45),
			&"steel",
			false
		)
