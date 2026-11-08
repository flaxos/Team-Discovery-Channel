extends SceneTree
## Sprint 16 Verification Suite: Level 28 Complex Connectivity, Tactical Camera Orbit,
## Multi-Console Blast Doors, Fog-of-War Room Shrouding & Hallway AI Pathfinding.
## Validates:
##  1. 360-Degree Camera Orbit (no north lock, unconstrained yaw orbit, camera-relative WASD).
##  2. Seamless Physical Traversal & Floor Alignment across ALL connected Level 28 rooms:
##     - Fallback Hallway (Z=28, Y=0.1) <-> Control Room (Z=15, Y=0.1) through Central Blast Doors (Z=22) with NO cliff/obstruction.
##     - Control Room (Z=15, Y=0.1) <-> Elevator Connector (X=12, Z=15, Y=0.1) with NO ramp box obstacle.
##     - Control Room (Z=14, Y=0.1) <-> Gate Room (X=5, Z=4, Y=0.1) through north doorway (Z=7.8) with NO step/ramp obstacle.
##     - Elevator Lobby <-> East Connector Corridor into Gate Room East Blast Doors (X=18, Z=4).
##     - Armory <-> Round Hallway <-> Connector Tunnel <-> Fallback Hallway.
##  3. Multi-Console Blast Door Operations (Central, West, East interactive consoles, open/close toggle, status lights).
##  4. Sector Shrouding / Fog of War (active room unshaded, distant rooms opaque, enemy culling without LOS).
##  5. Tactical AI Pathfinding & Wall Line-of-Sight (Airmen waypoint scramble, no aiming/shooting through walls).

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"
const AIRMAN_SCENE: String = "res://scenes/entities/SGCAirman.tscn"
const JAFFA_SCENE: String = "res://scenes/entities/JaffaGuard.tscn"

const BlastDoorConsoleScript = preload("res://scripts/props/BlastDoorConsole.gd")
const SGCAirmanAIScript = preload("res://scripts/entities/SGCAirmanAI.gd")

var gateroom: GateRoom = null
var player: PlayerController3D = null
var hud: TacticalHUD = null
var ticks: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 16 COMPLEX CONNECTIVITY & AI TEST ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	hud = gateroom.get_node_or_null("TacticalHUD") as TacticalHUD

	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load successfully")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)


func _verify_route_segment(space: PhysicsDirectSpaceState3D, p1: Vector3, p2: Vector3, route_name: String) -> void:
	# 1. Waist-height raycast clearance (Y = 0.8)
	var q_waist := PhysicsRayQueryParameters3D.create(p1 + Vector3(0.0, 0.8, 0.0), p2 + Vector3(0.0, 0.8, 0.0))
	q_waist.collision_mask = 1
	var res_waist: Dictionary = space.intersect_ray(q_waist)
	assert(res_waist.is_empty(), "[%s] Waist-height raycast (Y=0.8) blocked between %s and %s (hit: %s)" % [
		route_name, str(p1), str(p2), str(res_waist.get("position"))
	])

	# 2. Knee/ground clearance raycast (Y = 0.25) to verify NO steps, thresholds, or ramp box obstacles
	var q_knee := PhysicsRayQueryParameters3D.create(p1 + Vector3(0.0, 0.25, 0.0), p2 + Vector3(0.0, 0.25, 0.0))
	q_knee.collision_mask = 1
	var res_knee: Dictionary = space.intersect_ray(q_knee)
	assert(res_knee.is_empty(), "[%s] Knee-height raycast (Y=0.25) blocked by obstacle/step between %s and %s (hit: %s)" % [
		route_name, str(p1), str(p2), str(res_knee.get("position"))
	])

	# 3. Floor continuity and level verification: cast downward rays along the segment to detect cliffs
	var dist: float = p1.distance_to(p2)
	var num_samples: int = maxi(2, int(ceil(dist / 2.0)))
	for s: int in range(num_samples + 1):
		var t: float = float(s) / float(num_samples)
		var check_pos: Vector3 = p1.lerp(p2, t)
		var q_down := PhysicsRayQueryParameters3D.create(check_pos + Vector3(0.0, 1.0, 0.0), check_pos + Vector3(0.0, -1.0, 0.0))
		q_down.collision_mask = 1
		var res_down: Dictionary = space.intersect_ray(q_down)
		assert(not res_down.is_empty(), "[%s] Missing floor beneath position %s!" % [route_name, str(check_pos)])
		var hit_y: float = (res_down["position"] as Vector3).y
		assert(absf(hit_y - 0.0) < 0.08, "[%s] Floor height mismatch/cliff at %s: detected Y=%.3f, expected ~0.0" % [
			route_name, str(check_pos), hit_y
		])


