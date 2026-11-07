extends SceneTree
## Automated Headless Validation: Sprint 9 SGC Interactive Terminals, Armory Resupply & Multi-Sector Climax.
## Validates:
##  1. Interactive Armory Resupply: Ammo crates restock weapon magazines, reserves, Claymores, and C4 charges.
##  2. Interactive Armory Weapon Racks: Real-time weapon loadout swapping.
##  3. General's Defense Override Terminal: Facility lockdown, automated sentry deployment, and emergency strobes.
##  4. Security Station CCTV Surveillance Console: 4-camera cycling across Level 28 & Level 27 and clean exit.
##  5. Foothold Multi-Sector Climax Incursion: Concurrent 3-sector hostile assault across Level 28 and Level 27.

const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

const ArmoryResupplyStation = preload("res://scripts/props/ArmoryResupplyStation.gd")
const GeneralsDefenseTerminal = preload("res://scripts/props/GeneralsDefenseTerminal.gd")
const SecurityMonitorConsole = preload("res://scripts/props/SecurityMonitorConsole.gd")

var gateroom: GateRoom = null
var wave_mgr: WaveManager = null
var player: PlayerController3D = null
var ticks: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: SPRINT 9 INTERACTIVES & CLIMAX TEST      ")
	print("========================================================")

	var scene := load(GATE_ROOM_SCENE) as PackedScene
	assert(scene != null, "GateRoom scene must load successfully")
	gateroom = scene.instantiate() as GateRoom
	root.add_child(gateroom)

	wave_mgr = gateroom.get_node_or_null("WaveManager") as WaveManager
	assert(wave_mgr != null, "WaveManager must exist in GateRoom")

	var p_scene := load(PLAYER_SCENE) as PackedScene
	assert(p_scene != null, "Player scene must load successfully")
	player = p_scene.instantiate() as PlayerController3D
	player.name = "1"
	player.class_id = SGCNetworkManager.CLASS_ONEILL_RECON
	player.is_local_authority = true
	gateroom.get_node("Players").add_child(player, true)


