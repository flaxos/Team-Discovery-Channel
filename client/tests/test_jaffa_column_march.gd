extends SceneTree
## Test Suite: Jaffa Stargate 2-by-2 Column March Formation & Tactical Combat.
## Validates:
##  1. 2-by-2 spawning at the event horizon with correct lane offsets (X = -0.8m and X = +0.8m).
##  2. Cadenced streaming of subsequent ranks behind the lead pair.
##  3. Synchronized column marching down the ramp in State.MARCHING_FORMATION with weapons raised.
##  4. Transition to disciplined advance into the base at the base of the ramp (Gate Room center Z=0.0).
##  5. Front-rank crouching & return fire when engaged, with trailing ranks taking tactical cover/flanking.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const JAFFA_SCENE: String = "res://scenes/entities/JaffaGuard.tscn"

var gateroom: GateRoom = null
var wave_mgr: WaveManager = null
var enemies_container: Node3D = null
var players_container: Node3D = null
var target_dummy: CharacterBody3D = null

var ticks: int = 0
var test_step: int = 0
var bolt_fired: bool = false


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
	players_container = gateroom.get_node("Players") as Node3D
	assert(wave_mgr != null, "WaveManager must exist")
	assert(enemies_container != null, "Enemies container must exist")
	assert(players_container != null, "Players container must exist")


