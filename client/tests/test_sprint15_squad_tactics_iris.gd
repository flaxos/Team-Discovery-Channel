extends SceneTree
## Sprint 15 Verification Suite: Squad Quick-Ping Commands, Deployable Ballistic Shields,
## M18 Smoke Grenades & Segmented 3-Stage Iris Repair under Fire.
## Validates:
##  1. Deployable Ballistic Shield: Field placement, 600 HP, auto-cover & peek-to-shoot integration.
##  2. M18 Smoke Grenades: Canister throw, 4.5m cloud detonation, Jaffa line-of-sight occlusion.
##  3. Contextual Squad Quick-Ping: Move/Cover, Mount Turret, Revive Downed Ally, and Regroup orders.
##  4. Segmented 3-Stage Iris Repair: 33% / 66% checkpoint persistence across combat interruptions, 100% lock.
##  5. Armory Munitions Restock: Shields and smoke replenished at armory crates.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"
const AIRMAN_SCENE: String = "res://scenes/entities/SGCAirman.tscn"

const SGCAirmanAIScript = preload("res://scripts/entities/SGCAirmanAI.gd")
const DeployableShieldScript = preload("res://scripts/props/DeployableShield.gd")
const SmokeGrenadeScript = preload("res://scripts/weapons/SmokeGrenade.gd")
const IrisServoHousingScript = preload("res://scripts/props/IrisServoHousing.gd")
const ArmoryResupplyStationScript = preload("res://scripts/props/ArmoryResupplyStation.gd")

var gateroom: GateRoom = null
var player: PlayerController3D = null
var airman: SGCAirmanAIScript = null
var turret_west: DeployableTurret = null
var iris_servo: IrisServoHousingScript = null
var hud: TacticalHUD = null
var ticks: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 15 SQUAD TACTICS & IRIS REPAIR TEST")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	turret_west = gateroom.find_child("TurretWest", true, false) as DeployableTurret
	iris_servo = gateroom.find_child("IrisServoHousing", true, false) as IrisServoHousingScript
	hud = gateroom.get_node_or_null("TacticalHUD") as TacticalHUD

	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
	gateroom.get_node("Players").add_child(player, true)

	var allies := gateroom.get_node_or_null("Allies") as Node3D
	if allies != null and allies.get_child_count() > 0:
		airman = allies.get_child(0) as SGCAirmanAIScript
	else:
		var a_scene := load(AIRMAN_SCENE) as PackedScene
		airman = a_scene.instantiate() as SGCAirmanAIScript
		root.add_child(airman)