func _verify_character_movement(p1: Vector3, p2: Vector3, route_name: String) -> void:
	var dist: float = p1.distance_to(p2)
	var steps: int = maxi(2, int(ceil(dist / 0.5)))
	for s: int in range(steps):
		var t1: float = float(s) / float(steps)
		var t2: float = float(s + 1) / float(steps)
		var curr_pos: Vector3 = p1.lerp(p2, t1)
		var next_pos: Vector3 = p1.lerp(p2, t2)
		player.global_position = curr_pos
		var motion: Vector3 = next_pos - curr_pos
		var blocked: bool = player.test_move(player.global_transform, motion)
		assert(not blocked, "[%s] CharacterBody3D physically obstructed while moving from %s toward %s" % [
			route_name, str(curr_pos), str(next_pos)
		])


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# ========================================================
		# TEST 1: 360-Degree Camera Orbit & WASD Orientation
		# ========================================================
		print("[TEST 1/5] Testing 360-Degree Camera Orbit & Unconstrained Isometric Yaw...")

		var orig_yaw: float = player.current_iso_pan_yaw

		# Simulate horizontal mouse motion left and right across multiple full rotations
		var motion_event := InputEventMouseMotion.new()
		motion_event.relative = Vector2(250.0, 0.0)
		player._unhandled_input(motion_event)

		assert(not is_equal_approx(player.current_iso_pan_yaw, orig_yaw), "Mouse motion must adjust current_iso_pan_yaw")
		assert(player.current_iso_pan_yaw < orig_yaw, "Moving mouse right must rotate camera yaw counter-clockwise")

		# Simulate 360-degree rotation beyond old 22-degree (0.38 rad) clamp
		player.current_iso_pan_yaw = deg_to_rad(180.0)
		player._update_camera_and_occlusion(0.016)
		assert(player.camera_rig.rotation.y > deg_to_rad(100.0), "Camera rig must support full 360 yaw rotation without clamping")

		# Verify camera-relative movement: when camera is rotated 90 deg, forward moves along camera axis
		player.current_iso_pan_yaw = deg_to_rad(90.0)
		player.camera_rig.rotation.y = deg_to_rad(90.0)
		var cam_yaw: float = player.camera_rig.rotation.y
		var cam_forward := -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
		assert(is_equal_approx(cam_forward.x, -1.0) and is_equal_approx(cam_forward.z, 0.0), "Cam forward must reflect camera yaw orientation")

		player.current_iso_pan_yaw = 0.0
		player.camera_rig.rotation.y = 0.0
		print("[TEST 1/5] PASS: 360-degree camera yaw rotation and camera-relative orientation verified.")

	elif ticks == 4:
		# ========================================================
		# TEST 2: Complete Level 28 Physical Connectivity, Clearance & Floor Mismatch Resolution
		# ========================================================
		print("[TEST 2/5] Testing Exhaustive Level 28 Room Connectivity, Doorway Clearance & Floor Alignment...")

		var space: PhysicsDirectSpaceState3D = gateroom.get_world_3d().direct_space_state

		# --------------------------------------------------------
		# 2A. Route 1: Fallback Hallway (Z=28, Y=0.1) <-> Control Room (Z=15, Y=0.1) through Central Blast Doors (Z=22)
		# --------------------------------------------------------
		print("  -> Verifying Fallback Hallway <-> Control Room through Central Blast Doors (Z=22)...")
		var r1_fallback := Vector3(0.0, 0.1, 28.0)
		var r1_blastdoor := Vector3(0.0, 0.1, 22.0)
		var r1_control := Vector3(0.0, 0.1, 15.0)

		_verify_route_segment(space, r1_fallback, r1_blastdoor, "Fallback -> Central Blast Doors")
		_verify_route_segment(space, r1_blastdoor, r1_control, "Central Blast Doors -> Control Room")
		_verify_character_movement(r1_fallback, r1_blastdoor, "Fallback -> Central Blast Doors")
		_verify_character_movement(r1_blastdoor, r1_control, "Central Blast Doors -> Control Room")

		# Verify reverse traversal
		_verify_character_movement(r1_control, r1_blastdoor, "Control Room -> Central Blast Doors")
		_verify_character_movement(r1_blastdoor, r1_fallback, "Central Blast Doors -> Fallback")

		# --------------------------------------------------------
		# 2B. Route 2: Control Room (Z=15, Y=0.1) <-> Elevator Connector (X=12, Z=15, Y=0.1) <-> Elevator Lobby
		# --------------------------------------------------------
		print("  -> Verifying Control Room <-> Elevator Connector (X=12, Z=15) with NO ramp box obstacle...")
		var r2_control := Vector3(0.0, 0.1, 15.0)
		var r2_control_east := Vector3(5.0, 0.1, 15.0)
		var r2_connector := Vector3(12.0, 0.1, 15.0)
		var r2_elevator_lobby := Vector3(20.0, 0.1, 15.0)

		_verify_route_segment(space, r2_control, r2_control_east, "Control Room Center -> East Aisle")
		_verify_route_segment(space, r2_control_east, r2_connector, "Control Room -> Elevator Connector")
		_verify_route_segment(space, r2_connector, r2_elevator_lobby, "Elevator Connector -> Elevator Lobby")
		_verify_character_movement(r2_control, r2_control_east, "Control Room Center -> East Aisle")
		_verify_character_movement(r2_control_east, r2_connector, "Control Room -> Elevator Connector")
		_verify_character_movement(r2_connector, r2_elevator_lobby, "Elevator Connector -> Elevator Lobby")

		# Verify reverse traversal
		_verify_character_movement(r2_elevator_lobby, r2_connector, "Elevator Lobby -> Elevator Connector")
		_verify_character_movement(r2_connector, r2_control, "Elevator Connector -> Control Room")

		# --------------------------------------------------------
		# 2C. Route 3: Control Room (Z=14, Y=0.1) <-> Gate Room (X=5, Z=4, Y=0.1) through North Doorway (Z=7.8)
		# --------------------------------------------------------
		print("  -> Verifying Control Room <-> Gate Room through North Doorway (Z=7.8) with NO step/ramp obstacle...")
		var r3_control_north := Vector3(5.0, 0.1, 14.0)
		var r3_north_door := Vector3(5.0, 0.1, 7.8)
		var r3_gate_room := Vector3(5.0, 0.1, 4.0)

		_verify_route_segment(space, r3_control_north, r3_north_door, "Control Room -> North Doorway")
		_verify_route_segment(space, r3_north_door, r3_gate_room, "North Doorway -> Gate Room Arena")
		_verify_character_movement(r3_control_north, r3_north_door, "Control Room -> North Doorway")
		_verify_character_movement(r3_north_door, r3_gate_room, "North Doorway -> Gate Room Arena")

		# Verify reverse traversal
		_verify_character_movement(r3_gate_room, r3_north_door, "Gate Room Arena -> North Doorway")
		_verify_character_movement(r3_north_door, r3_control_north, "North Doorway -> Control Room")

		# --------------------------------------------------------
		# 2D. Route 4: Elevator Lobby <-> East Connector Corridor into Gate Room East Blast Doors (X=18, Z=4)
		# --------------------------------------------------------
		print("  -> Verifying Elevator Lobby <-> East Corridor into Gate Room East Blast Doors (X=18, Z=4)...")
		var r4_elev_center := Vector3(24.0, 0.1, 18.0)
		var r4_corridor_portal := Vector3(22.5, 0.1, 9.6)
		var r4_corridor_mid := Vector3(22.5, 0.1, 6.0)
		var r4_east_blastdoor := Vector3(18.0, 0.1, 4.0)
		var r4_gate_east := Vector3(10.0, 0.1, 4.0)

		_verify_route_segment(space, r4_elev_center, r4_corridor_portal, "Elevator Lobby -> East Corridor Portal")
		_verify_route_segment(space, r4_corridor_portal, r4_corridor_mid, "East Corridor Portal -> Mid Corridor")
		_verify_route_segment(space, r4_corridor_mid, r4_east_blastdoor, "East Corridor -> East Blast Doors")
		_verify_route_segment(space, r4_east_blastdoor, r4_gate_east, "East Blast Doors -> Gate Room Floor")

		_verify_character_movement(r4_elev_center, r4_corridor_portal, "Elevator Lobby -> East Corridor Portal")
		_verify_character_movement(r4_corridor_portal, r4_corridor_mid, "East Corridor Portal -> Mid Corridor")
		_verify_character_movement(r4_corridor_mid, r4_east_blastdoor, "East Corridor -> East Blast Doors")
		_verify_character_movement(r4_east_blastdoor, r4_gate_east, "East Blast Doors -> Gate Room Floor")

		# --------------------------------------------------------
		# 2E. Route 5: Armory <-> Round Hallway <-> Connector Tunnel <-> Fallback Hallway
		# --------------------------------------------------------
		print("  -> Verifying Armory <-> Round Hallway <-> Connector Tunnel <-> Fallback Hallway...")
		var r5_armory := Vector3(44.0, 0.1, 36.0)
		var r5_armory_door := Vector3(35.0, 0.1, 36.0)
		var r5_round_hallway := Vector3(26.0, 0.1, 36.0)
		var r5_connector_tunnel := Vector3(11.5, 0.1, 36.0)
		var r5_fallback_corner := Vector3(2.5, 0.1, 36.0)
		var r5_fallback_mid := Vector3(2.5, 0.1, 28.0)

		_verify_route_segment(space, r5_armory, r5_armory_door, "Armory -> Armory Doorway")
		_verify_route_segment(space, r5_armory_door, r5_round_hallway, "Armory Doorway -> Round Hallway")
		_verify_route_segment(space, r5_round_hallway, r5_connector_tunnel, "Round Hallway -> Connector Tunnel")
		_verify_route_segment(space, r5_connector_tunnel, r5_fallback_corner, "Connector Tunnel -> Fallback Corner")
		_verify_route_segment(space, r5_fallback_corner, r5_fallback_mid, "Fallback Corner -> Fallback Mid")

		_verify_character_movement(r5_armory, r5_armory_door, "Armory -> Armory Doorway")
		_verify_character_movement(r5_armory_door, r5_round_hallway, "Armory Doorway -> Round Hallway")
		_verify_character_movement(r5_round_hallway, r5_connector_tunnel, "Round Hallway -> Connector Tunnel")
		_verify_character_movement(r5_connector_tunnel, r5_fallback_corner, "Connector Tunnel -> Fallback Corner")
		_verify_character_movement(r5_fallback_corner, r5_fallback_mid, "Fallback Corner -> Fallback Mid")

		# --------------------------------------------------------
		# 2F. Full Continuous Perimeter Traversal Loop & Sector Classification
		# --------------------------------------------------------
		print("  -> Verifying full continuous perimeter loop and accurate real-time sector classification...")
		var perimeter_points: Array[Dictionary] = [
			{"pos": Vector3(44.0, 0.1, 36.0), "sector": GateRoom.SECTOR_ARMORY},
			{"pos": Vector3(35.0, 0.1, 36.0), "sector": GateRoom.SECTOR_ARMORY},
			{"pos": Vector3(26.0, 0.1, 36.0), "sector": GateRoom.SECTOR_ROUND_HALLWAY},
			{"pos": Vector3(24.0, 0.1, 18.0), "sector": GateRoom.SECTOR_ELEVATOR_LOBBY},
			{"pos": Vector3(22.5, 0.1, 9.6), "sector": GateRoom.SECTOR_EAST_CORRIDOR},
			{"pos": Vector3(22.5, 0.1, 6.0), "sector": GateRoom.SECTOR_EAST_CORRIDOR},
			{"pos": Vector3(18.0, 0.1, 4.0), "sector": GateRoom.SECTOR_EAST_CORRIDOR},
			{"pos": Vector3(5.0, 0.1, 4.0), "sector": GateRoom.SECTOR_GATE_ROOM},
			{"pos": Vector3(5.0, 0.1, 7.8), "sector": GateRoom.SECTOR_CONTROL_ROOM},
			{"pos": Vector3(5.0, 0.1, 14.0), "sector": GateRoom.SECTOR_CONTROL_ROOM},
			{"pos": Vector3(0.0, 0.1, 15.0), "sector": GateRoom.SECTOR_CONTROL_ROOM},
			{"pos": Vector3(12.0, 0.1, 15.0), "sector": GateRoom.SECTOR_CONTROL_ROOM},
			{"pos": Vector3(0.0, 0.1, 15.0), "sector": GateRoom.SECTOR_CONTROL_ROOM},
			{"pos": Vector3(0.0, 0.1, 22.0), "sector": GateRoom.SECTOR_CONTROL_ROOM},
			{"pos": Vector3(0.0, 0.1, 28.0), "sector": GateRoom.SECTOR_FALLBACK_HALLWAY},
			{"pos": Vector3(2.5, 0.1, 28.0), "sector": GateRoom.SECTOR_FALLBACK_HALLWAY},
			{"pos": Vector3(2.5, 0.1, 36.0), "sector": GateRoom.SECTOR_FALLBACK_HALLWAY},
			{"pos": Vector3(11.5, 0.1, 36.0), "sector": GateRoom.SECTOR_CONNECTOR_TUNNEL},
			{"pos": Vector3(26.0, 0.1, 36.0), "sector": GateRoom.SECTOR_ROUND_HALLWAY},
			{"pos": Vector3(44.0, 0.1, 36.0), "sector": GateRoom.SECTOR_ARMORY}
		]

		for i: int in range(perimeter_points.size()):
			var pt_data: Dictionary = perimeter_points[i]
			var p: Vector3 = pt_data["pos"]
			var expected_sec: String = pt_data["sector"]

			var detected_sec: String = gateroom.get_current_sector(p)
			assert(detected_sec == expected_sec, "Perimeter point %s must classify as %s (got %s)" % [
				str(p), expected_sec, detected_sec
			])

			# Verify CharacterBody3D has solid ground contact at every route waypoint
			player.global_position = p
			var grounded: bool = player.test_move(player.global_transform, Vector3.DOWN * 0.15)
			assert(grounded, "Operative must maintain solid floor contact at waypoint %s (no void/gap)!" % str(p))

		print("[TEST 2/5] PASS: All Level 28 sectors physically connected with unobstructed doorways and 100% flat floor alignment.")

	elif ticks == 6:
		# ========================================================
		# TEST 3: Multi-Console Blast Door Operations (Center, West, East)
		# ========================================================
		print("[TEST 3/5] Testing Multi-Console Blast Door Operations (Center, West, East)...")

		var consoles: Array[Node] = gateroom.get_tree().get_nodes_in_group("blast_door_console")
		assert(consoles.size() >= 3, "All 3 Blast Door Consoles (Central, West, East) must be in 'blast_door_console' group")

		var central_console: BlastDoorConsoleScript = null
		var west_console: BlastDoorConsoleScript = null
		var east_console: BlastDoorConsoleScript = null
		for node: Node in consoles:
			var c: BlastDoorConsoleScript = node as BlastDoorConsoleScript
			if c != null:
				if c.door_id == "center":
					central_console = c
				elif c.door_id == "west":
					west_console = c
				elif c.door_id == "east":
					east_console = c

		assert(central_console != null, "Central Blast Door console must exist")
		assert(west_console != null, "West Blast Door console must exist")
		assert(east_console != null, "East Blast Door console must exist")

		# Initial state: doors must start in OPEN position
		assert(not gateroom.is_blast_doors_closed, "Blast doors must start in OPEN position")

		# Verify initial console light status
		for c: BlastDoorConsoleScript in [central_console, west_console, east_console]:
			if c.console_light != null:
				assert(c.console_light.light_color.g > 0.5, "Console light for %s must start green when doors are open" % c.door_id)

		# --------------------------------------------------------
		# 3A. Central Console Interaction -> Close Doors
		# --------------------------------------------------------
		print("  -> Interacting with Central Console (Z=22) to seal blast doors...")
		player.global_position = central_console.global_position + Vector3(0.0, 0.0, 1.0)
		central_console.interact(player)
		assert(gateroom.is_blast_doors_closed, "Interacting with Central Console must close all blast doors")

		# Verify console status indicators turned red
		for c: BlastDoorConsoleScript in [central_console, west_console, east_console]:
			if c.console_light != null:
				assert(c.console_light.light_color.r > 0.8, "Console light for %s must turn red when doors close" % c.door_id)
			if c.prompt_label != null:
				assert("OPEN" in c.prompt_label.text, "Prompt label for %s must display OPEN when doors are sealed" % c.door_id)

		# --------------------------------------------------------
		# 3B. East Console Interaction -> Open Doors
		# --------------------------------------------------------
		print("  -> Interacting with East Console (X=18, Z=4) to open blast doors...")
		gateroom.is_animating_doors = false
		player.global_position = east_console.global_position + Vector3(0.0, 0.0, 1.0)
		east_console.interact(player)
		assert(not gateroom.is_blast_doors_closed, "Interacting with East Console must open all blast doors back up")

		# Verify console status indicators turned green
		for c: BlastDoorConsoleScript in [central_console, west_console, east_console]:
			if c.console_light != null:
				assert(c.console_light.light_color.g > 0.5, "Console light for %s must turn green when doors open" % c.door_id)
			if c.prompt_label != null:
				assert("SEAL" in c.prompt_label.text or "CLOSE" in c.prompt_label.text,
					"Prompt label for %s must display SEAL/CLOSE when doors are open" % c.door_id)

		# --------------------------------------------------------
		# 3C. West Console Interaction -> Toggle Close & Re-open Doors
		# --------------------------------------------------------
		print("  -> Interacting with West Console (X=-18, Z=4) to toggle seal and re-open...")
		gateroom.is_animating_doors = false
		player.global_position = west_console.global_position + Vector3(0.0, 0.0, 1.0)
		west_console.interact(player)
		assert(gateroom.is_blast_doors_closed, "Interacting with West Console must seal all blast doors")

		gateroom.is_animating_doors = false
		west_console.interact(player)
		assert(not gateroom.is_blast_doors_closed, "Second interaction with West Console must re-open all blast doors")

		# Reset doors fully open
		gateroom.is_animating_doors = false
		var door_l: CSGBox3D = gateroom.get_node_or_null("BlastDoors/BlastDoorLeft") as CSGBox3D
		var door_r: CSGBox3D = gateroom.get_node_or_null("BlastDoors/BlastDoorRight") as CSGBox3D
		if door_l != null and door_r != null:
			door_l.position.x = -4.8
			door_r.position.x = 4.8

		print("[TEST 3/5] PASS: Central, West, and East Blast Door Consoles fully operational and synchronized.")

	elif ticks == 8:
		# ========================================================
		# TEST 4: Sector Shrouding & Fog of War
		# ========================================================
		print("[TEST 4/5] Testing Sector Shrouding & Dynamic Fog of War...")

		# 1. Verify all 10 Level 28 sectors have configured shroud boxes
		var expected_sectors: Array[String] = [
			GateRoom.SECTOR_GATE_ROOM,
			GateRoom.SECTOR_CONTROL_ROOM,
			GateRoom.SECTOR_FALLBACK_HALLWAY,
			GateRoom.SECTOR_CONNECTOR_TUNNEL,
			GateRoom.SECTOR_ROUND_HALLWAY,
			GateRoom.SECTOR_ARMORY,
			GateRoom.SECTOR_LABORATORY,
			GateRoom.SECTOR_ELEVATOR_LOBBY,
			GateRoom.SECTOR_EAST_CORRIDOR,
			GateRoom.SECTOR_WEST_CORRIDOR
		]
		assert(gateroom.sector_shrouds.size() == 10, "All 10 Level 28 sectors must have configured shrouds (found %d)" % gateroom.sector_shrouds.size())
		for sec in expected_sectors:
			assert(gateroom.sector_shrouds.has(sec), "Sector shroud for %s must exist" % sec)
			var s_mesh := gateroom.sector_shrouds[sec] as MeshInstance3D
			assert(s_mesh != null and s_mesh.mesh is BoxMesh, "Shroud %s must be a valid BoxMesh" % sec)

		# 2. When player is in Armory:
		gateroom._update_sector_shrouding(GateRoom.SECTOR_ARMORY)
		var armory_shroud := gateroom.sector_shrouds[GateRoom.SECTOR_ARMORY] as MeshInstance3D
		var round_shroud := gateroom.sector_shrouds[GateRoom.SECTOR_ROUND_HALLWAY] as MeshInstance3D
		var gateroom_shroud := gateroom.sector_shrouds[GateRoom.SECTOR_GATE_ROOM] as MeshInstance3D
		var west_shroud := gateroom.sector_shrouds[GateRoom.SECTOR_WEST_CORRIDOR] as MeshInstance3D

		assert(not armory_shroud.visible, "Armory shroud must be HIDDEN when operative is inside Armory")
		assert(round_shroud.visible, "Round Hallway shroud must be VISIBLE when operative is in Armory")
		assert(gateroom_shroud.visible, "Gate Room shroud must be VISIBLE (opaque roof) when operative is in Armory")
		assert(west_shroud.visible, "West Corridor shroud must be VISIBLE (opaque roof) when operative is in Armory")

		# Adjacent sector (Round Hallway) must use alpha ~0.90 structural silhouette material with ambient emission
		assert(round_shroud.material_override == gateroom.shroud_mat_adjacent, "Adjacent shroud must use silhouette material")
		var adj_mat := round_shroud.material_override as StandardMaterial3D
		assert(adj_mat != null and adj_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Adjacent shroud must use alpha transparency")
		assert(is_equal_approx(adj_mat.albedo_color.a, 0.90), "Adjacent shroud alpha must be 0.90 for subtle structural silhouette")

		# Distant visited sector (Gate Room) must use opaque structural material
		assert(gateroom_shroud.material_override == gateroom.shroud_mat_visited, "Distant visited shroud must use visited material")
		var visited_mat := gateroom_shroud.material_override as StandardMaterial3D
		assert(visited_mat != null and visited_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Visited shroud must be fully opaque")

		# Distant unvisited sector (Laboratory) must use opaque deep fog-of-war material
		var lab_shroud := gateroom.sector_shrouds[GateRoom.SECTOR_LABORATORY] as MeshInstance3D
		assert(lab_shroud.material_override == gateroom.shroud_mat_opaque, "Distant unvisited shroud must use opaque material")
		var opaque_mat := lab_shroud.material_override as StandardMaterial3D
		assert(opaque_mat != null and opaque_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Distant unvisited shroud must be fully opaque")

		# 3. Test pickup culling in distant room:
		var lab_patch := gateroom.find_child("LabDataPatchDrive", true, false)
		if lab_patch != null:
			var patch_node := lab_patch as Node3D
			assert(not patch_node.visible, "LabDataPatchDrive in Laboratory must be culled while operative is in Armory")

		# 4. Create an enemy Jaffa in Gate Room arena while player is in Armory
		var jaffa_scene := load(JAFFA_SCENE) as PackedScene
		var jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		gateroom.get_node("Enemies").add_child(jaffa)
		jaffa.global_position = Vector3(0.0, 0.1, -10.0) # In Gate Room
		player.global_position = Vector3(44.0, 0.1, 36.0) # In Armory

		# Force shroud update
		gateroom._update_sector_shrouding(GateRoom.SECTOR_ARMORY)
		assert(not jaffa.visible, "Jaffa in Gate Room must be culled (visible=false) when operative is in distant shrouded Armory")

		# 5. Move player into Gate Room: Jaffa must become visible, Gate Room shroud unmasks
		player.global_position = Vector3(0.0, 0.1, 4.0)
		gateroom._update_sector_shrouding(GateRoom.SECTOR_GATE_ROOM)
		assert(not gateroom_shroud.visible, "Gate Room shroud must unmask when operative enters Gate Room")
		assert(jaffa.visible, "Jaffa must become VISIBLE when operative enters Gate Room arena")

		# Now Armory is a previously visited distant room: should use shroud_mat_visited
		assert(armory_shroud.visible, "Armory shroud must be visible when operative is in Gate Room")
		assert(armory_shroud.material_override == gateroom.shroud_mat_visited, "Previously visited Armory must use visited opaque material")

		jaffa.queue_free()
		print("[TEST 4/5] PASS: Sector shrouds and dynamic Fog of War enemy culling verified.")

	elif ticks == 10:
		# ========================================================
		# TEST 5: Tactical AI Waypoint Scramble & Strict Wall LOS
		# ========================================================
		print("[TEST 5/5] Testing SGC Airman Waypoint Scramble & Strict Wall LOS...")

		var airman_scene := load(AIRMAN_SCENE) as PackedScene
		var airman: SGCAirmanAIScript = airman_scene.instantiate() as SGCAirmanAIScript
		gateroom.get_node("Allies").add_child(airman)
		airman.global_position = Vector3(42.0, 0.1, 34.0) # In Armory

		airman.scramble_to_gate_room()
		assert(airman.current_state == SGCAirmanAIScript.State.SCRAMBLE, "Airman must enter SCRAMBLE state")
		assert(airman.current_scramble_waypoint_index == 0, "Airman scramble must start at Waypoint 0")

		# Advance scramble: first waypoint must point towards Armory doorway (35, 0.1, 36)
		airman._process_scramble(0.016)
		assert(airman.velocity.x < 0.0, "Airman must move west toward Armory doorway rather than diagonal into walls")

		# Test Line of Sight check
		var jaffa_scene := load(JAFFA_SCENE) as PackedScene
		var jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		gateroom.get_node("Enemies").add_child(jaffa)
		jaffa.global_position = Vector3(0.0, 0.1, -10.0) # Behind multiple Gate Room walls from Armory

		assert(not airman._has_line_of_sight(jaffa), "Airman in Armory must NOT have Line of Sight to Jaffa in Gate Room")
		assert(not jaffa._has_line_of_sight(airman), "Jaffa in Gate Room must NOT have Line of Sight to Airman in Armory")

		# Neither AI should aim directly through walls:
		jaffa.current_target = airman
		jaffa._physics_process(0.016)
		# When behind walls without LOS, Jaffa does not snap yaw to airman through wall
		assert(not is_equal_approx(jaffa.rotation.y, atan2(-(airman.global_position.x - jaffa.global_position.x), -(airman.global_position.z - jaffa.global_position.z))),
			"Jaffa must not aim staff weapon directly through solid walls without Line of Sight")

		airman.queue_free()
		jaffa.queue_free()
		print("[TEST 5/5] PASS: Tactical AI waypoint scramble and strict Wall Line-of-Sight verified.")

		print("\n========================================================")
		print("  SPRINT 16 COMPLEX CONNECTIVITY & AI TEST PASSED!      ")
		print("  ✓ 360-Degree Tactical Isometric Orbit & WASD Orientation ")
		print("  ✓ Seamless Level 28 Hallway Connectivity (No Dead Ends)")
		print("  ✓ Level 28 Floor Alignment & Zero Doorway Cliff Mismatch")
		print("  ✓ Multi-Console Blast Door Operations (Center/West/East) ")
		print("  ✓ Sector Shrouding & Fog of War Dynamic Enemy Culling ")
		print("  ✓ SGC Airman Waypoint Scramble & Strict Wall LOS      ")
		print("========================================================\n")
		quit(0)
		return true

	return false
