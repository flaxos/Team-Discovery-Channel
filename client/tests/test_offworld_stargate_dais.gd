extends SceneTree
## Fit the reusable gate on the live map, then walk both sides with the stock operative.

const SITE := preload("res://scenes/mission/GoauldInfiltrationMission.tscn")
const BARE_GATE := preload("res://scenes/props/Stargate.tscn")
const OFFWORLD_GATE := preload("res://scenes/props/OffworldStargate.tscn")
const DHD_BASE := preload("res://scenes/props/DHDConsole.tscn")
const PLAYER := preload("res://scenes/entities/Player.tscn")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var site := SITE.instantiate() as ModularMission
	root.add_child(site)
	if not site.is_started:
		await site.started
	assert(site.level.last_errors.is_empty() and site.setup_errors.is_empty())
	var gate := site.stargate_mesh
	var dais := gate.get_node(^"StoneDais") as StaticBody3D
	assert(site.dialing_console.target_stargate == gate)
	var lamp := check_console(site.dialing_console)
	var bare := BARE_GATE.instantiate() as StargateRing
	for path: NodePath in [^"ExtractionArea/CollisionShape3D", ^"KawooshArea/CollisionShape3D", ^"EventHorizon"]:
		assert(gate.get_node(path).transform == bare.get_node(path).transform)
	assert(not bare.has_node(^"StoneDais"))
	bare.free()
	var landing_height := check_threshold(gate, dais)

	var placed := OFFWORLD_GATE.instantiate() as StargateRing
	placed.position = Vector3(24, 6.5, -8)
	placed.rotation.y = PI / 2
	root.add_child(placed)
	var raised_base := placed.get_node(^"StoneDais") as StaticBody3D
	assert(raised_base.global_position.is_equal_approx(Vector3(24, 3, -8)))
	assert(raised_base.global_basis.is_equal_approx(placed.global_basis))
	assert(raised_base.get_node(^"WalkableSlope").shape == dais.get_node(^"WalkableSlope").shape)
	placed.free()

	var front := Vector3(0, 0, 5.15)
	var rear := Vector3(0, 0, -2.5)
	var landing := Vector3(0, landing_height, 0)
	for approach: Vector3 in [front, rear]:
		var route := site.level.local_path(dais.to_global(approach), dais.to_global(landing))
		assert(route.size() >= 2 and route[-1].distance_to(dais.to_global(landing)) < 0.3,
			"Both approaches reach the landing on the live navmesh")

	var operative := PLAYER.instantiate() as PlayerController3D
	operative.name = "1"
	operative.peer_id = 1
	operative.class_id = "oneill_recon"
	operative.position = site.players_container.to_local(dais.to_global(front + Vector3.UP * 0.05))
	operative.rotation.y = gate.global_rotation.y
	site.players_container.add_child(operative)
	await walk(operative, dais, landing_height, &"move_up", rear.z, -1.0)
	await walk(operative, dais, landing_height, &"move_down", front.z, 1.0)
	await cross_active_gate(operative, gate, lamp)
	site.queue_free()
	await process_frame
	print("PASS reusable offworld gate, unchanged gate anchors, and both walkable stone approaches")
	await preload("res://tests/support/finish.gd").success(self)


func check_console(console: DHDDialer) -> StandardMaterial3D:
	var base := DHD_BASE.instantiate() as DHDDialer
	var trigger_path := ^"InteractArea/CollisionShape3D"
	var native := base.get_node(trigger_path) as CollisionShape3D
	var installed := console.get_node(trigger_path) as CollisionShape3D
	assert(installed.transform == native.transform and installed.shape == native.shape)
	assert((base.get_node(^"BaseMesh") as MeshInstance3D).visible)
	base.free()
	assert(not (console.get_node(^"BaseMesh") as MeshInstance3D).visible)
	assert(not (console.get_node(^"DeckMesh") as MeshInstance3D).visible)
	var exterior := console.get_node(^"Exterior") as Node3D
	assert(exterior.find_children("*", "CollisionObject3D", true, false).is_empty())
	var allowed := console.get_meta("attachment_bounds") as AABB
	var meshes := exterior.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= 20)
	for mesh: MeshInstance3D in meshes:
		var relative := console.global_transform.affine_inverse() * mesh.global_transform
		assert(allowed.grow(0.001).encloses(relative * mesh.mesh.get_aabb()), str(mesh.name))
	var dome := exterior.get_node(^"Deck/Dome") as MeshInstance3D
	var lamp := dome.get_active_material(0) as StandardMaterial3D
	assert(is_equal_approx(lamp.emission_energy_multiplier, 0.24))
	return lamp