func _process(delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# ========================================================
		# TEST 1: Deployable Ballistic Shield & Cover Integration
		# ========================================================
		print("[TEST 1/5] Testing Deployable Ballistic Shield Field Placement & Cover Integration...")
		assert(player.deployable_shields_count == 1, "Player must spawn with 1 Deployable Ballistic Shield")

		player.global_position = Vector3(10.0, 0.1, 10.0)
		player.rotation = Vector3.ZERO
		player.deploy_shield()

		assert(player.deployable_shields_count == 0, "Deployable shield count must decrement to 0 after placement")

		# Find the placed shield
		var shield: DeployableShieldScript = null
		for node in root.find_children("*", "", true, false):
			if node is DeployableShieldScript:
				shield = node as DeployableShieldScript
				break
		assert(shield != null, "DeployableShield instance must be spawned in scene tree")
		assert(shield.is_in_group("cover"), "DeployableShield must belong to 'cover' group")
		assert(shield.health_component != null and is_equal_approx(shield.health_component.max_health, 600.0), "Shield must have 600.0 HP durability")

		# Position player right behind the deployed shield (0.8m behind)
		player.global_position = shield.global_position + Vector3(0, 0, 0.8)
		player._process_cover_and_peeking(0.1, Vector3.ZERO)

		assert(player.is_in_cover, "Player must auto-detect cover behind newly placed DeployableShield")
		assert(player.is_crouching, "Player must crouch behind DeployableShield")

		# Peek-to-Shoot over shield
		player.is_aiming_down_sights = true
		player._process_cover_and_peeking(0.1, Vector3.ZERO)
		assert(player.is_peeking, "Player must elevate to peeking stance when aiming over DeployableShield")
		player.is_aiming_down_sights = false

		# Shield durability & destruction
		shield.health_component.take_damage(650.0, null, "plasma")
		assert(shield.health_component.is_dead, "Shield must be destroyed by lethal damage")

		print("[TEST 1/5] PASS: Deployable Ballistic Shield placement, auto-cover, and peek-to-shoot verified.")

	elif ticks == 4:
		# ========================================================
		# TEST 2: M18 Smoke Grenade & Jaffa Line-of-Sight Occlusion
		# ========================================================
		print("[TEST 2/5] Testing M18 Smoke Grenade Canister Throw & Jaffa LOS Occlusion...")
		assert(player.smoke_grenades_count == 2, "Player must spawn with 2 M18 Smoke Grenades")

		player.global_position = Vector3(0.0, 0.1, 0.0)
		player.throw_smoke_grenade()
		assert(player.smoke_grenades_count == 1, "Smoke grenade count must decrement to 1")

		var grenade: SmokeGrenadeScript = null
		for node in root.find_children("*", "", true, false):
			if node is SmokeGrenadeScript:
				grenade = node as SmokeGrenadeScript
				break
		assert(grenade != null, "SmokeGrenade instance must exist in world")

		# Detonate grenade
		grenade.global_position = Vector3(0.0, 0.1, 5.0)
		grenade._detonate()
		assert(grenade.is_detonated, "SmokeGrenade must be detonated")
		assert(grenade.cloud_area != null and grenade.cloud_area.is_in_group("smoke_cloud"), "SmokeCloudArea must be in 'smoke_cloud' group")

		# Create a Jaffa and test LOS ray occlusion through the smoke cloud
		var jaffa_scene := load("res://scenes/entities/JaffaGuard.tscn") as PackedScene
		var jaffa: JaffaAI = jaffa_scene.instantiate() as JaffaAI
		root.add_child(jaffa)
		jaffa.global_position = Vector3(0.0, 0.1, 12.0) # Jaffa is at Z=12, Smoke is at Z=5, Player is at Z=0

		var is_obscured := jaffa._is_target_obscured_by_smoke(player.global_position)
		assert(is_obscured, "Ray between Jaffa (Z=12) and Player (Z=0) passing through Smoke (Z=5) must be OBSCURED")

		var has_los := jaffa._has_line_of_sight(player)
		assert(not has_los, "Jaffa line of sight must be completely blocked by active smoke cloud")

		# Move player sideways outside the 4.5m smoke radius
		var clear_pos := Vector3(14.0, 0.1, 0.0)
		assert(not jaffa._is_target_obscured_by_smoke(clear_pos), "Target position outside smoke radius must NOT be obscured")

		jaffa.queue_free()
		grenade.queue_free()
		print("[TEST 2/5] PASS: M18 Smoke Grenade 4.5m cloud detonation and Jaffa LOS occlusion verified.")

	elif ticks == 6:
		# ========================================================
		# TEST 3: Contextual Squad Quick-Ping Command System
		# ========================================================
		print("[TEST 3/5] Testing Contextual Squad Quick-Ping Command System ([Q] / Middle-Click)...")
		assert(airman != null, "Allied SGC Airman must exist")
		airman.global_position = Vector3(0.0, 0.1, 0.0)

		# Subtest A: Move / Take Cover Ping
		var move_dest := Vector3(6.0, 0.1, 6.0)
		player.issue_squad_command(move_dest, null)
		assert(airman.current_state == SGCAirmanAIScript.State.ORDER_MOVE, "Airman must enter ORDER_MOVE state")
		assert(airman.ordered_position == move_dest, "Airman ordered_position must match ping target")

		# Subtest B: Mount .50 Cal Browning Ping
		if turret_west != null:
			player.issue_squad_command(turret_west.global_position, turret_west)
			assert(airman.current_state == SGCAirmanAIScript.State.MAN_TURRET or airman.current_state == SGCAirmanAIScript.State.MOVE_TO_TURRET, "Airman must target and man the .50 Cal turret")
			airman.dismount_turret()

		# Subtest C: Revive Downed Ally Ping
		var downed_dummy := CharacterBody3D.new()
		downed_dummy.name = "DownedAlly"
		var d_health := HealthComponent.new()
		d_health.name = "HealthComponent"
		d_health.is_downed = true
		downed_dummy.add_child(d_health)
		root.add_child(downed_dummy)

		player.issue_squad_command(downed_dummy.global_position, downed_dummy)
		assert(airman.current_state == SGCAirmanAIScript.State.REVIVE_PLAYER, "Airman must enter REVIVE_PLAYER state upon revive ping")
		assert(airman.target_player_to_revive == downed_dummy, "Airman target_player_to_revive must be set to downed dummy")
		downed_dummy.queue_free()

		# Subtest D: Squad Regroup Order
		player.issue_squad_regroup()
		assert(airman.current_state == SGCAirmanAIScript.State.ORDER_REGROUP, "Airman must enter ORDER_REGROUP state upon regroup command")
		assert(airman.order_leader == player, "Airman order_leader must point to operative")

		print("[TEST 3/5] PASS: Contextual squad ping commands (Move, Mount Turret, Revive, Regroup) verified.")

	elif ticks == 8:
		# ========================================================
		# TEST 4: Segmented 3-Stage Iris Repair & Checkpoint Persistence
		# ========================================================
		print("[TEST 4/5] Testing Segmented 3-Stage Iris Repair under Fire & Checkpoint Persistence...")
		assert(iris_servo != null, "IrisServoHousing must exist in Gate Room")
		iris_servo.completed_stages = 0
		iris_servo.current_stage = 1
		iris_servo.stage_repair_time = 0.0
		iris_servo.is_repaired = false

		# Part A: Partial Stage 1 -> Interruption -> Progress resets to stage start (0/3)
		iris_servo.start_repair(player)
		iris_servo.update_repair(1.2) # 1.2s of 2.5s required for Stage 1
		assert(iris_servo.completed_stages == 0, "No stages should be completed yet")
		iris_servo.cancel_repair() # Interrupted by enemy fire
		assert(not iris_servo.is_repairing, "Repair must be cancelled")
		assert(iris_servo.completed_stages == 0, "Completed stages must remain 0")

		# Part B: Complete Stage 1 (Gears) -> Checkpoint 1/3 Saved!
		iris_servo.start_repair(player)
		iris_servo.update_repair(2.6) # Complete Stage 1
		assert(iris_servo.completed_stages == 1, "Stage 1 (Trinium Drive Gears) must be COMPLETED")
		assert(iris_servo.current_stage == 2, "Current stage must advance to Stage 2")

		# Duck into cover / interrupt
		iris_servo.cancel_repair()
		assert(iris_servo.completed_stages == 1, "Stage 1 checkpoint (33%) MUST PERSIST across interruptions!")

		# Part C: Complete Stage 2 (Hydraulics) -> Checkpoint 2/3 Saved!
		iris_servo.start_repair(player)
		iris_servo.update_repair(2.6) # Complete Stage 2
		assert(iris_servo.completed_stages == 2, "Stage 2 (Hydraulic Bypass) must be COMPLETED")
		assert(iris_servo.current_stage == 3, "Current stage must advance to Stage 3")

		# Interrupt again
		iris_servo.cancel_repair()
		assert(iris_servo.completed_stages == 2, "Stage 2 checkpoint (66%) MUST PERSIST across interruptions!")

		# Part D: Complete Stage 3 (Iris Mechanical Lock) -> 100% Iris Sealed!
		iris_servo.start_repair(player)
		iris_servo.update_repair(2.6) # Complete Stage 3
		assert(iris_servo.completed_stages == 3, "Stage 3 (Mechanical Lock) must be COMPLETED")
		assert(iris_servo.is_repaired, "Trinium Iris must be fully REPAIRED & LOCKED at 100%")

		print("[TEST 4/5] PASS: Segmented 3-Stage Iris repair checkpoints and 100% lock verified.")

	elif ticks == 10:
		# ========================================================
		# TEST 5: Armory Restock of Shields and Smoke Grenades
		# ========================================================
		print("[TEST 5/5] Testing Armory Resupply of Tactical Shields & Smoke Grenades...")
		player.deployable_shields_count = 0
		player.smoke_grenades_count = 0

		var armory_crate := gateroom.find_child("AmmoCrate1", true, false) as ArmoryResupplyStationScript
		assert(armory_crate != null, "Armory AmmoCrate1 must exist in Level28Complex")

		armory_crate.interact(player)
		assert(player.deployable_shields_count == 1, "Armory resupply must restock Deployable Shields to max (1)")
		assert(player.smoke_grenades_count == 2, "Armory resupply must restock M18 Smoke Grenades to max (2)")

		print("[TEST 5/5] PASS: Armory munitions resupply restores shields and smoke grenades.")

		print("\n========================================================")
		print("  SPRINT 15 SQUAD TACTICS & IRIS REPAIR TEST PASSED!    ")
		print("  ✓ Deployable Ballistic Shield (600 HP, Auto-Cover)    ")
		print("  ✓ M18 Smoke Grenades (4.5m Cloud, Jaffa LOS Occlusion)")
		print("  ✓ Contextual Squad Quick-Ping ([Q] / Middle-Click)    ")
		print("  ✓ Segmented 3-Stage Iris Repair (Gears/Hydro/Lock)    ")
		print("  ✓ Persistent Checkpoints Across Firefight Interrupts  ")
		print("  ✓ Armory Munitions Restock (Shields & Smoke)          ")
		print("========================================================\n")
		quit(0)
		return true

	return false
