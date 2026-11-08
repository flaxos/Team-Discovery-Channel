extends SceneTree
## Squad Radial Command Wheel & Tri-Sensory Confirmation Test Suite
## Validates:
##  1. Tap vs Hold Threshold: Quick tap (<200ms) contextual ping vs hold (>=200ms) radial wheel open.
##  2. Radial Slice Geometry: 5 Slices (Move, Hold, Suppress, Man .50, Regroup) & Center Deadzone Cancel.
##  3. Release Execution & Closure: Radial selection confirmed on key/mouse release, wheel closed.
##  4. Tri-Sensory Confirmation: Holographic 3D Waypoint, HUD Military Toast Banner, Radio Squawk Audio.
##  5. Squad Dispatch Logic: Individual Airman orders, squad-wide Regroup, and No Active Airmen warning.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"
const AIRMAN_SCENE: String = "res://scenes/entities/SGCAirman.tscn"

const SGCAirmanAIScript = preload("res://scripts/entities/SGCAirmanAI.gd")
const RadialCommandWheelScript = preload("res://scripts/ui/RadialCommandWheel.gd")
const DeployableTurretScript = preload("res://scripts/weapons/DeployableTurret.gd")

var gateroom: GateRoom = null
var player: PlayerController3D = null
var hud: TacticalHUD = null
var airman_davis: SGCAirmanAI = null
var airman_siler: SGCAirmanAI = null
var turret_west: DeployableTurret = null
var ticks: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SQUAD RADIAL COMMAND WHEEL VERIFICATION  ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	turret_west = gateroom.find_child("TurretWest", true, false) as DeployableTurret
	assert(turret_west != null, "TurretWest must exist in GateRoom")

	hud = gateroom.find_child("TacticalHUD", true, false) as TacticalHUD
	assert(hud != null, "TacticalHUD must exist in GateRoom")

	# Setup Player
	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)
	player.global_position = Vector3(0.0, 0.1, 4.0)

	# Setup Allied Airmen
	var allies := gateroom.get_node_or_null("Allies") as Node3D
	assert(allies != null, "Allies container must exist in GateRoom")

	if allies.get_child_count() >= 2:
		airman_davis = allies.get_child(0) as SGCAirmanAI
		airman_siler = allies.get_child(1) as SGCAirmanAI
	else:
		var a_scene := load(AIRMAN_SCENE) as PackedScene
		airman_davis = a_scene.instantiate() as SGCAirmanAI
		airman_davis.name = "AirmanDavis"
		airman_davis.airman_callsign = "AIRMAN DAVIS"
		allies.add_child(airman_davis)

		airman_siler = a_scene.instantiate() as SGCAirmanAI
		airman_siler.name = "AirmanSiler"
		airman_siler.airman_callsign = "SGT SILER"
		allies.add_child(airman_siler)

	assert(airman_davis != null and airman_siler != null, "Both Airmen must exist in fireteam")


