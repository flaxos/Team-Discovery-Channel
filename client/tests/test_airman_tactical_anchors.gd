extends SceneTree
## Tactical Airmen AI Verification Suite: Corner Holding, .50 Cal Mounting,
## Suppressive Hallway Fire & Player-Led Leapfrogging.
## Validates:
##  1. Corner Holding & Tactical Cover: Anchor occupation, crouch stance, peek-to-suppress, 65% cover mitigation.
##  2. .50 Cal Turret Mounting: Tactical 8.0m reach auto-mount, 65% gun shield armor, heavy suppressive fire, polite player yielding.
##  3. Suppressive Hallway Fire: Controlled MP5 hallway bursts, tracer emission, hallway suppression signals.
##  4. Player-Led Progression: Airmen hold positions and do NOT rush uncleared rooms ahead of human pointman.
##  5. Bounding Overwatch / Leapfrogging: One airman advances while the other provides cover fire, then roles switch upon arrival.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"
const AIRMAN_SCENE: String = "res://scenes/entities/SGCAirman.tscn"
const JAFFA_SCENE: String = "res://scenes/entities/JaffaGuard.tscn"

const SGCAirmanAIScript = preload("res://scripts/entities/SGCAirmanAI.gd")
const DeployableTurretScript = preload("res://scripts/weapons/DeployableTurret.gd")

