extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	var definition := map.definition
	assert(definition.validate().is_empty())
	assert(definition.FLOOR_HEIGHTS.keys() == [28, 27, 26])
	assert(definition.region(&"BRIEFING_ROOM").confidence == "reference_relationship")
	assert(definition.region(&"STAGING").confidence == "gameplay_extension")
	var blocked: Array[StringName] = [&"GATE_ROOM__GATE_EAST_ACCESS"]
	var route := definition.route(&"GATE_ROOM", &"ARMORY", blocked)
	assert(
		not route.is_empty() and route[0].to_region == &"GATE_WEST_ACCESS",
		"Fallback loop must route around blocked eastern exits"
	)
	var style_ids: Array[StringName] = []
	for style in definition.styles:
		style_ids.append(style.id)
		assert(not style.description.is_empty() and not style.reference.is_empty())
	for slot in definition.asset_slots:
		assert(
			slot.style_id in style_ids and slot.dimensions.x > 0 and not slot.description.is_empty()
		)
	# Art replacements must preserve gameplay collision and reject over-sized visuals.
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.2, 1)
	visual.mesh = box
	var scene := PackedScene.new()
	scene.pack(visual)
	visual.free()
	var body := map.get_node("STAGINGFloor") as StaticBody3D
	var collision: Shape3D = body.get_child(1).shape
	assert(map.replace_asset_visual(&"STAGINGFloor", scene))
	assert(body.get_child(1).shape == collision, "Art replacement must preserve collision")
	visual = MeshInstance3D.new()
	box = BoxMesh.new()
	box.size = Vector3(100, 100, 100)
	visual.mesh = box
	scene = PackedScene.new()
	scene.pack(visual)
	visual.free()
	assert(not map.replace_asset_visual(&"STAGINGFloor", scene), "Oversize art must be rejected")
	var actor := CharacterBody3D.new()
	room.add_child(actor)
	actor.position = Vector3(5, 0, 4)
	var nav := SGCNavigator.new(actor)
	assert(
		nav.next_position(Vector3(1000, 0, 1000)) == actor.position and nav.status == "unreachable",
		"Unknown goals must not produce direct wall-crossing movement"
	)
	print(
		"PASS source provenance, fallback routes, art metadata, visual bounds and unreachable destinations"
	)
	await preload("res://tests/support/finish.gd").success(self)
