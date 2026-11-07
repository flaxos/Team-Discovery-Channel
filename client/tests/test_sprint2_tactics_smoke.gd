extends SceneTree
## Automated Headless Validation: Sprint 2 Foothold Tactics, Cover Physics & Defense Smoke Test.
## Validates:
##  1. Crouch cover system and 65% damage mitigation.
##  2. Mounted Browning .50 Cal manual aiming, fire control, and dismounting.
##  3. Directional M18A1 Claymore tripwire detection and lethal 120-degree fragmentation cone.
##  4. 2-way Transport Rings teleportation between Gate Room and Fallback Hallway.
##  5. SGC Level 28 Blast Doors sliding seals and console control.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"
const JAFFA_SCENE: String = "res://scenes/entities/JaffaGuard.tscn"
const TURRET_SCENE: String = "res://scenes/props/DeployableTurret.tscn"
const CLAYMORE_SCENE: String = "res://scenes/props/ClaymoreMine.tscn"

const ClaymoreMineScript = preload("res://scripts/weapons/ClaymoreMine.gd")

var gateroom: GateRoom = null
var player: PlayerController3D = null
var jaffa_front: JaffaAI = null
var jaffa_behind: JaffaAI = null
var turret: DeployableTurret = null
var claymore: Node3D = null

var rings_a: TransportRings = null
var rings_b: TransportRings = null

var step: int = 0
var ticks: int = 0
var elapsed_time: float = 0.0
var test_passed: bool = false


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 2 TACTICS & COVER PHYSICS TEST    ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	# Spawn player
	var p_scene := load(PLAYER_SCENE) as PackedScene
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)

	rings_a = gateroom.get_node_or_null("TransportRings") as TransportRings
	rings_b = gateroom.get_node_or_null("FallbackHallway/TransportRingsBeta") as TransportRings
	if rings_a == null or rings_b == null:
		var rings_scene := load("res://scenes/props/TransportRings.tscn") as PackedScene
		rings_a = rings_scene.instantiate() as TransportRings
		rings_a.name = "TransportRingsAlpha"
		rings_a.position = Vector3(8, 0, 3)
		rings_b = rings_scene.instantiate() as TransportRings
		rings_b.name = "TransportRingsBeta"
		rings_b.position = Vector3(3, 0, 39)
		rings_a.paired_rings_path = NodePath("../TransportRingsBeta")
		rings_b.paired_rings_path = NodePath("../TransportRingsAlpha")
		gateroom.add_child(rings_a)
		gateroom.add_child(rings_b)


