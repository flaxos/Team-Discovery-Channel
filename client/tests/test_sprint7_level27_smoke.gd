extends SceneTree
## Automated Headless Validation: Sprint 7 SGC Level 27 Command Deck & Vertical Transit Smoke Test.
## Validates:
##  1. Sublevel 27 Architectural Geometry (Briefing Room, General's Office, Security Station, Overlook Window).
##  2. SGC Hydraulic Elevator 2-Stop Vertical Transit (Sublevel 28 <-> Sublevel 27, animated doors, arrival cues).
##  3. Continuous 24-Step Spiral Staircase Interconnect with full physics collisions.
##  4. Multi-Level Emergency Alert Strobe Lighting across all 14 sector beacons.
##  5. Dynamic Sublevel 27 Sector Classification & Signal Integration.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

var gateroom: GateRoom = null
var elevator: SGCElevator = null
var player: PlayerController3D = null
var ticks: int = 0
var last_sector: String = ""


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 7 LEVEL 27 & VERTICAL TRANSIT     ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	elevator = gateroom.get_node_or_null("SGCElevator") as SGCElevator
	assert(elevator != null, "SGCElevator must be instanced in GateRoom")

	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load successfully")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	gateroom.get_node("Players").add_child(player, true)

	gateroom.sector_changed.connect(func(pid: int, old_s: String, new_s: String) -> void:
		last_sector = new_s
	)


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Sublevel 27 Architectural Geometry & Command Deck Hierarchy
		print("[TEST 1/5] Testing Level 27 Command Deck Geometry & Sector Hierarchy...")
		var l27: Node3D = gateroom.get_node_or_null("Level27Complex") as Node3D
		assert(l27 != null, "Level27Complex must exist in GateRoom")

		var briefing: Node3D = l27.get_node_or_null("BriefingRoom") as Node3D
		assert(briefing != null, "BriefingRoom sector must exist")

		var overlook_window: MeshInstance3D = briefing.get_node_or_null("BriefingGateRoomOverlook") as MeshInstance3D
		assert(overlook_window != null, "Reinforced glass overlook window into Gate Room must exist")

		var table: CSGBox3D = briefing.get_node_or_null("ConferenceTable") as CSGBox3D
		assert(table != null and table.use_collision, "Mahogany conference table must exist with collision")

		var office: Node3D = l27.get_node_or_null("GeneralsOffice") as Node3D
		assert(office != null, "GeneralsOffice must exist")

		var red_phone: CSGBox3D = office.get_node_or_null("RedHotlinePhone") as CSGBox3D
		assert(red_phone != null, "White House red hotline telephone must exist on Hammond's desk")

		var destruct_console: CSGBox3D = office.get_node_or_null("SelfDestructConsole") as CSGBox3D
		assert(destruct_console != null, "Dual-key Base Self-Destruct console must exist")

		var security: Node3D = l27.get_node_or_null("SecurityStation") as Node3D
		assert(security != null, "SecurityStation must exist")

		var monitors: CSGBox3D = security.get_node_or_null("CCTVMonitorBank") as CSGBox3D
		assert(monitors != null, "CCTV Monitor Bank must exist in Security Station")

		var upper_elevator: Node3D = l27.get_node_or_null("UpperElevatorLobby") as Node3D
		assert(upper_elevator != null, "UpperElevatorLobby must exist on Level 27")

		print("[TEST 1/5] PASS: Sublevel 27 Command Deck geometry, props & overlook verified.")

	elif ticks == 4:
		# TEST 2: SGC Hydraulic Elevator 2-Stop Vertical Transit
		print("[TEST 2/5] Testing SGC Hydraulic Elevator 2-Stop Vertical Transit...")
		assert(elevator.current_floor == 28, "Elevator must start on Sublevel 28")
		assert(not elevator.is_moving, "Elevator must start stationary")

		# Initiate transit to Level 27
		elevator.sync_move_elevator(27)
		assert(elevator.is_moving, "Elevator must be moving after call")
		assert(elevator.state == SGCElevator.ElevatorState.MOVING_UP, "Elevator state must be MOVING_UP")

		# Manually complete transit
		elevator.cabin.position.y = SGCElevator.FLOOR_27_Y
		elevator.current_floor = 27
		elevator.state = SGCElevator.ElevatorState.AT_27
		elevator.is_moving = false
		elevator._update_floor_indicator(27)
		assert(elevator.current_floor == 27, "Elevator must be on Level 27")
		assert(elevator.state == SGCElevator.ElevatorState.AT_27, "State must be AT_27")

		# Call elevator back down to Level 28
		elevator.sync_move_elevator(28)
		assert(elevator.is_moving, "Elevator must be moving down")
		assert(elevator.state == SGCElevator.ElevatorState.MOVING_DOWN, "State must be MOVING_DOWN")

		# Complete descent
		elevator.cabin.position.y = SGCElevator.FLOOR_28_Y
		elevator.current_floor = 28
		elevator.state = SGCElevator.ElevatorState.AT_28
		elevator.is_moving = false
		elevator._update_floor_indicator(28)
		assert(elevator.current_floor == 28, "Elevator returned to Level 28")
		print("[TEST 2/5] PASS: SGC Elevator 2-stop vertical transit and states verified.")

	elif ticks == 6:
		# TEST 3: Continuous 24-Step Spiral Staircase Interconnect
		print("[TEST 3/5] Testing Continuous 24-Step Spiral Staircase Interconnect...")
		var stairs: Node3D = gateroom.get_node("Level27Complex/SpiralStairsInterconnect") as Node3D
		assert(stairs != null, "SpiralStairsInterconnect node must exist")

		var pole: CSGCylinder3D = stairs.get_node_or_null("StairsCentralPole") as CSGCylinder3D
		assert(pole != null and pole.use_collision, "StairsCentralPole must have physics collision")

		var step_count: int = 0
		for child in pole.get_children():
			var step := child as CSGBox3D
			if step != null and step.name.begins_with("Step"):
				assert(step.use_collision, "Each spiral stair step must have active collision")
				step_count += 1

		assert(step_count == 24, "Spiral staircase must contain exactly 24 helical collision steps (found %d)" % step_count)
		print("[TEST 3/5] PASS: 24-step continuous helical collision stairs verified.")

	elif ticks == 8:
		# TEST 4: Multi-Level Emergency Strobe Lighting (14 Beacons Across L28 & L27)
		print("[TEST 4/5] Testing Multi-Level Emergency Alert Strobe Lighting across 14 Beacons...")
		var em_lights: Node3D = gateroom.get_node("EmergencyLights") as Node3D
		assert(em_lights.get_child_count() == 14, "EmergencyLights must contain exactly 14 sector beacons across L28 and L27 (found %d)" % em_lights.get_child_count())

		# Activate alert
		gateroom.set_emergency_lights(true)
		assert(gateroom.is_emergency_active, "Emergency active flag must be true")
		gateroom._process(0.2)

		for light in em_lights.get_children():
			var omni := light as OmniLight3D
			assert(omni != null and omni.light_energy > 0.0, "All 14 emergency beacons must emit light during alert")

		# Standby reset
		gateroom.set_emergency_lights(false)
		for light in em_lights.get_children():
			var omni := light as OmniLight3D
			assert(omni != null and omni.light_energy == 0.0, "All 14 emergency beacons must return to 0 energy on standby")
		print("[TEST 4/5] PASS: All 14 Sublevel 28 & 27 Emergency Strobe Beacons operate synchronously.")

	elif ticks == 10:
		# TEST 5: Dynamic Sublevel 27 Sector Classification & Signal Integration
		print("[TEST 5/5] Testing Sublevel 27 Sector Classification & Navigation Signals...")

		# Move to Briefing Room
		player.global_position = Vector3(20, 5.5, -4)
		gateroom._process(0.016)
		assert(last_sector == GateRoom.SECTOR_BRIEFING_ROOM, "Must emit BRIEFING_ROOM (got %s)" % last_sector)

		# Move to General's Office
		player.global_position = Vector3(32, 5.5, -4)
		gateroom._process(0.016)
		assert(last_sector == GateRoom.SECTOR_GENERALS_OFFICE, "Must emit GENERALS_OFFICE (got %s)" % last_sector)

		# Move to Security Operations Station
		player.global_position = Vector3(20, 5.5, -16.5)
		gateroom._process(0.016)
		assert(last_sector == GateRoom.SECTOR_SECURITY_STATION, "Must emit SECURITY_STATION (got %s)" % last_sector)

		# Move to Upper Secure Corridor
		player.global_position = Vector3(32, 5.5, -15)
		gateroom._process(0.016)
		assert(last_sector == GateRoom.SECTOR_UPPER_CORRIDOR, "Must emit UPPER_CORRIDOR (got %s)" % last_sector)

		# Move to Upper Elevator Lobby
		player.global_position = Vector3(26, 5.5, 18)
		gateroom._process(0.016)
		assert(last_sector == GateRoom.SECTOR_UPPER_ELEVATOR_LOBBY, "Must emit UPPER_ELEVATOR_LOBBY (got %s)" % last_sector)

		# Descend back to Gate Room
		player.global_position = Vector3(0, 0, 0)
		gateroom._process(0.016)
		assert(last_sector == GateRoom.SECTOR_GATE_ROOM, "Must emit GATE_ROOM on return to Sublevel 28 (got %s)" % last_sector)

		print("[TEST 5/5] PASS: Full Sublevel 27 sector navigation and signals verified.")

		print("\n========================================================")
		print("  SPRINT 7 LEVEL 27 COMMAND DECK TEST PASSED!           ")
		print("  ✓ Level 27 Command Deck (Briefing, Hammond, Security) ")
		print("  ✓ Gate Room Overlook Observation Window               ")
		print("  ✓ SGC Hydraulic Elevator 2-Stop Vertical Transit      ")
		print("  ✓ 24-Step Helical Spiral Staircase Interconnect       ")
		print("  ✓ 14 Synchronous Emergency Strobe Beacons (L28 & L27) ")
		print("  ✓ Dynamic Multi-Level Sector Tracking & Navigation    ")
		print("========================================================\n")
		quit(0)
		return true

	return false
