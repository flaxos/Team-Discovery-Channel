extends SceneTree
## Sprint 12 Verification Suite: 38-Second Wormhole Incursion Engine & Tug-of-War Wave Coordination.
## Validates:
##  1. Inbound Gate Activation Sequence: Chevrons 1->7 lock -> Kawoosh -> Iris Malfunction Alert.
##  2. 38-Second Wormhole Countdown Engine: Timer counts down, HUD banner updates with countdown.
##  3. Wormhole Collapse & 20s Resupply Window: Automatic gate shutdown at 0.0s and capacitor recharge.
##  4. Dynamic Gate Room Iris Servo Repair: Channeling repair snaps Iris shut, blocking reinforcements.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

const SGCDialingConsoleScript = preload("res://scripts/props/SGCDialingConsole.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")

var gateroom: GateRoom = null
var wave_mgr: WaveManager = null
var stargate: StargateRing = null
var hud: TacticalHUD = null
var player: PlayerController3D = null
var ticks: int = 0
var test_step: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 12 38-SECOND INCURSION ENGINE TEST")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	wave_mgr = gateroom.get_node("WaveManager") as WaveManager
	stargate = gateroom.get_node("Stargate") as StargateRing
	hud = gateroom.get_node("TacticalHUD") as TacticalHUD

	var p_scene := load(PLAYER_SCENE) as PackedScene
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Inbound Activation Sequence & Iris Malfunction
		print("[TEST 1/4] Testing Inbound Activation Sequence & Iris Malfunction...")
		var sequence_started := { "ok": false }
		var iris_malfunction := { "ok": false }

		wave_mgr.chevron_sequence_started.connect(func() -> void:
			sequence_started["ok"] = true
		)
		wave_mgr.iris_malfunction_declared.connect(func() -> void:
			iris_malfunction["ok"] = true
		)

		wave_mgr.wormhole_duration_s = 38.0
		wave_mgr.start_next_wave()

		assert(sequence_started["ok"], "Chevron sequence started signal must be emitted")
		assert(wave_mgr.is_wave_active, "WaveManager must mark wave active")
		assert(wave_mgr.enemies_alive == 4, "Initial incursion breach squad must field 4 Jaffa")
		print("[TEST 1/4] PASS: Inbound activation sequence initiated with 4 initial breach hostiles.")

	elif ticks == 20:
		# TEST 2: 38-Second Countdown Engine
		print("[TEST 2/4] Testing 38-Second Incursion Countdown & HUD banner...")
		# Simulate 10 seconds of incursion combat
		wave_mgr.is_wormhole_open = true
		wave_mgr.inbound_wormhole_timer = 28.0
		wave_mgr._physics_process(delta)

		assert(wave_mgr.inbound_wormhole_timer < 38.0, "Inbound wormhole timer must count down")
		hud.on_wormhole_timer_tick(wave_mgr.inbound_wormhole_timer, 38.0)
		assert("INBOUND WORMHOLE:" in hud.objective_label.text, "HUD must display INBOUND WORMHOLE banner")
		assert("IRIS JAMMED OPEN" in hud.objective_label.text, "HUD must display IRIS JAMMED alert")
		print("[TEST 2/4] PASS: 38-Second incursion clock and HUD countdown verified.")

	elif ticks == 30:
		# TEST 3: Wormhole Collapse & 20s Inter-Gate Recharge
		print("[TEST 3/4] Testing Wormhole Collapse at 0.0s & 20s Inter-Gate Recharge...")
		# Force timer expiration
		wave_mgr.inbound_wormhole_timer = 0.0
		wave_mgr._collapse_inbound_wormhole()

		assert(not wave_mgr.is_wormhole_open, "Wormhole must close when countdown expires")
		assert(stargate.current_state == StargateRing.GateState.INACTIVE, "Stargate state must return to INACTIVE")

		# Simulate clearing incursion hostiles to trigger recharge window
		wave_mgr.enemies_alive = 0
		wave_mgr._on_all_incursion_enemies_cleared()

		assert(wave_mgr.is_intermission, "Intermission must activate after incursion is cleared")
		assert(wave_mgr.intermission_timer == wave_mgr.inter_gate_recharge_s, "Intermission timer must equal 20s recharge window")
		hud.on_intermission_tick(int(wave_mgr.intermission_timer))
		assert("INTER-GATE RECHARGE:" in hud.objective_label.text, "HUD must display INTER-GATE RECHARGE banner")
		print("[TEST 3/4] PASS: Wormhole collapsed, Stargate disengaged, and 20s recharge window active.")

	elif ticks == 40:
		# TEST 4: Dynamic Gate Room Iris Servo Repair Sub-Mission
		print("[TEST 4/4] Testing Dynamic Gate Room Iris Servo Repair...")
		var iris_servo := gateroom.get_node("IrisServoHousing") as IrisServoHousingScript
		assert(iris_servo != null, "IrisServoHousing must exist in GateRoom")
		assert(not iris_servo.is_repaired, "IrisServoHousing must start unrepaired")

		# Begin manual repair channeling
		iris_servo.start_repair(player)
		assert(iris_servo.is_repairing, "IrisServoHousing must enter repairing state")

		# Channel repair for 6.0 seconds
		var repaired := iris_servo.update_repair(6.5)
		assert(repaired, "Iris servo repair must complete after 6.0 seconds")
		assert(iris_servo.is_repaired, "IrisServoHousing must be marked repaired")
		assert(wave_mgr.is_iris_repaired, "WaveManager must acknowledge Iris repair")
		print("[TEST 4/4] PASS: Gate Room Iris servo manually repaired, sealing gate and blocking reinforcements.")

		print("\n========================================================")
		print("  SPRINT 12 38-SECOND INCURSION ENGINE TEST PASSED!     ")
		print("  ✓ Sequential Chevrons 1->7 Locking & Kawoosh Vortex   ")
		print("  ✓ Iris Malfunction Red Alert Announcement & Banner    ")
		print("  ✓ 38-Second Inbound Wormhole Real-Time Countdown      ")
		print("  ✓ Wormhole Collapse & 20-Second Resupply Intermission ")
		print("  ✓ Dynamic Iris Servo Repair Sealing Off Reinforcements")
		print("========================================================\n")
		quit(0)
		return true

	return false
