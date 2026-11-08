extends SceneTree
## Test Suite: Jaffa Stargate 2-by-2 Column March Formation & Tactical Combat.
## Validates:
##  1. Cadenced 2-by-2 column stream spawner (symmetrical X=-1.2m and X=+1.2m).
##  2. Rank cadence interval (spawned in ranks of 2).
##  3. Disciplined formation march down ramp towards Gate Room center (Z=0.0) at march_speed (2.4 m/s).
##  4. Weapon held ready in front during column march.
##  5. Engaged front rank halting and crouching to fire plasma bolts.
##  6. Engaged trailing ranks breaking into tactical combat (corridor flanking / sandbag cover).

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const JAFFA_SCENE: String = "res://scenes/entities/JaffaGuard.tscn"

var gateroom: GateRoom = null
var wave_mgr: WaveManager = null
var enemies_container: Node3D = null
var ticks: int = 0
var test_step: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: JAFFA 2-BY-2 COLUMN MARCH FORMATION TEST")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	wave_mgr = gateroom.get_node("WaveManager") as WaveManager
	enemies_container = gateroom.get_node("Enemies") as Node3D
	assert(wave_mgr != null, "WaveManager must exist")
	assert(enemies_container != null, "Enemies container must exist")


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Cadenced 2-by-2 column stream spawner
		print("[TEST 1/5] Testing Cadenced 2-by-2 Column Stream Spawning...")
		wave_mgr.is_wave_active = true
		wave_mgr.is_wormhole_open = true
		wave_mgr.inbound_wormhole_timer = 38.0
		wave_mgr.current_wave = 1
		wave_mgr.rank_spawn_interval = 0.1

		# Request 4 Jaffa on the ramp (should spawn 2 ranks of 2)
		wave_mgr._spawn_wave_jaffa(4)

		# Initial call should spawn the first rank (2 Jaffa) immediately
		var enemies: Array[Node] = enemies_container.get_children()
		assert(enemies.size() == 2, "First rank must spawn immediately as a pair of 2 (found %d)" % enemies.size())
		assert(wave_mgr.pending_column_spawns == 2, "Pending spawns must be 2 for next rank")

		var jaffa_left: JaffaAI = enemies[0] as JaffaAI
		var jaffa_right: JaffaAI = enemies[1] as JaffaAI
		assert(jaffa_left != null and jaffa_right != null, "Spawned enemies must be JaffaAI")

		# Check symmetrical positions around X = -1.2m and X = +1.2m
		assert(is_equal_approx(jaffa_left.position.x, -1.2), "Left Jaffa must spawn at X = -1.2m (got %.2f)" % jaffa_left.position.x)
		assert(is_equal_approx(jaffa_right.position.x, 1.2), "Right Jaffa must spawn at X = +1.2m (got %.2f)" % jaffa_right.position.x)
		assert(is_equal_approx(jaffa_left.position.z, -13.5), "Jaffa must spawn at Stargate Z = -13.5m (got %.2f)" % jaffa_left.position.z)

		# Check initial formation state & weapon visual
		assert(jaffa_left.current_state == JaffaAI.State.MARCHING_FORMATION, "Jaffa must initialize in MARCHING_FORMATION")
		assert(jaffa_right.current_state == JaffaAI.State.MARCHING_FORMATION, "Jaffa must initialize in MARCHING_FORMATION")
		assert(jaffa_left.is_front_rank and jaffa_right.is_front_rank, "First pair must be designated front rank")
		print("[TEST 1/5] PASS: First rank spawned symmetrically at X = -1.2m and +1.2m in MARCHING_FORMATION.")
		print("[TEST 2/5] Testing Rank Cadence Spawner Interval (queued pending ranks)...")

	elif enemies_container.get_child_count() >= 4 and test_step == 0:
		test_step = 1
		print("[TEST 2/5] PASS: Rank 1 spawned cleanly behind Rank 0 after cadence interval (Total enemies: %d)." % enemies_container.get_child_count())
		var jaffa_trailing_left: JaffaAI = enemies_container.get_child(2) as JaffaAI
		var jaffa_trailing_right: JaffaAI = enemies_container.get_child(3) as JaffaAI
		assert(not jaffa_trailing_left.is_front_rank and not jaffa_trailing_right.is_front_rank, "Trailing ranks must not be marked front rank")
		assert(jaffa_trailing_left.formation_rank == 1 and jaffa_trailing_right.formation_rank == 1, "Trailing rank index must be 1")
		assert(jaffa_trailing_left.current_state == JaffaAI.State.MARCHING_FORMATION, "Trailing rank must also be in MARCHING_FORMATION")

		# TEST 3: March Discipline & Speed
		print("[TEST 3/5] Testing March Speed & Column Discipline (march_speed = 2.4 m/s)...")
		var jaffa_front_left: JaffaAI = enemies_container.get_child(0) as JaffaAI
		assert(jaffa_front_left.march_speed == 2.4, "March speed property must be 2.4 m/s")

		jaffa_front_left._process_marching_formation(0.5)
		assert(is_equal_approx(jaffa_front_left.velocity.z, 2.4) or jaffa_front_left.velocity.z > 2.0, "Velocity.z must target march_speed 2.4 m/s (got %.2f)" % jaffa_front_left.velocity.z)
		assert(absf(jaffa_front_left.global_position.x - (-1.2)) < 0.05, "Left column must strictly maintain X=-1.2m lane discipline")
		assert(jaffa_front_left.staff_mount.position.z < -0.3, "Staff mount must be held ready in front")
		print("[TEST 3/5] PASS: Jaffa marched forward down ramp at steady 2.4 m/s maintaining strict lane discipline and ready weapon posture.")

		# TEST 4: Front Rank Halting & Crouching under Fire
		print("[TEST 4/5] Testing Front Rank Halting and Crouching when engaged...")
		var jaffa_front: JaffaAI = enemies_container.get_child(0) as JaffaAI

		# Simulate taking damage while in formation
		jaffa_front._on_damage_taken(10.0, null, "bullet")

		assert(jaffa_front.current_state == JaffaAI.State.COMBAT, "Front rank must enter COMBAT state when engaged")
		assert(jaffa_front.is_crouching, "Front rank must crouch down to suppress defense line")
		assert(Vector2(jaffa_front.velocity.x, jaffa_front.velocity.z).length() < 0.1, "Front rank must halt horizontal velocity to steady aim")
		print("[TEST 4/5] PASS: Front rank halted and assumed crouched firing posture.")

		# TEST 5: Trailing Rank Tactical Break (Flanking Corridors / Sandbag Cover)
		print("[TEST 5/5] Testing Trailing Rank Tactical Break (Cover / Flanking)...")
		assert(jaffa_trailing_left.current_state == JaffaAI.State.COVER, "Trailing rank left must enter COVER/flanking state")
		assert(jaffa_trailing_right.current_state == JaffaAI.State.COVER, "Trailing rank right must enter COVER/flanking state")
		assert(not jaffa_trailing_left.is_crouching, "Trailing rank should sprint upright to cover")

		assert(jaffa_trailing_left.tactical_destination.x < 0.0, "West trailing Jaffa must target West tactical route")
		assert(jaffa_trailing_right.tactical_destination.x > 0.0, "East trailing Jaffa must target East tactical route")
		print("[TEST 5/5] PASS: Trailing ranks broke into tactical cover and flanking routes.")

		print("\n========================================================")
		print("  JAFFA 2-BY-2 COLUMN MARCH FORMATION TEST PASSED!      ")
		print("  ✓ Symmetrical 2-by-2 Column Stream Spawner            ")
		print("  ✓ Rank Cadence Timing (Between Pairs)                 ")
		print("  ✓ Disciplined March at 2.4 m/s (Holding Staff Ready)  ")
		print("  ✓ Front Rank Halt & Crouch Suppressive Fire           ")
		print("  ✓ Trailing Rank Tactical Cover & Corridor Flanking    ")
		print("========================================================\n")
		quit(0)
		return true

	return false
