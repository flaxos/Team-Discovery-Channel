extends SceneTree
## Sprint 11 Verification Suite: Canonical SGC Lore Decoupling & Control Room Consoles.
## Validates:
##  1. Absence of Goa'uld Transport Rings on SGC Sublevel 28 (preserved in res://scenes/props/).
##  2. Absence of offworld DHD on Gate Room floor (preserved in res://scenes/props/).
##  3. SGCDialingConsole instantiated in Level28Complex/ControlRoomMezzanine.
##  4. Operative interaction at Control Room terminal executes 7 chevrons + GDO authorization.
##  5. IrisServoHousing present at Stargate platform base.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")

var gateroom: GateRoom = null
var player: PlayerController3D = null
var ticks: int = 0


func _init() -> void:
	call_deferred("_setup")

func _setup() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 11 LORE DECOUPLING & CONSOLES TEST")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_CARTER_TECH
	gateroom.get_node("Players").add_child(player, true)


func _process(_delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Lore Decoupling - No Rings or DHD on Gate Room floor
		print("[TEST 1/4] Verifying offworld props decoupled from SGC Sublevel 28...")
		var root_rings := gateroom.get_node_or_null("TransportRings")
		assert(root_rings == null, "Goa'uld Transport Rings must NOT exist on Gate Room floor")

		var hallway_rings := gateroom.get_node_or_null("FallbackHallway/TransportRingsBeta")
		assert(hallway_rings == null, "Goa'uld Transport Rings must NOT exist in Fallback Hallway")

		var root_dhd := gateroom.get_node_or_null("DHDConsole")
		assert(root_dhd == null, "Offworld DHD pedestal must NOT exist on Gate Room floor")
		print("[TEST 1/4] PASS: Offworld Transport Rings and DHD pedestal decoupled from SGC Sublevel 28.")

	elif ticks == 5:
		# TEST 2: SGC Dialing Computer Console in Control Room Mezzanine
		print("[TEST 2/4] Verifying SGC Dialing Console in Control Room Mezzanine...")
		var control_room := gateroom.get_node_or_null("Level28Complex/ControlRoomMezzanine")
		assert(control_room != null, "ControlRoomMezzanine must exist")

		var sgc_dialer := control_room.get_node_or_null("SGCDialingConsole") as SGCDialingConsoleScript
		assert(sgc_dialer != null, "SGCDialingConsole must exist in ControlRoomMezzanine")
		assert(sgc_dialer.position.z >= 9.0 and sgc_dialer.position.z <= 12.0, "SGCDialingConsole must overlook Gate Room (found Z=%.2f)" % sgc_dialer.position.z)
		print("[TEST 2/4] PASS: SGC Dialing Console installed on Control Room Mezzanine overlooking Gate Room.")

	elif ticks == 10:
		# TEST 3: Iris Servo Housing at Gate Ramp Base
		print("[TEST 3/4] Verifying Iris Servo Housing at Stargate ramp base...")
		var iris_servo := gateroom.get_node_or_null("IrisServoHousing") as IrisServoHousingScript
		assert(iris_servo != null, "IrisServoHousing must exist at Stargate base")
		assert(iris_servo.global_position.distance_to(gateroom.get_node("Stargate").position) < 8.0, "IrisServoHousing must be near Stargate base")
		print("[TEST 3/4] PASS: Iris Servo Housing positioned at Stargate base platform.")

	elif ticks == 15:
		# TEST 4: Control Room Terminal Dialing & GDO Authorization
		print("[TEST 4/4] Testing Control Room terminal chevron locking and GDO authorization...")
		var sgc_dialer := gateroom.dhd_console as SGCDialingConsoleScript
		assert(sgc_dialer != null, "Dialing console accessor must return SGCDialingConsole")

		preload("res://tests/support/mission_fixture.gd").extraction_ready(gateroom)
		sgc_dialer.start_dialing(player)
		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.CHEVRONS, "Console must enter CHEVRONS phase")

		for i in range(7):
			var glyph: String = sgc_dialer.chevron_sequence[sgc_dialer.current_chevron_index]
			var ok := sgc_dialer.input_glyph(glyph)
			assert(ok, "Glyph %d must be accepted" % (i + 1))

		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.GDO_AUTH, "Console must advance to GDO_AUTH phase")

		for i in range(4):
			var beat: String = sgc_dialer.gdo_sequence[sgc_dialer.gdo_index]
			var ok := sgc_dialer.input_glyph(beat)
			assert(ok, "GDO beat %d must be accepted" % (i + 1))

		assert(sgc_dialer.current_phase == DHDDialer.DialPhase.COMPLETE, "Console must reach COMPLETE phase")
		print("[TEST 4/4] PASS: Control Room Mezzanine SGC Dialing Console 7-chevron + GDO sequence verified.")

		print("\n========================================================")
		print("  SPRINT 11 SGC LORE DECOUPLING & CONSOLES TEST PASSED! ")
		print("  ✓ Goa'uld Transport Rings Decoupled from Sublevel 28  ")
		print("  ✓ Offworld DHD Pedestal Decoupled from Gate Ramp Floor ")
		print("  ✓ SGC Dialing Supercomputer Installed in Control Room ")
		print("  ✓ Iris Servo Manual Override Housing at Gate Ramp Base")
		print("  ✓ Full 7-Chevron + GDO Authorization at SGC Console   ")
		print("========================================================\n")
		quit(0)
		return true

	return false