var gateroom: GateRoom = null
var player: PlayerController3D = null
var airman_davis: SGCAirmanAI = null
var airman_siler: SGCAirmanAI = null
var turret_west: DeployableTurret = null
var ticks: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: TACTICAL AIRMEN AI & LEAPFROGGING TEST  ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	turret_west = gateroom.find_child("TurretWest", true, false) as DeployableTurret
	assert(turret_west != null, "TurretWest must exist in GateRoom")

	# Setup Player
	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)
	player.global_position = Vector3(0.0, 0.1, 4.0) # In Gate Room

	# Setup 2 Allied Airmen (Davis and Siler)
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


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# ========================================================
		# TEST 1: Corner Holding & Tactical Cover
		# ========================================================
		print("[TEST 1/5] Testing Tactical Corner Holding & Auto-Cover Stance...")
		var corner_anchor := Vector3(-5.0, 0.1, 5.8)
		var face_dir := Vector3(0.0, 0.0, -1.0) # Facing Gate ramp

		var corner_held_signaled: Array[bool] = [false]
		airman_davis.corner_held.connect(func(a: SGCAirmanAI, pos: Vector3) -> void:
			if pos.distance_to(corner_anchor) < 0.01:
				corner_held_signaled[0] = true
		)

		airman_davis.hold_corner(corner_anchor, face_dir, "sandbag")

		assert(airman_davis.current_state == SGCAirmanAIScript.State.HOLD_CORNER, "Airman must enter HOLD_CORNER state")
		assert(airman_davis.is_in_cover, "Airman must be marked as in cover")
		assert(airman_davis.is_crouching, "Airman must adopt crouching stance behind corner cover")
		assert(not airman_davis.is_peeking, "Airman must not be peeking while resting behind cover")
		assert(airman_davis.body_mesh != null and is_equal_approx(airman_davis.body_mesh.scale.y, 0.65), "Body mesh must scale down to crouch height (0.65)")
		assert(corner_held_signaled[0], "corner_held signal must emit with anchor position")

		# Test 65% cover damage mitigation
		var hp_before: float = airman_davis.health_component.current_health
		airman_davis.health_component.take_damage(100.0, null, "plasma")
		var dmg_taken: float = hp_before - airman_davis.health_component.current_health
		assert(is_equal_approx(dmg_taken, 35.0), "Airman crouching behind cover must mitigate 65%% damage (expected 35.0 dmg, got %.1f)" % dmg_taken)

		# Heal airman back to full
		airman_davis.health_component.heal(100.0)
		print("[TEST 1/5] PASS: Tactical Corner Holding, crouch stance, and 65% cover mitigation verified.")

	elif ticks == 4:
		# ========================================================
		# TEST 2: .50 Cal Turret Mounting, Gun Shield & Polite Yielding
		# ========================================================
		print("[TEST 2/5] Testing .50 Cal Browning Mounting, Gun Shield Armor & Player Yielding...")
		assert(turret_west.is_in_group("turret") and turret_west.is_in_group("mounted_turret"), "Turret must belong to 'turret' and 'mounted_turret' groups")
		assert(turret_west.mounted_player == null, "TurretWest must start uncrewed")

		# Position airman near TurretWest (~3.0m away)
		airman_davis.global_position = turret_west.global_position + Vector3(2.5, 0.0, 0.0)
		airman_davis.current_state = SGCAirmanAIScript.State.COMBAT

		# Trigger physics update: airman must detect turret within tactical reach (~8.0m) and move to mount
		airman_davis._physics_process(0.016)
		assert(airman_davis.current_state == SGCAirmanAIScript.State.MOVE_TO_TURRET or airman_davis.current_state == SGCAirmanAIScript.State.MAN_TURRET,
			"Airman within 8.0m must move to mount or man available .50 Cal turret")

		# Mount the turret directly
		airman_davis.mount_turret(turret_west)
		assert(airman_davis.current_state == SGCAirmanAIScript.State.MAN_TURRET, "Airman must enter MAN_TURRET state")
		assert(turret_west.mounted_player == airman_davis, "TurretWest mounted_player must be airman")
		assert(airman_davis.mounted_turret == turret_west, "Airman mounted_turret must be TurretWest")

		# Test 65% gun shield damage mitigation while mounted
		var hp_before_shield: float = airman_davis.health_component.current_health
		airman_davis.health_component.take_damage(100.0, null, "plasma")
		var shield_dmg: float = hp_before_shield - airman_davis.health_component.current_health
		assert(is_equal_approx(shield_dmg, 35.0), "Airman behind .50 Cal gun shield must mitigate 65%% damage (expected 35.0, got %.1f)" % shield_dmg)
		airman_davis.health_component.heal(100.0)

		# Spawn target Jaffa down the ramp: turret must fire heavy .50 cal suppressive fire
		var jaffa_scene := load(JAFFA_SCENE) as PackedScene
		var test_jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		gateroom.get_node("Enemies").add_child(test_jaffa)
		test_jaffa.global_position = Vector3(0.0, 0.1, -1.0) # On Gate Room floor in line of sight
		turret_west.fire_cooldown = 0.0

		var turret_fired_received: Array[bool] = [false]
		airman_davis.hallway_suppressed.connect(func(a: SGCAirmanAI, dir: Vector3) -> void:
			turret_fired_received[0] = true
		)

		airman_davis._process_turret(0.016)
		assert(turret_fired_received[0], "Airman manning .50 Cal must fire suppressive rounds at incoming Jaffa")

		# Polite Yielding: Human player approaches within 2.0m of turret
		player.global_position = turret_west.global_position + Vector3(0.0, 0.0, 1.5)
		airman_davis._process_turret(0.016)
		assert(turret_west.mounted_player == null, "Airman must politely yield and dismount when human player approaches within 2.2m")
		assert(airman_davis.current_state == SGCAirmanAIScript.State.COMBAT, "Airman must return to COMBAT state after yielding turret")

		test_jaffa.queue_free()
		print("[TEST 2/5] PASS: .50 Cal auto-mount within 8.0m, gun shield armor, heavy fire, and player yielding verified.")

	elif ticks == 6:
		# ========================================================
		# TEST 3: Suppressive Hallway Fire & Peek-and-Duck Cycles
		# ========================================================
		print("[TEST 3/5] Testing Suppressive Hallway Fire & Peek-to-Suppress Cadence...")
		var hallway_anchor := Vector3(0.0, 0.1, 1.8)
		var hallway_dir := Vector3(0.0, 0.0, -1.0)
		airman_davis.hold_corner(hallway_anchor, hallway_dir, "sandbag")

		var suppressed_dirs: Array[Vector3] = []
		airman_davis.hallway_suppressed.connect(func(a: SGCAirmanAI, dir: Vector3) -> void:
			suppressed_dirs.append(dir)
		)

		# Lay down suppressive hallway fire down the corridor
		airman_davis.suppress_hallway(hallway_dir, 2.0)
		assert(airman_davis.is_suppressing, "Airman must enter suppressing state")
		assert(airman_davis.is_peeking, "Airman must elevate to peeking stance to lay down suppressive fire")
		assert(suppressed_dirs.size() > 0 and suppressed_dirs[0].is_equal_approx(hallway_dir), "Airman must lay down suppressive fire in hallway corridor direction")

		# Clear previous active suppression command before testing Jaffa peek-and-duck cycle
		airman_davis.is_suppressing = false
		airman_davis.suppress_timer = 0.0

		# Spawn Jaffa in combat line of sight to verify peek-and-duck cycle
		var jaffa_scene := load(JAFFA_SCENE) as PackedScene
		var jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		gateroom.get_node("Enemies").add_child(jaffa)
		jaffa.global_position = Vector3(0.0, 0.1, -1.0) # In open Gate Room floor with clear line of sight

		# Peek phase
		airman_davis.peek_timer = 0.5
		airman_davis._process_hold_corner(0.1)
		assert(airman_davis.is_peeking, "During peek phase (0.5s < 1.2s), Airman must peek over cover to return fire")
		assert(airman_davis.body_mesh.scale.y == 1.0, "Body mesh must be fully upright while peeking")

		# Duck phase
		airman_davis.peek_timer = 1.5 # Past peeking_burst_duration (1.2s)
		airman_davis._process_hold_corner(0.1)
		assert(not airman_davis.is_peeking and airman_davis.is_crouching, "During duck phase (1.5s > 1.2s), Airman must crouch back behind cover")
		assert(is_equal_approx(airman_davis.body_mesh.scale.y, 0.65), "Body mesh must crouch back down to 0.65")

		jaffa.queue_free()
		print("[TEST 3/5] PASS: Suppressive Hallway Fire and peek-and-duck cycles verified.")

	elif ticks == 8:
		# ========================================================
		# TEST 4: Player-Led Progression (Human Pointman Gate)
		# ========================================================
		print("[TEST 4/5] Testing Player-Led Progression (Waiting for Human Pointman)...")
		# Position Airmen in Gate Room at defense line
		airman_davis.hold_corner(Vector3(-5.0, 0.1, 5.8), Vector3(0.0, 0.0, -1.0))
		airman_siler.hold_corner(Vector3(2.5, 0.1, 5.8), Vector3(0.0, 0.0, -1.0))

		# Case A: Human player is still in the current room (GATE_ROOM). Airmen MUST NOT advance alone!
		player.global_position = Vector3(0.0, 0.1, 4.0) # Player in Gate Room
		airman_davis._check_player_led_progression()
		airman_siler._check_player_led_progression()

		assert(airman_davis.current_state == SGCAirmanAIScript.State.HOLD_CORNER, "Davis must hold corner and wait for human pointman to lead")
		assert(airman_siler.current_state == SGCAirmanAIScript.State.HOLD_CORNER, "Siler must hold corner and wait for human pointman to lead")

		# Case B: Human player advances into forward room (CONTROL_ROOM), BUT uncleared enemies remain in current corridor!
		player.global_position = Vector3(0.0, 0.1, 15.0) # Player in Control Room
		var jaffa_scene := load(JAFFA_SCENE) as PackedScene
		var hostile_jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		gateroom.get_node("Enemies").add_child(hostile_jaffa)
		hostile_jaffa.global_position = Vector3(0.0, 0.1, 0.0) # In Gate Room corridor

		airman_davis._check_player_led_progression()
		assert(airman_davis.current_state == SGCAirmanAIScript.State.HOLD_CORNER,
			"Airmen must NOT rush forward into next room while current corridor has active hostiles!")

		hostile_jaffa.queue_free()
		print("[TEST 4/5] PASS: Player-led progression verified. Airmen hold corners and do not advance alone.")

	elif ticks == 10:
		# ========================================================
		# TEST 5: Bounding Overwatch / Leapfrogging Progression
		# ========================================================
		print("[TEST 5/5] Testing Bounding Overwatch / Fireteam Leapfrogging...")
		# Setup: Player has advanced into CONTROL_ROOM and cleared GATE_ROOM
		player.global_position = Vector3(5.0, 0.1, 14.0)
		airman_davis.hold_corner(Vector3(-5.0, 0.1, 5.8), Vector3(0.0, 0.0, -1.0))
		airman_siler.hold_corner(Vector3(2.5, 0.1, 5.8), Vector3(0.0, 0.0, -1.0))

		# Corridor is secured! Trigger leapfrog progression
		airman_davis._on_player_secured_hallway("CONTROL_ROOM")

		# One airman bounds forward while the other covers the movement
		var one_bounding: bool = (airman_davis.current_state == SGCAirmanAIScript.State.LEAPFROG_ADVANCE and airman_siler.current_state == SGCAirmanAIScript.State.COVER_FIRE) or \
			(airman_siler.current_state == SGCAirmanAIScript.State.LEAPFROG_ADVANCE and airman_davis.current_state == SGCAirmanAIScript.State.COVER_FIRE)
		assert(one_bounding, "One airman must enter LEAPFROG_ADVANCE while fireteam partner provides COVER_FIRE")

		var bounder: SGCAirmanAI = airman_davis if airman_davis.is_leapfrogging_advancing else airman_siler
		var overwatch: SGCAirmanAI = airman_siler if bounder == airman_davis else airman_davis

		assert(bounder.is_leapfrogging_advancing, "Bounder must be marked as advancing")
		assert(overwatch.is_providing_cover_fire, "Overwatch partner must be marked as providing cover fire")
		assert(overwatch.is_peeking, "Overwatch partner must have weapon raised ready to suppress")

		# Simulate Bounder reaching the forward tactical anchor
		bounder.global_position = bounder.target_advance_position
		bounder._process_leapfrog_advance(0.016)

		assert(bounder.current_state == SGCAirmanAIScript.State.HOLD_CORNER, "Bounder must enter HOLD_CORNER upon reaching forward anchor")
		assert(bounder.is_in_cover and bounder.is_crouching, "Bounder must take cover at new forward anchor")
		assert(not bounder.is_leapfrogging_advancing, "Bounder advance flag must reset")

		# Trailing airman now leaps forward
		overwatch._process_cover_fire(0.016)
		assert(overwatch.current_state == SGCAirmanAIScript.State.LEAPFROG_ADVANCE, "Trailing airman must now leapfrog forward to join forward line")
		assert(overwatch.is_leapfrogging_advancing, "Trailing airman must be actively bounding")

		# Trailing airman reaches their forward anchor
		overwatch.global_position = overwatch.target_advance_position
		overwatch._process_leapfrog_advance(0.016)
		assert(overwatch.current_state == SGCAirmanAIScript.State.HOLD_CORNER, "Trailing airman must also secure and hold forward corner")

		print("[TEST 5/5] PASS: Fireteam Bounding Overwatch and Leapfrogging successfully coordinated.")

		print("\n========================================================")
		print("  ALL TACTICAL AIRMEN AI TESTS PASSED!                  ")
		print("  ✓ Tactical Corner Holding & Auto-Cover Stance         ")
		print("  ✓ .50 Cal Browning Mounting & Gun Shield Protection   ")
		print("  ✓ Polite Turret Yielding to Approaching Player        ")
		print("  ✓ Suppressive Hallway Fire & Peek-and-Duck Cycles     ")
		print("  ✓ Player-Led Progression (Human Pointman Waiting)     ")
		print("  ✓ Tactical Leapfrogging (Bounding Overwatch)          ")
		print("========================================================\n")
		quit(0)
		return true

	return false