func _process(_delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# ========================================================
		# TEST 1: Tap vs Hold Threshold (< 200ms vs >= 200ms)
		# ========================================================
		print("[TEST 1/5] Testing [Q] / Mouse 4 Quick-Tap vs Hold Threshold...")

		# Initial state
		assert(not player.is_command_wheel_open, "Command wheel must be initially closed")
		assert(not hud.is_radial_wheel_open(), "HUD radial wheel must be initially closed")

		# 1A: Quick Tap (< 200ms)
		var test_target_pos := Vector3(5.0, 0.1, 3.0)
		player.locked_target_world_pos = test_target_pos
		player._on_command_input_pressed()
		assert(player.is_holding_command_input, "Player must register command input pressed")

		# Release after 50ms (well under 200ms)
		player.command_press_time_ms = Time.get_ticks_msec() - 50
		player._on_command_input_released()
		assert(not player.is_command_wheel_open, "Radial wheel must NOT open on quick tap (< 200ms)")
		assert(not hud.is_radial_wheel_open(), "HUD radial wheel must remain closed on quick tap")
		assert(airman_davis.current_state == SGCAirmanAIScript.State.ORDER_MOVE or airman_davis.current_state == SGCAirmanAIScript.State.COMBAT,
			"Quick tap must fire contextual ping without opening radial wheel")

		# 1B: Hold (>= 200ms)
		player._on_command_input_pressed()
		assert(player.is_holding_command_input, "Player must register command input pressed for hold test")

		# Advance time past 200ms threshold
		player.command_press_time_ms = Time.get_ticks_msec() - 250
		player._physics_process(0.016)

		assert(player.is_command_wheel_open, "Radial command wheel must engage when held >= 200ms")
		assert(hud.is_radial_wheel_open(), "HUD radial wheel must be open and active")

		# Cleanup for next test
		player.close_squad_command_wheel()
		assert(not player.is_command_wheel_open, "Command wheel must close cleanly")
		print("[TEST 1/5] PASS: Tap vs Hold threshold (< 200ms tap ping, >= 200ms radial wheel) verified.")

	elif ticks == 4:
		# ========================================================
		# TEST 2: Radial Slice Selection Geometry & Deadzone Cancel
		# ========================================================
		print("[TEST 2/5] Testing 5 Radial Slices Geometry & Center Deadzone Cancel...")
		var wheel: RadialCommandWheel = hud.radial_wheel
		assert(wheel != null, "RadialCommandWheel instance must exist in HUD")

		var center := Vector2(640.0, 360.0)
		wheel.open_wheel(center, Vector3(0.0, 0.1, 0.0))
		assert(wheel.is_wheel_active, "Radial wheel must be active after open_wheel")

		# Test Deadzone (< 45px) -> CANCEL (-1)
		wheel.update_mouse_position(center + Vector2(15.0, 15.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_CANCEL,
			"Mouse inside 45px deadzone must select CANCEL (-1)")

		wheel.update_mouse_position(center + Vector2(0.0, 0.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_CANCEL,
			"Mouse at exact center must select CANCEL (-1)")

		# Test Slice 0: MOVE TO COVER (Top / North, 90 deg)
		wheel.update_mouse_position(center + Vector2(0.0, -90.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_MOVE_TO_COVER,
			"Vector straight up (North) must select Slice 0: MOVE TO COVER (got %d)" % wheel.get_selected_command())

		# Test Slice 1: HOLD CORNER (Top-Right / North-East, 18 deg)
		# 18 deg: cos(18) ~ 0.951, sin(18) ~ 0.309 -> x = 95.1, y = -30.9
		wheel.update_mouse_position(center + Vector2(95.0, -31.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_HOLD_CORNER,
			"Vector North-East (~18 deg) must select Slice 1: HOLD CORNER (got %d)" % wheel.get_selected_command())

		# Test Slice 2: SUPPRESS HALLWAY (Bottom-Right / South-East, -54 deg)
		# -54 deg: cos(-54) ~ 0.588, sin(-54) ~ -0.809 -> x = 58.8, y = 80.9
		wheel.update_mouse_position(center + Vector2(59.0, 81.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_SUPPRESS_HALLWAY,
			"Vector South-East (~ -54 deg) must select Slice 2: SUPPRESS HALLWAY (got %d)" % wheel.get_selected_command())

		# Test Slice 3: MAN .50 CAL (Bottom-Left / South-West, -126 deg)
		# -126 deg: cos(-126) ~ -0.588, sin(-126) ~ -0.809 -> x = -58.8, y = 80.9
		wheel.update_mouse_position(center + Vector2(-59.0, 81.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_MAN_50_CAL,
			"Vector South-West (~ -126 deg) must select Slice 3: MAN .50 CAL (got %d)" % wheel.get_selected_command())

		# Test Slice 4: REGROUP ON ME (Top-Left / North-West, 162 deg)
		# 162 deg: cos(162) ~ -0.951, sin(162) ~ 0.309 -> x = -95.1, y = -30.9
		wheel.update_mouse_position(center + Vector2(-95.0, -31.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_REGROUP_ON_ME,
			"Vector North-West (~ 162 deg) must select Slice 4: REGROUP ON ME (got %d)" % wheel.get_selected_command())

		# Test relative mouse direction updating
		wheel.open_wheel(center, Vector3.ZERO)
		wheel.update_mouse_direction(Vector2(0.0, -80.0))
		assert(wheel.get_selected_command() == RadialCommandWheel.CMD_MOVE_TO_COVER,
			"update_mouse_direction straight up must select Slice 0: MOVE TO COVER")

		wheel.close_wheel()
		assert(not wheel.is_wheel_active, "Radial wheel must be inactive after close_wheel")
		print("[TEST 2/5] PASS: All 5 radial slice sectors and deadzone cancel geometry verified.")

	elif ticks == 6:
		# ========================================================
		# TEST 3: Release Execution & Command Wheel Closure
		# ========================================================
		print("[TEST 3/5] Testing Release Execution & Command Wheel Closure...")

		var target_loc := Vector3(8.0, 0.1, 2.0)
		player.locked_target_world_pos = target_loc
		player.open_squad_command_wheel()
		assert(player.is_command_wheel_open, "Command wheel must be open")

		# Select Slice 0: MOVE TO COVER
		var wheel: RadialCommandWheel = hud.radial_wheel
		wheel.update_mouse_position(wheel.wheel_center + Vector2(0.0, -90.0))
		assert(hud.get_radial_selected_command() == RadialCommandWheel.CMD_MOVE_TO_COVER,
			"HUD must report CMD_MOVE_TO_COVER selected")

		# Release with >= 200ms hold duration
		player.command_press_time_ms = Time.get_ticks_msec() - 300
		player.is_holding_command_input = true
		player._on_command_input_released()

		assert(not player.is_command_wheel_open, "Command wheel must close upon release")
		assert(not hud.is_radial_wheel_open(), "HUD radial wheel must close upon release")
		assert(airman_davis.current_state == SGCAirmanAIScript.State.ORDER_MOVE,
			"Airman Davis must enter ORDER_MOVE state after Move to Cover release")
		assert(airman_davis.ordered_position.is_equal_approx(target_loc),
			"Airman Davis ordered_position must match target_loc")

		# Test Release on CANCEL deadzone
		player.open_squad_command_wheel()
		wheel.update_mouse_position(wheel.wheel_center) # center deadzone
		assert(hud.get_radial_selected_command() == RadialCommandWheel.CMD_CANCEL,
			"Selected command must be CANCEL in deadzone")

		player.command_press_time_ms = Time.get_ticks_msec() - 300
		player.is_holding_command_input = true
		player._on_command_input_released()
		assert(not player.is_command_wheel_open, "Command wheel must close upon cancelled release")

		print("[TEST 3/5] PASS: Release execution, wheel closure, and cancel abort verified.")

	elif ticks == 8:
		# ========================================================
		# TEST 4: Tri-Sensory Confirmation (3D Waypoint, Toast, Audio)
		# ========================================================
		print("[TEST 4/5] Testing Tri-Sensory Confirmation (3D Waypoint, Toast, Radio Squawk)...")

		# 4A: 3D Holographic Waypoint FX
		var waypoint_pos := Vector3(4.0, 0.1, 6.0)
		player._spawn_command_waypoint_fx(waypoint_pos, RadialCommandWheel.CMD_HOLD_CORNER)

		var waypoints := root.get_tree().get_nodes_in_group("squad_waypoint")
		assert(waypoints.size() > 0, "3D Holographic waypoint node must spawn in scene tree")
		var wp := waypoints[waypoints.size() - 1] as Node3D
		assert(wp.global_position.distance_to(waypoint_pos) < 0.1, "Waypoint must spawn at target position")

		var mesh_inst: MeshInstance3D = wp.find_child("MeshInstance3D", true, false) as MeshInstance3D
		if mesh_inst == null and wp.get_child_count() > 0:
			mesh_inst = wp.get_child(0) as MeshInstance3D
		assert(mesh_inst != null, "Waypoint must contain a MeshInstance3D ring")
		assert(mesh_inst.material_override != null, "Waypoint ring must have material override")
		var wp_mat := mesh_inst.material_override as StandardMaterial3D
		assert(wp_mat != null, "Waypoint material must be StandardMaterial3D")
		# Hold corner uses blue ring: Color(0.25, 0.45, 1.0, 0.9)
		assert(wp_mat.albedo_color.b > 0.8, "Hold Corner waypoint ring must be Blue (high blue component)")
		wp.queue_free()

		# 4B: HUD Military Toast Banner
		var toast_msg := "[TACTICAL ORDER: AIRMAN DAVIS -> HOLD CORNER (SECTOR: GATE ROOM)]"
		hud.show_squad_order_toast(toast_msg, 2.0)
		assert(hud.squad_toast_panel != null, "Squad toast panel must exist")
		assert(hud.squad_toast_panel.visible, "Squad toast panel must be visible after show_squad_order_toast")
		assert(hud.squad_toast_label != null and hud.squad_toast_label.text == toast_msg,
			"Squad toast label must display expected tactical order message")

		# 4C: Radio Squawk / Audio Chirp
		player._play_command_radio_sound()
		var squawk_player: Node = root.find_child("RadioSquawkPlayer", true, false)
		assert(squawk_player != null, "RadioSquawkPlayer audio player node must be spawned")
		squawk_player.queue_free()

		print("[TEST 4/5] PASS: Tri-sensory confirmation (3D waypoint ring, HUD toast, radio chirp) verified.")

	elif ticks == 10:
		# ========================================================
		# TEST 5: Squad Dispatch Logic & Fallback Warnings
		# ========================================================
		print("[TEST 5/5] Testing Full Squad Dispatch Logic & Warning Toast...")

		# 5A: HOLD CORNER
		var corner_anchor := Vector3(-5.0, 0.1, 5.8)
		player.execute_squad_radial_command(RadialCommandWheel.CMD_HOLD_CORNER, corner_anchor)
		assert(airman_davis.current_state == SGCAirmanAIScript.State.HOLD_CORNER,
			"Airman Davis must enter HOLD_CORNER state on HOLD CORNER command")
		assert(airman_davis.is_in_cover and airman_davis.is_crouching,
			"Airman must adopt crouching tactical cover stance behind corner")

		# 5B: SUPPRESS HALLWAY
		var hallway_target := Vector3(0.0, 0.1, -10.0)
		player.execute_squad_radial_command(RadialCommandWheel.CMD_SUPPRESS_HALLWAY, hallway_target)
		assert(airman_davis.is_suppressing, "Airman Davis must enter suppressive state")
		assert(airman_davis.is_peeking, "Airman must peek up to lay down suppressive hallway fire")

		# 5C: MAN .50 CAL
		player.execute_squad_radial_command(RadialCommandWheel.CMD_MAN_50_CAL, turret_west.global_position)
		assert(airman_davis.current_state == SGCAirmanAIScript.State.MOVE_TO_TURRET or airman_davis.current_state == SGCAirmanAIScript.State.MAN_TURRET,
			"Airman Davis must move to man .50 Cal Browning turret")

		# 5D: REGROUP ON ME (All Airmen)
		player.execute_squad_radial_command(RadialCommandWheel.CMD_REGROUP_ON_ME, player.global_position)
		assert(airman_davis.current_state == SGCAirmanAIScript.State.ORDER_REGROUP,
			"Airman Davis must acknowledge squad REGROUP order")
		assert(airman_siler.current_state == SGCAirmanAIScript.State.ORDER_REGROUP,
			"Airman Siler must acknowledge squad REGROUP order")

		# 5E: No Active Airmen Warning Toast
		# Temporarily down both airmen
		airman_davis.health_component.current_health = 0.0
		airman_davis.health_component.is_downed = true
		airman_siler.health_component.current_health = 0.0
		airman_siler.health_component.is_downed = true

		player.execute_squad_radial_command(RadialCommandWheel.CMD_MOVE_TO_COVER, Vector3(2.0, 0.1, 2.0))
		assert(hud.squad_toast_label.text == "[SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]",
			"Warning toast must appear when no active airmen are available")

		player.execute_squad_radial_command(RadialCommandWheel.CMD_REGROUP_ON_ME, player.global_position)
		assert(hud.squad_toast_label.text == "[SQUAD WARNING: NO ACTIVE AIRMEN AVAILABLE]",
			"Warning toast must appear when attempting regroup with no active airmen")

		print("[TEST 5/5] PASS: Squad dispatch (Hold, Suppress, Turret, Regroup, No Airmen Warning) verified.")

		print("\n========================================================")
		print("  SQUAD RADIAL COMMAND WHEEL VERIFICATION PASSED!       ")
		print("  ✓ Tap vs Hold Input Interception (<200ms vs >=200ms)  ")
		print("  ✓ 5 Radial Slices + Center Deadzone (<45px Cancel)    ")
		print("  ✓ Release Confirmation & Mouse Selection Interception ")
		print("  ✓ Tri-Sensory Confirmation (3D FX, HUD Toast, Audio)  ")
		print("  ✓ Airmen Dispatch & Tactical Corner / Turret Orders   ")
		print("  ✓ Fallback Warning Toast on All Airmen Downed         ")
		print("========================================================\n")
		quit(0)

	return false