func _process(_delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: 2-by-2 Spawning at Event Horizon with Lane Offsets (X=-0.8 and X=+0.8)
		print("[TEST 1/5] Testing 2-by-2 Spawning at Event Horizon (Offsets X=-0.8m, X=+0.8m)...")
		wave_mgr.is_wave_active = true
		wave_mgr.is_wormhole_open = true
		wave_mgr.inbound_wormhole_timer = 38.0
		wave_mgr.current_wave = 1
		wave_mgr.rank_spawn_interval = 0.1

		# Request 4 Jaffa on the ramp (should spawn 2 ranks of 2)
		wave_mgr._spawn_wave_jaffa(4)

		var enemies: Array[Node] = enemies_container.get_children()
		assert(enemies.size() == 2, "First rank must spawn immediately as a pair of 2 (found %d)" % enemies.size())
		assert(wave_mgr.pending_column_spawns == 2, "Pending spawns must be 2 for trailing rank")

		var jaffa_left: JaffaAI = enemies[0] as JaffaAI
		var jaffa_right: JaffaAI = enemies[1] as JaffaAI
		assert(jaffa_left != null and jaffa_right != null, "Spawned enemies must be JaffaAI")

		# Check symmetrical positions around X = -0.8m and X = +0.8m
		assert(is_equal_approx(jaffa_left.position.x, -0.8), "Left Jaffa must spawn at lane X = -0.8m (got %.2f)" % jaffa_left.position.x)
		assert(is_equal_approx(jaffa_right.position.x, 0.8), "Right Jaffa must spawn at lane X = +0.8m (got %.2f)" % jaffa_right.position.x)
		assert(is_equal_approx(jaffa_left.position.z, -13.5), "Jaffa must spawn at Stargate event horizon Z = -13.5m (got %.2f)" % jaffa_left.position.z)
		assert(is_equal_approx(jaffa_right.position.z, -13.5), "Jaffa must spawn at Stargate event horizon Z = -13.5m (got %.2f)" % jaffa_right.position.z)

		# Check initial formation state & weapon visual
		assert(jaffa_left.current_state == JaffaAI.State.MARCHING_FORMATION, "Left Jaffa must initialize in MARCHING_FORMATION")
		assert(jaffa_right.current_state == JaffaAI.State.MARCHING_FORMATION, "Right Jaffa must initialize in MARCHING_FORMATION")
		assert(jaffa_left.is_front_rank and jaffa_right.is_front_rank, "First pair must be designated front rank")
		assert(jaffa_left.staff_mount.position.z < -0.3, "Left Jaffa must hold staff weapon raised in front")
		assert(jaffa_right.staff_mount.position.z < -0.3, "Right Jaffa must hold staff weapon raised in front")
		print("[TEST 1/5] PASS: First rank spawned at event horizon (X=-0.8m, X=+0.8m) with weapons raised.")
		print("[TEST 2/5] Testing Rank Cadence Spawner Interval (queued pending ranks)...")

	elif enemies_container.get_child_count() >= 4 and test_step == 0:
		test_step = 1
		print("[TEST 2/5] PASS: Trailing rank spawned cleanly behind lead rank after cadence interval.")
		var jaffa_trailing_left: JaffaAI = enemies_container.get_child(2) as JaffaAI
		var jaffa_trailing_right: JaffaAI = enemies_container.get_child(3) as JaffaAI
		assert(not jaffa_trailing_left.is_front_rank and not jaffa_trailing_right.is_front_rank, "Trailing ranks must not be marked front rank")
		assert(jaffa_trailing_left.formation_rank == 1 and jaffa_trailing_right.formation_rank == 1, "Trailing rank index must be 1")
		assert(is_equal_approx(jaffa_trailing_left.position.x, -0.8), "Trailing left Jaffa must spawn at X=-0.8m")
		assert(is_equal_approx(jaffa_trailing_right.position.x, 0.8), "Trailing right Jaffa must spawn at X=+0.8m")
		assert(jaffa_trailing_left.current_state == JaffaAI.State.MARCHING_FORMATION, "Trailing rank must also be in MARCHING_FORMATION")

		# TEST 3: Synchronized Column Marching down the ramp
		print("[TEST 3/5] Testing Synchronized Column Marching (march_speed = 2.4 m/s, lockstep)...")
		var jaffa_front_left: JaffaAI = enemies_container.get_child(0) as JaffaAI
		var jaffa_front_right: JaffaAI = enemies_container.get_child(1) as JaffaAI
		assert(jaffa_front_left.march_speed == 2.4 and jaffa_front_right.march_speed == 2.4, "March speed property must be 2.4 m/s")

		# Simulate physics march step
		jaffa_front_left._process_marching_formation(0.5)
		jaffa_front_right._process_marching_formation(0.5)

		assert(jaffa_front_left.velocity.z > 2.0, "Left Jaffa velocity.z must reach march_speed (got %.2f)" % jaffa_front_left.velocity.z)
		assert(jaffa_front_right.velocity.z > 2.0, "Right Jaffa velocity.z must reach march_speed (got %.2f)" % jaffa_front_right.velocity.z)
		assert(absf(jaffa_front_left.velocity.z - jaffa_front_right.velocity.z) < 0.05, "Left and Right Jaffa must advance in synchronized lockstep")
		assert(absf(jaffa_front_left.global_position.x - (-0.8)) < 0.05, "Left column must maintain X=-0.8m lane discipline")
		assert(absf(jaffa_front_right.global_position.x - 0.8) < 0.05, "Right column must maintain X=+0.8m lane discipline")
		assert(jaffa_front_left.staff_mount.position.z < -0.3, "Staff mount must be held raised ready in front")
		print("[TEST 3/5] PASS: Synchronized column marching down ramp at 2.4 m/s lockstep with staff weapons raised.")

		# TEST 4: Transition to Disciplined Advance at Base of Ramp
		print("[TEST 4/5] Testing Transition to Disciplined Advance at Gate Room center (Z=0.0)...")
		# Move right Jaffa to the base of the ramp
		jaffa_front_right.global_position.z = 0.1
		jaffa_front_right._process_marching_formation(0.1)

		assert(jaffa_front_right.current_state == JaffaAI.State.ADVANCE, "Must transition to State.ADVANCE at base of ramp")
		assert(jaffa_front_right.staff_mount.position.x > 0.2, "Staff weapon must reset to advance carry posture at side")

		# Advance steadily into base preserving tactical lane cohesion
		jaffa_front_right._process_advance_state(0.5)
		assert(jaffa_front_right.velocity.z > 1.5, "Must steadily advance into the base (velocity.z = %.2f)" % jaffa_front_right.velocity.z)
		print("[TEST 4/5] PASS: Transitioned to State.ADVANCE at base of ramp, steadily advancing into base with tactical lane cohesion.")

		# TEST 5: Front-Rank Crouching & Return Fire when Engaged
		print("[TEST 5/5] Testing Front Rank Crouching & Return Fire when engaged...")
		var jaffa_front: JaffaAI = enemies_container.get_child(0) as JaffaAI
		var jaffa_trailing: JaffaAI = enemies_container.get_child(2) as JaffaAI

		# Spawn target operative downrange
		target_dummy = CharacterBody3D.new()
		target_dummy.name = "MockPlayer_1"
		var col := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		col.shape = shape
		target_dummy.add_child(col)

		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.max_health = 100.0
		health.current_health = 100.0
		target_dummy.add_child(health)

		players_container.add_child(target_dummy)
		target_dummy.global_position = Vector3(0.0, 0.0, 6.0)

		# Connect to staff_fired signal to track plasma discharge
		jaffa_front.staff_fired.connect(func(_pos: Vector3, _dir: Vector3) -> void:
			bolt_fired = true
		)

		# Front rank engages target
		jaffa_front.current_target = target_dummy
		jaffa_front.break_formation_and_engage()

		assert(jaffa_front.current_state == JaffaAI.State.COMBAT, "Front rank must enter COMBAT state when engaged")
		assert(jaffa_front.is_crouching, "Front rank must crouch down into suppressive firing posture")
		assert(Vector2(jaffa_front.velocity.x, jaffa_front.velocity.z).length() < 0.1, "Front rank must halt horizontal velocity")

		# Alert nearby squad mates
		jaffa_front._alert_nearby_formation_jaffa()
		assert(jaffa_trailing.current_state == JaffaAI.State.COVER, "Trailing rank must take cover/flank when squad engaged")
		assert(not jaffa_trailing.is_crouching, "Trailing rank must sprint upright to cover")

		# Fire staff weapon
		jaffa_front.fire_timer = 0.05
		jaffa_front._process_combat_state(0.1)
		assert(bolt_fired, "Front rank Jaffa must discharge staff plasma bolt return fire!")
		print("[TEST 5/5] PASS: Front rank halted, crouched, and unleashed return staff fire; rear ranks took cover.")

		print("\n========================================================")
		print("  JAFFA 2-BY-2 COLUMN MARCH FORMATION TEST PASSED!      ")
		print("  ✓ 2-by-2 Spawning at Event Horizon (X=-0.8m, +0.8m)   ")
		print("  ✓ Cadenced Streaming of Subsequent Ranks              ")
		print("  ✓ Synchronized March at 2.4 m/s (Lockstep, Staff Up)  ")
		print("  ✓ Transition to Disciplined Advance at Base of Ramp   ")
		print("  ✓ Front Rank Halt, Crouch & Suppressive Return Fire   ")
		print("  ✓ Trailing Rank Tactical Cover & Corridor Flanking    ")
		print("========================================================\n")

		for child in root.get_children():
			child.free()
		quit(0)
		return true

	if ticks > 60:
		push_error("[TEST FAILURE] Jaffa column march test timed out.")
		if is_instance_valid(gateroom):
			gateroom.free()
		quit(1)
		return true

	return false
