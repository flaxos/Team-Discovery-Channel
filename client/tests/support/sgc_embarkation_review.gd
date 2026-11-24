extends SceneTree
## Real SGC UAT views and a fixed-camera comparison of the steel finish.

const SGC_SCENE := preload("res://scenes/main/SGCUATBase.tscn")

var room: GateRoom
var camera: Camera3D
var output_dir: String
var figures: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func warm_frames(count: int) -> void:
	for i in range(count):
		await process_frame


func capture(label: String, origin: Vector3, target: Vector3) -> void:
	camera.position = origin
	camera.look_at(target)
	await warm_frames(48)
	var gpu: Array[float] = []
	var viewport := root.get_viewport_rid()
	for i in range(45):
		await RenderingServer.frame_post_draw
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	gpu.sort()
	figures[label] = {
		"gpu_ms_median": gpu[gpu.size() >> 1],
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	}
	assert(root.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK)


func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	room = SGC_SCENE.instantiate() as GateRoom
	root.add_child(room)
	var map := room.get_node("SGCMap") as SGCMap
	await map.navigation_ready
	room.set_process(false)
	room.hud.hide()
	room.sector_shrouds.clear()
	for shroud: Node3D in room.get_node("SectorShrouds").get_children():
		shroud.hide()
	camera = Camera3D.new()
	camera.fov = 63
	room.add_child(camera)
	camera.make_current()
	output_dir = ProjectSettings.globalize_path("res://../build/asset-review/sprint13")
	DirAccess.make_dir_recursive_absolute(output_dir)

	var ramp := room.get_node("BunkerGeometry/GateRamp") as CSGBox3D
	var platform := room.get_node("BunkerGeometry/StargatePlatform") as CSGBox3D
	var steel := ramp.material as StandardMaterial3D
	var work_light := room.get_node("CeilingFloodlights/RampWorkLight") as SpotLight3D
	var pbr: Dictionary[MeshInstance3D, StandardMaterial3D] = {}
	for body: Node in map.get_children():
		if not body.has_meta("asset_slot"):
			continue
		var slot := body.get_meta("asset_slot") as SGCAssetSlot
		if slot.pbr_material == null:
			continue
		var visual := body.get_child(0) as MeshInstance3D
		pbr[visual] = visual.material_override as StandardMaterial3D
		visual.material_override = map.materials[slot.style_id]
	var previous := StandardMaterial3D.new()
	previous.albedo_color = Color(0.12, 0.13, 0.15)
	previous.metallic = 0.4
	previous.roughness = 0.5
	ramp.material = previous
	platform.material = previous
	work_light.hide()
	var wide := Vector3(6.65, 2.7, 6.9)
	var gate := Vector3(-1.0, 3.8, -14.8)
	await capture("before", wide, gate)
	for visual: MeshInstance3D in pbr:
		visual.material_override = pbr[visual]
	platform.material = steel
	ramp.material = steel
	await capture("pbr-original-lighting", wide, gate)
	work_light.show()
	await capture("normal", wide, gate)
	await capture("side-approach", Vector3(16, 1.7, 4.0), Vector3(-5, 2.1, -7.5))
	var near := Vector3(1.65, 1.82, -1.75)
	var tread := Vector3(0.15, 1.5, -5.4)
	await capture("steel-source", near, tread)
	var matte := steel.duplicate() as StandardMaterial3D
	matte.metallic = 0.0
	ramp.material = matte
	await capture("steel-matte", near, tread)
	ramp.material = steel

	var probe := ReflectionProbe.new()
	probe.position = Vector3(0, 5, -7)
	probe.size = Vector3(22, 10, 27)
	probe.interior = true
	probe.box_projection = true
	room.add_child(probe)
	await capture("steel-bounded-probe", near, tread)
	await capture("probe-wide", wide, gate)
	probe.queue_free()
	await process_frame

	room.set_emergency_lights(true)
	room._process(0.2)
	await capture("alarm", wide, gate)
	room.set_emergency_lights(false)
	room.stargate_mesh.sync_gate_snapshot(StargateRing.GateState.ACTIVE, StargateRing.GateDirection.INBOUND, 7, false)
	await capture("gate-active", wide, gate)

	var report := FileAccess.open(output_dir.path_join("visual-metrics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(figures, "\t") + "\n")
	print("Captured SGC embarkation materials and reflection comparison")
	await preload("res://tests/support/finish.gd").success(self)