func check_threshold(gate: StargateRing, dais: StaticBody3D) -> float:
	var fallback := "--expect-gate-fallback" in OS.get_cmdline_user_args()
	var community := gate.get_node_or_null(^"CommunityVisual/gate_ring") as MeshInstance3D
	assert((community == null) == fallback)
	var rim := gate.get_node(^"GateRingMesh") as MeshInstance3D if fallback else community
	var rim_to_gate := gate.global_transform.affine_inverse() * rim.global_transform
	var ring_bottom := (rim_to_gate * rim.get_aabb()).position.y
	var horizon := gate.event_horizon_mesh
	var opening := horizon.transform * horizon.get_aabb()
	var slab := dais.get_node(^"Landing/ThresholdStone") as MeshInstance3D
	var slab_bounds := (dais.global_transform.affine_inverse() * slab.global_transform) * slab.get_aabb()
	var landing_height := opening.position.y - dais.position.y
	assert(is_equal_approx(slab_bounds.end.y, landing_height) and ring_bottom < opening.position.y,
		"The threshold stone reaches the horizon while the outer ring is embedded")
	var inner_lip := lower_inner_edge(rim, rim_to_gate)
	assert(absf(inner_lip - opening.position.y) < 0.01,
		"The visible inner ring meets the footpath at the centreline")
	var space := dais.get_world_3d().direct_space_state
	for z: float in [-0.4, 0.0, 0.4]:
		var point := Vector3(0, landing_height, z)
		var ray := PhysicsRayQueryParameters3D.create(
			dais.to_global(point + Vector3.UP * 0.3), dais.to_global(point - Vector3.UP * 0.3), 1)
		var hit := space.intersect_ray(ray)
		assert(hit.get("collider") == dais and hit.position.distance_to(dais.to_global(point)) < 0.005,
			"The solid footpath stays flush through the aperture")
	print("Threshold collision and slab y=", landing_height, " m, rim-to-horizon error=", absf(inner_lip - opening.position.y), " m")
	return landing_height


func lower_inner_edge(rim: MeshInstance3D, to_gate: Transform3D) -> float:
	# Slice the actual rim mesh along the walking centreline and keep the highest lower edge.
	var positions := rim.mesh.get_faces()
	var edge := -INF
	for first in range(0, positions.size(), 3):
		for side in range(3):
			var a := to_gate * positions[first + side]
			var b := to_gate * positions[first + (side + 1) % 3]
			if a.x * b.x <= 0.0 and not is_equal_approx(a.x, b.x):
				var hit := a.lerp(b, -a.x / (b.x - a.x))
				if hit.y < 0.0:
					edge = maxf(edge, hit.y)
	return edge


func walk(operative: PlayerController3D, dais: StaticBody3D, landing_height: float, action: StringName, goal_z: float, direction: float) -> void:
	Input.action_press(action)
	var crossed_on_foot := false
	for frame in range(180):
		await physics_frame
		var foot := dais.to_local(operative.global_position)
		if absf(foot.z) < 0.15:
			assert(operative.is_on_floor() and absf(foot.y - landing_height) < 0.02,
				"The operative crosses the ring plane while standing on the threshold")
			crossed_on_foot = true
		if direction * (foot.z - goal_z) > 0.0:
			break
	Input.action_release(action)
	var finish := dais.to_local(operative.global_position)
	assert(direction * (finish.z - goal_z) > 0.0 and absf(finish.y) < 0.05,
		"The operative crosses the full dais and returns to floor level")
	assert(crossed_on_foot)
	print("Dais traversal ", action, " crossed the aperture on foot, finish=", finish)


func cross_active_gate(operative: PlayerController3D, gate: StargateRing, lamp: StandardMaterial3D) -> void:
	var crossed := [false]
	gate.player_extracted.connect(func(body: Node) -> void: crossed[0] = body == operative)
	gate.kawoosh_duration_s = 0.08
	assert(gate.reserve_connection(false))
	await process_frame
	await process_frame
	assert(is_equal_approx(lamp.emission_energy_multiplier, 0.85))
	gate.authorize_extraction()
	for chevron in range(1, 8):
		gate.lock_chevron(chevron)
	await gate.wormhole_opened
	await process_frame
	await process_frame
	assert(is_equal_approx(lamp.emission_energy_multiplier, 2.1))
	Input.action_press(&"move_up")
	for frame in range(180):
		await physics_frame
		if crossed[0]:
			break
	Input.action_release(&"move_up")
	assert(crossed[0], "An operative walking up the dais reaches the active extraction area")
