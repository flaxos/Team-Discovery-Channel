extends SceneTree
## Automated Headless Validation: Sprint 6 SGC Sublevel 28 Full Map Expansion Smoke Test.
## Validates:
##  1. Level 28 Scene Architecture & Hierarchy (Rotunda, Armory, Lab, Elevator Lobby, Mezzanine).
##  2. Real-time Sector Tracking & Spatial Bounding Coordinate Classification.
##  3. Structural Load-Bearing Pillars Physics Collisions in Round Hallway.
##  4. Facility-Wide Emergency Alert Strobe Lighting across all 10 Sector Beacons.
##  5. Operative Sector Transition Signals & Real-time HUD Synchronization.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

var gateroom: GateRoom = null
var player: PlayerController3D = null
var ticks: int = 0
var last_emitted_sector: String = ""


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 6 LEVEL 28 FULL MAP TEST          ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load successfully")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)

	gateroom.sector_changed.connect(func(pid: int, old_s: String, new_s: String) -> void:
		last_emitted_sector = new_s
	)


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Level 28 Scene Architecture & Complex Node Hierarchy
		print("[TEST 1/5] Testing Level 28 Complex Node Hierarchy & Sectors...")
		var complex: Node3D = gateroom.get_node_or_null("Level28Complex") as Node3D
		assert(complex != null, "Level28Complex parent node must exist in GateRoom")

		var connector: Node3D = complex.get_node_or_null("ConnectorTunnel") as Node3D
		assert(connector != null, "ConnectorTunnel must exist")

		var round_hallway: Node3D = complex.get_node_or_null("RoundHallway") as Node3D
		assert(round_hallway != null, "RoundHallway rotunda must exist")

		var armory: Node3D = complex.get_node_or_null("ArmorySector") as Node3D
		assert(armory != null, "ArmorySector must exist")

		var lab: Node3D = complex.get_node_or_null("LaboratorySector") as Node3D
		assert(lab != null, "LaboratorySector must exist")

		var elevator: Node3D = complex.get_node_or_null("ElevatorSector") as Node3D
		assert(elevator != null, "ElevatorSector must exist")

		var control: Node3D = complex.get_node_or_null("ControlRoomMezzanine") as Node3D
		assert(control != null, "ControlRoomMezzanine must exist")

		print("[TEST 1/5] PASS: All 6 new Sublevel 28 sectors verified in scene tree.")

	elif ticks == 4:
		# TEST 2: Sector Spatial Coordinate Classification
		print("[TEST 2/5] Testing Sector Spatial Bounding Coordinate Classification...")
		assert(gateroom.get_current_sector(Vector3(0, 0, 0)) == GateRoom.SECTOR_GATE_ROOM, "Center must be Gate Room")
		assert(gateroom.get_current_sector(Vector3(20, 1.0, -4)) == GateRoom.SECTOR_CONTROL_ROOM, "Mezzanine coordinates must be Control Room")
		assert(gateroom.get_current_sector(Vector3(0, 0, 30)) == GateRoom.SECTOR_FALLBACK_HALLWAY, "Z=30 must be Fallback Hallway")
		assert(gateroom.get_current_sector(Vector3(12, 0, 36)) == GateRoom.SECTOR_CONNECTOR_TUNNEL, "X=12, Z=36 must be Connector Tunnel")
		assert(gateroom.get_current_sector(Vector3(26, 0, 36)) == GateRoom.SECTOR_ROUND_HALLWAY, "X=26, Z=36 must be Round Hallway")
		assert(gateroom.get_current_sector(Vector3(44, 0, 36)) == GateRoom.SECTOR_ARMORY, "X=44, Z=36 must be Armory")
		assert(gateroom.get_current_sector(Vector3(26, 0, 55)) == GateRoom.SECTOR_LABORATORY, "X=26, Z=55 must be Laboratory")
		assert(gateroom.get_current_sector(Vector3(26, 0, 18)) == GateRoom.SECTOR_ELEVATOR_LOBBY, "X=26, Z=18 must be Elevator Lobby")
		print("[TEST 2/5] PASS: All 8 sector bounding volumes accurately classified.")

	elif ticks == 6:
		# TEST 3: Structural Load-Bearing Pillars Collision Physics
		print("[TEST 3/5] Testing Round Hallway Concrete Load-Bearing Pillars Collision...")
		var round_hallway: Node3D = gateroom.get_node("Level28Complex/RoundHallway") as Node3D
		var p_nw := round_hallway.get_node_or_null("PillarNW") as CSGBox3D
		var p_ne := round_hallway.get_node_or_null("PillarNE") as CSGBox3D
		var p_sw := round_hallway.get_node_or_null("PillarSW") as CSGBox3D
		var p_se := round_hallway.get_node_or_null("PillarSE") as CSGBox3D

		assert(p_nw != null and p_nw.use_collision, "PillarNW must have physics collision enabled")
		assert(p_ne != null and p_ne.use_collision, "PillarNE must have physics collision enabled")
		assert(p_sw != null and p_sw.use_collision, "PillarSW must have physics collision enabled")
		assert(p_se != null and p_se.use_collision, "PillarSE must have physics collision enabled")
		print("[TEST 3/5] PASS: 4 Round Hallway load-bearing pillars have active collision.")

	elif ticks == 8:
		# TEST 4: Facility-Wide Emergency Alert Strobe Lighting Pass (10 Sector Beacons)
		print("[TEST 4/5] Testing Facility-Wide Emergency Alert Strobe Lighting across 10 Beacons...")
		var em_lights: Node3D = gateroom.get_node("EmergencyLights") as Node3D
		assert(em_lights.get_child_count() == 10, "EmergencyLights must contain exactly 10 beacons across all sectors")

		# Activate strobe
		gateroom.set_emergency_lights(true)
		assert(gateroom.is_emergency_active, "Emergency active flag must be true")

		# Tick process to calculate strobe energy
		gateroom._process(0.2)
		for light in em_lights.get_children():
			var omni := light as OmniLight3D
			assert(omni != null and omni.light_energy > 0.0, "All sector emergency beacons must emit light during alert")

		# Standby reset
		gateroom.set_emergency_lights(false)
		for light in em_lights.get_children():
			var omni := light as OmniLight3D
			assert(omni != null and omni.light_energy == 0.0, "All sector emergency beacons must return to 0 energy on standby")
		print("[TEST 4/5] PASS: 10 Emergency Alert Strobe Beacons operate synchronously.")

	elif ticks == 10:
		# TEST 5: Operative Sector Transition Signals & Real-time HUD Synchronization
		print("[TEST 5/5] Testing Operative Sector Transitions & Signal Emission...")
		# Move to Connector Tunnel
		player.global_position = Vector3(12, 0, 36)
		gateroom._process(0.016)
		assert(last_emitted_sector == GateRoom.SECTOR_CONNECTOR_TUNNEL, "Must emit CONNECTOR_TUNNEL")

		# Move to Round Hallway
		player.global_position = Vector3(26, 0, 36)
		gateroom._process(0.016)
		assert(last_emitted_sector == GateRoom.SECTOR_ROUND_HALLWAY, "Must emit ROUND_HALLWAY")

		# Move to Armory
		player.global_position = Vector3(44, 0, 36)
		gateroom._process(0.016)
		assert(last_emitted_sector == GateRoom.SECTOR_ARMORY, "Must emit ARMORY")

		# Move to Laboratory
		player.global_position = Vector3(26, 0, 55)
		gateroom._process(0.016)
		assert(last_emitted_sector == GateRoom.SECTOR_LABORATORY, "Must emit LABORATORY")

		# Move to Elevator Lobby
		player.global_position = Vector3(26, 0, 18)
		gateroom._process(0.016)
		assert(last_emitted_sector == GateRoom.SECTOR_ELEVATOR_LOBBY, "Must emit ELEVATOR_LOBBY")

		# Move to Control Room Mezzanine
		player.global_position = Vector3(20, 1.2, -4)
		gateroom._process(0.016)
		assert(last_emitted_sector == GateRoom.SECTOR_CONTROL_ROOM, "Must emit CONTROL_ROOM")

		print("[TEST 5/5] PASS: Dynamic operative sector transitions emit signals across all sectors.")

		print("\n========================================================")
		print("  SPRINT 6 LEVEL 28 FULL MAP TEST PASSED!               ")
		print("  ✓ Level 28 Complex Hierarchy & 6 New Sectors          ")
		print("  ✓ Spatial Coordinate Bounding Sector Classification   ")
		print("  ✓ 4 Load-Bearing Rotunda Pillars Physics Collisions   ")
		print("  ✓ 10 Synchronous Sector Emergency Strobe Beacons      ")
		print("  ✓ Real-Time Operative Sector Navigation & Signals     ")
		print("========================================================\n")
		quit(0)
		return true

	return false