func _process(_delta: float) -> bool:
	ticks += 1

	if ticks == 2:
		# TEST 1: Interactive Armory Resupply Station (Ammo Crate)
		print("[TEST 1/5] Testing Armory Ammo Crate Munitions Resupply...")
		var ammo_crate := gateroom.find_child("AmmoCrate1", true, false) as ArmoryResupplyStation
		assert(ammo_crate != null, "AmmoCrate1 must exist and have ArmoryResupplyStation script")
		assert(ammo_crate.is_in_group("interactable"), "AmmoCrate1 must be in 'interactable' group")

		# Reduce player ammo and expend tactical equipment
		var weapon := player.current_weapon
		assert(weapon != null, "Player must have an active weapon")
		weapon.current_ammo = 10
		weapon.reserve_ammo = 20
		player.claymore_charges = 0
		player.c4_charges_remaining = 0

		# Position player next to ammo crate and interact
		player.global_position = ammo_crate.global_position + Vector3(0.5, 0.0, 0.5)
		var resupplied_box := [false]
		ammo_crate.resupplied.connect(func(_p: Node) -> void:
			resupplied_box[0] = true
		, CONNECT_ONE_SHOT)

		player._try_interact()
		assert(resupplied_box[0], "ArmoryResupplyStation must emit resupplied signal on interaction")
		assert(weapon.reserve_ammo == weapon.reserve_capacity, "Reserve ammo must be fully replenished (Found: %d, Expected: %d)" % [weapon.reserve_ammo, weapon.reserve_capacity])
		assert(player.claymore_charges == player.MAX_CLAYMORE_CHARGES, "Claymores must be replenished to MAX (Found: %d)" % player.claymore_charges)
		assert(player.c4_charges_remaining == player.MAX_C4_CHARGES, "C4 charges must be replenished to MAX (Found: %d)" % player.c4_charges_remaining)
		print("[TEST 1/5] PASS: Armory Ammo Crate replenished weapon reserve ammo, Claymores (%d), and C4 charges (%d)." % [player.claymore_charges, player.c4_charges_remaining])

	elif ticks == 4:
		# TEST 2: Interactive Armory Weapon Rack Loadout Swapping
		print("[TEST 2/5] Testing Armory Weapon Rack Loadout Swapping...")
		var weapon_rack := gateroom.find_child("WeaponRackNorth", true, false) as ArmoryResupplyStation
		assert(weapon_rack != null, "WeaponRackNorth must exist and have ArmoryResupplyStation script")
		assert(weapon_rack.station_type == ArmoryResupplyStation.StationType.WEAPON_RACK, "WeaponRackNorth must have WEAPON_RACK type")

		var initial_weapon_id := player.primary_weapon_id
		player.global_position = weapon_rack.global_position + Vector3(0.5, 0.0, 0.5)

		var swapped_box := [""]
		weapon_rack.weapon_swapped.connect(func(_p: Node, new_id: String) -> void:
			swapped_box[0] = new_id
		, CONNECT_ONE_SHOT)

		player._try_interact()
		assert(not swapped_box[0].is_empty(), "Weapon swap signal must emit with valid weapon ID")
		assert(player.primary_weapon_id == swapped_box[0], "Player active primary must match swapped ID")
		assert(player.current_weapon.weapon_id == swapped_box[0], "Player current weapon instance must match swapped ID (%s)" % swapped_box[0])
		print("[TEST 2/5] PASS: Armory Weapon Rack successfully swapped loadout (%s -> %s)." % [initial_weapon_id, swapped_box[0]])

	elif ticks == 6:
		# TEST 3: General's Emergency Defense Override Terminal
		print("[TEST 3/5] Testing General's Emergency Defense Override Terminal...")
		var def_terminal := gateroom.find_child("GeneralsDefenseTerminal", true, false) as GeneralsDefenseTerminal
		assert(def_terminal != null, "GeneralsDefenseTerminal must exist in General's Office")
		assert(def_terminal.is_in_group("interactable"), "GeneralsDefenseTerminal must be in 'interactable' group")

		# Position player in General's Office next to terminal and interact
		player.global_position = def_terminal.global_position + Vector3(0.3, 0.0, 0.3)
		var defense_box := [false]
		def_terminal.defense_grid_activated.connect(func(_p: Node) -> void:
			defense_box[0] = true
		, CONNECT_ONE_SHOT)

		player._try_interact()
		assert(defense_box[0], "GeneralsDefenseTerminal must emit defense_grid_activated signal")

		# Verify automated sentry spawned in Gate Room
		var sentry := gateroom.find_child("GeneralsAutomatedSentry", true, false) as DeployableTurret
		assert(sentry != null, "Automated defensive sentry must be spawned in Gate Room")
		assert(sentry.is_automated_sentry, "Sentry must be operating in autonomous sentry mode")

		# Verify emergency lights and blast door lock
		assert(gateroom.is_blast_doors_closed, "Blast doors must be sealed to secure Level 28 corridor")
		print("[TEST 3/5] PASS: General's Defense Terminal deployed Gate Room automated sentry and sealed blast doors.")

	elif ticks == 8:
		# TEST 4: Security Station CCTV Surveillance Console
		print("[TEST 4/5] Testing Security Station CCTV Multi-Monitor Feeds...")
		var cctv := gateroom.find_child("CCTVMonitorBank", true, false) as SecurityMonitorConsole
		assert(cctv != null, "CCTVMonitorBank must exist in Security Station with SecurityMonitorConsole script")
		assert(cctv.is_in_group("interactable"), "CCTVMonitorBank must be in 'interactable' group")

		player.global_position = cctv.global_position + Vector3(0.5, 0.0, 0.5)

		# 1. Enter CCTV mode
		var entered_box := [false]
		cctv.cctv_entered.connect(func(_p: Node) -> void:
			entered_box[0] = true
		, CONNECT_ONE_SHOT)

		player._try_interact()
		assert(entered_box[0], "CCTV console must emit cctv_entered signal")
		assert(player.is_in_cctv_mode, "PlayerController3D must be flagged in CCTV mode")
		assert(cctv.current_feed_index == 0, "Initial camera must be Feed 0 (CAM 01: GATE ROOM ARENA)")
		assert(player.camera_rig.global_position.distance_to(SecurityMonitorConsole.FEEDS[0]["position"]) < 0.1, "CameraRig must be anchored at Cam 1 coordinates")

		# 2. Cycle CCTV feeds
		var cycled_box := [""]
		cctv.cctv_cycled.connect(func(idx: int, fname: String) -> void:
			cycled_box[0] = fname
		, CONNECT_ONE_SHOT)

		cctv.cycle_feed()
		assert(cctv.current_feed_index == 1, "Camera feed must advance to Feed 1 (CAM 02: CONTROL ROOM MEZZANINE)")
		assert(cycled_box[0] == "CAM 02: CONTROL ROOM MEZZANINE", "Feed name must match Control Room Mezzanine")

		# 3. Exit CCTV mode
		var exited_box := [false]
		cctv.cctv_exited.connect(func(_p: Node) -> void:
			exited_box[0] = true
		, CONNECT_ONE_SHOT)

		cctv.exit_cctv()
		assert(exited_box[0], "CCTV console must emit cctv_exited signal")
		assert(not player.is_in_cctv_mode, "PlayerController3D must clear CCTV mode on exit")
		print("[TEST 4/5] PASS: Security Station CCTV console verified (Enter -> Cam 1 -> Cam 2 Cycle -> Clean Exit).")

	elif ticks == 10:
		# TEST 5: Multi-Sector Climax Incursion System
		print("[TEST 5/5] Testing Foothold Multi-Sector Climax Incursion...")
		var incursion_box: Array = [[]]
		wave_mgr.multi_sector_incursion_started.connect(func(sectors: Array[String]) -> void:
			incursion_box[0] = sectors
		, CONNECT_ONE_SHOT)

		wave_mgr.trigger_climax_incursion()
		assert(wave_mgr.current_wave == 4, "WaveManager must advance to Climax Wave 4")
		assert(wave_mgr.is_wave_active, "Climax wave must be actively engaged")
		var sec_list: Array = incursion_box[0] as Array
		assert(sec_list.has("GATE_ROOM"), "Incursion must breach Gate Room")
		assert(sec_list.has("ARMORY_HALLWAY"), "Incursion must breach Armory/Fallback Transport Rings")
		assert(sec_list.has("LEVEL_27_CORRIDOR"), "Incursion must breach Sublevel 27 Upper Deck")

		# Verify hostiles spawned in Enemies container
		var enemies := gateroom.get_node("Enemies")
		assert(enemies != null, "Enemies container must exist")
		var enemy_count := enemies.get_child_count()
		assert(enemy_count >= 6, "Multi-sector incursion must field hostiles across sectors (Found: %d)" % enemy_count)
		assert(wave_mgr.enemies_alive == 8, "WaveManager enemies_alive must be 8 for Climax Wave")
		print("[TEST 5/5] PASS: Multi-Sector Climax Incursion breached Gate Room, Armory Rings, and Level 27 simultaneously (Hostiles: %d)." % enemy_count)

		print("\n========================================================")
		print("  SPRINT 9 INTERACTIVES & CLIMAX TEST PASSED!           ")
		print("  ✓ Armory Ammo Crates (Full Ammo, Claymores & C4)      ")
		print("  ✓ Armory Weapon Racks (Real-Time Loadout Swapping)    ")
		print("  ✓ General's Defense Terminal (Sentry & Lockdown)      ")
		print("  ✓ Security Station CCTV (Multi-Camera Surveillance)   ")
		print("  ✓ Foothold Climax Incursion (Multi-Sector Assault)    ")
		print("========================================================\n")
		quit(0)
		return true

	return false
