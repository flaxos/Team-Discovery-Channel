extends SceneTree
## Actual native-compound movement. Roofs are hidden only for this cutaway overview.
const Encounter = preload("res://tests/support/modular_flank_encounter.gd")
var output: String
var follower: JaffaAI
var observed := PackedVector3Array()
var actual: MeshInstance3D
var legend: Label


func _init() -> void:
	call_deferred("run")


func record() -> void:
	if is_instance_valid(follower) and (observed.is_empty() or observed[-1].distance_to(follower.global_position) > 0.15):
		observed.append(follower.global_position)


func line(points: PackedVector3Array, colour: Color, priority: int = 0) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	if points.size() < 2:
		return mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = priority
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point in points:
		mesh.surface_add_vertex(point + Vector3.UP * 0.4)
	mesh.surface_end()
	return mesh


func shot(label: String) -> void:
	actual.mesh = line(observed, Color(1.0, 0.5, 0.1), 1)
	for i in range(10):
		await physics_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)


func tuples(points: PackedVector3Array) -> Array:
	var result: Array = []
	for point in points:
		result.append([point.x, point.y, point.z])
	return result


func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/modular-flanking-review")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 1000)
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var main := load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room: ModularMission
	for i in range(1800):
		await physics_frame
		room = main.current_gate_room as ModularMission
		if room != null and room.is_started:
			break
	assert(room != null and room.is_started)
	room.alert.set_physics_process(false)
	for guard: JaffaAI in room.enemies.get_children():
		guard.stand_down()
	var encounter := await Encounter.choose(room)
	assert(not encounter.is_empty())
	var player := room.players_container.get_node("1") as PlayerController3D
	player.set_physics_process(false)
	player.health_component.frozen = true
	player.global_position = encounter.known + Vector3.UP * 0.05
	var guards := Encounter.spawn(room, encounter)
	follower = guards[1]
	for i in range(1200):
		if follower.is_tactical_flanking:
			break
		await physics_frame
	assert(follower.is_tactical_flanking)
	follower.set_physics_process(false)
	physics_frame.connect(record)
	var planned := follower._flank_navigation.points.duplicate()
	room.hud.hide()
	for item in room.level.layout.instances:
		for mesh in room.level.get_node(str(item.id) + "/Visuals").get_children():
			if str(mesh.name).begins_with("Roof"):
				(mesh as Node3D).hide()
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 90.0
	camera.global_position = Vector3(-4, 110, 36)
	camera.look_at(Vector3(-4, 0, 36), Vector3.FORWARD)
	camera.current = true
	var plan := MeshInstance3D.new()
	plan.mesh = line(planned, Color(0.1, 0.9, 1.0))
	room.add_child(plan)
	actual = MeshInstance3D.new()
	room.add_child(actual)
	var overlay := CanvasLayer.new()
	room.add_child(overlay)
	legend = Label.new()
	legend.position = Vector2(24, 20)
	legend.add_theme_font_size_override("font_size", 22)
	legend.add_theme_color_override("font_outline_color", Color.BLACK)
	legend.add_theme_constant_override("outline_size", 6)
	legend.text = "SPRINT 4 — MODULAR FLANKING / CUTAWAY REVIEW\nCyan: planned alternate entrance | Orange: observed host movement\nStart: %s | Last sighting: %s | Leads retain their position" % [encounter.rooms[0], encounter.rooms[-1]]
	overlay.add_child(legend)
	await shot("1-plan")
	follower.set_physics_process(true)
	for i in range(1800):
		if follower._flank_time > 6.0:
			break
		await physics_frame
	await shot("2-mid-route")
	for i in range(1800):
		if not follower.is_tactical_flanking:
			break
		await physics_frame
	assert(follower.flank_status == "arrived", follower.flank_status)
	for guard in guards:
		guard.set_physics_process(false)
	record()
	legend.text += "\nCompleted at the other entrance in %.2f simulated seconds" % follower._flank_time
	await shot("3-arrived")
	var data := {"layout": room.definition.layout.resource_path, "rooms": Array(encounter.rooms),
		"last_seen": tuples(PackedVector3Array([encounter.known])), "planned": tuples(planned),
		"observed": tuples(observed), "simulated_seconds": follower._flank_time, "outcome": follower.flank_status}
	FileAccess.open(output.path_join("trajectory.json"), FileAccess.WRITE).store_string(JSON.stringify(data, "\t"))
	physics_frame.disconnect(record)
	net.disconnect_game()
	for i in range(4):
		await physics_frame
	print("PASS modular flank rendered trajectory review: ", output)
	await preload("res://tests/support/finish.gd").success(self)