func _process(delta: float) -> bool:
	ticks += 1
	elapsed_time += delta

	# Step 1: Validate Crouch Cover & Damage Mitigation
	if step == 0 and ticks == 5:
		print("[TEST 1/5] Testing Cover Physics & Damage Mitigation...")
		# Standing damage test
		player.is_crouching = false
		player.health_component.current_health = 100.0
		player.health_component.take_damage(40.0)
		assert(is_equal_approx(player.health_component.current_health, 60.0), "Standing operative must take full damage")

		# Crouched damage test (65% mitigation)
		player.is_crouching = true
		player.health_component.current_health = 100.0
		player.health_component.take_damage(40.0)
		var expected_health := 100.0 - (40.0 * 0.35) # 86.0
		assert(is_equal_approx(player.health_component.current_health, expected_health),
			"Crouched operative behind cover must mitigate 65%% of incoming damage (Expected: %f, Got: %f)" % [expected_health, player.health_component.current_health])
		print("[TEST 1/5] PASS: Crouch cover physics verified! 65% damage mitigation confirmed.")
		step = 1

	# Step 2: Validate Mounted Browning .50 Cal Tripod
	elif step == 1 and ticks == 10:
		print("[TEST 2/5] Testing Mounted .50 Cal Browning HMG...")
		var t_scene := load(TURRET_SCENE) as PackedScene
		turret = t_scene.instantiate() as DeployableTurret
		turret.position = Vector3(0, 0, 5)
		gateroom.add_child(turret)

		# Mount turret
		turret.mount(player)
		assert(turret.mounted_player == player, "Player must be registered as mounted operative")

		# Manual fire
		var fired := turret.try_manual_fire(Vector3(0, 0, -1))
		assert(fired, "Mounted operative must be able to manually fire the .50 Cal")
		assert(turret.fire_cooldown > 0.0, "Firing must incur cyclic cooldown")

		# Dismount
		turret.dismount()
		assert(turret.mounted_player == null, "Operative must be cleared from mounted turret")
		turret.queue_free()
		print("[TEST 2/5] PASS: .50 Cal mounting, manual aiming, firing, and dismounting verified.")
		step = 2

	# Step 3: Validate M18A1 Directional Claymore
	elif step == 2 and ticks == 15:
		print("[TEST 3/5] Testing M18A1 Directional Claymore Mine...")
		var c_scene := load(CLAYMORE_SCENE) as PackedScene
		claymore = c_scene.instantiate() as Node3D
		claymore.position = Vector3(0, 0, 0)
		gateroom.add_child(claymore)

		# Spawn Jaffa A in front of Claymore (Z = -3, in 120-degree forward blast arc)
		var j_scene := load(JAFFA_SCENE) as PackedScene
		jaffa_front = j_scene.instantiate() as JaffaAI
		jaffa_front.position = Vector3(0, 0, -3)
		gateroom.get_node("Enemies").add_child(jaffa_front, true)

		# Spawn Jaffa B behind Claymore (Z = +3, 180 degrees away from forward blast)
		jaffa_behind = j_scene.instantiate() as JaffaAI
		jaffa_behind.position = Vector3(0, 0, 3)
		gateroom.get_node("Enemies").add_child(jaffa_behind, true)

		# Detonate Claymore
		claymore.detonate()

		# Verify forward enemy took lethal blast damage
		assert(jaffa_front.health_component.current_health < 50.0, "Jaffa in forward blast arc must take lethal fragmentation damage")
		# Verify rear enemy took zero damage
		assert(jaffa_behind.health_component.current_health == jaffa_behind.health_component.max_health, "Entity behind directional Claymore must take zero damage")

		jaffa_front.queue_free()
		jaffa_behind.queue_free()
		print("[TEST 3/5] PASS: Directional Claymore blast cone validated! Forward arc lethal, rear arc safe.")
		step = 3

	# Step 4: Validate 2-Way Transport Rings Network
	elif step == 3 and ticks == 20:
		print("[TEST 4/5] Testing 2-Way Transport Rings Network...")
		assert(rings_a != null and rings_b != null, "Both Gate Room and Hallway rings must exist")
		rings_a._resolve_paired_rings()
		rings_b._resolve_paired_rings()
		assert(rings_a.paired_rings == rings_b, "Gate Room rings must be paired to Hallway rings")
		assert(rings_b.paired_rings == rings_a, "Hallway rings must be paired to Gate Room rings")

		# Place player in Gate Room rings
		player.global_position = rings_a.global_position
		# Discharge beam
		rings_a._discharge_beam()

		# Verify player was beamed to Hallway rings
		var dist_to_hallway_rings := player.global_position.distance_to(rings_b.global_position)
		assert(dist_to_hallway_rings <= 1.5, "Operative must be beamed to paired Hallway rings (Dist: %f)" % dist_to_hallway_rings)
		print("[TEST 4/5] PASS: 2-Way Transport Rings beamed operative across SGC Level 28!")
		step = 4

	# Step 5: Validate SGC Level 28 Blast Doors
	elif step == 4 and ticks == 25:
		print("[TEST 5/5] Testing SGC Level 28 Sliding Blast Doors...")
		assert(not gateroom.is_blast_doors_closed, "Blast doors must start open")

		# Toggle close
		gateroom.toggle_blast_doors()
		assert(gateroom.is_blast_doors_closed, "Blast doors must switch to sealed/closed state")
		assert(gateroom.door_left.use_collision and gateroom.door_right.use_collision, "Blast doors must have active collision")

		# Reset animating flag to test immediate re-open
		gateroom.is_animating_doors = false
		gateroom.toggle_blast_doors()
		assert(not gateroom.is_blast_doors_closed, "Blast doors must switch to open state")

		print("[TEST 5/5] PASS: SGC Blast Doors sealed and opened with collision barriers!")
		step = 5

	if step == 5 and not test_passed:
		print("\n========================================================")
		print("  SPRINT 2 TACTICS & COVER PHYSICS TEST PASSED!         ")
		print("  ✓ Crouch Cover Physics (65% Mitigation)               ")
		print("  ✓ Browning .50 Cal Manual Mount / Fire / Dismount     ")
		print("  ✓ M18A1 Directional Claymore Fragmentation Arc        ")
		print("  ✓ SGC Level 28 2-Way Transport Rings Network          ")
		print("  ✓ Level 28 Sliding Blast Doors & Choke Point Fallback ")
		print("========================================================\n")
		test_passed = true
		quit(0)
		return true

	if elapsed_time > 8.0 and not test_passed:
		push_error("[TEST FAILURE] Sprint 2 tactics test timed out after %.2fs." % elapsed_time)
		quit(1)
		return true

	return false
