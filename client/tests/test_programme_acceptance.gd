extends SceneTree
## Sprint 35 Programme Acceptance Test Suite.
## Validates the entire Sprints 7-35 asset programme:
## 1. 4-player class matrix & equipment fits (Carter, O'Neill, Teal'c, SG-3 Heavy)
## 2. Stationary SGC civilian roles (Lab, Medic, Admin)
## 3. Offworld destinations (Goa'uld Mothership & Alpha Site Outpost)
## 4. Normal vs alarm lighting states across base and mothership
## 5. Asset attribution and licence ledger integrity

const SGC_BASE_SCENE := "res://scenes/main/SGCUATBase.tscn"
const ALPHA_SITE_SCENE := "res://scenes/mission/TauriAlphaSiteMission.tscn"
const MOTHERSHIP_OBJECTIVE_SCENE := "res://scenes/mission/GoauldMothershipObjectiveMission.tscn"
const PLAYER_SCENE := "res://scenes/entities/Player.tscn"
const CIVILIAN_SCENE := "res://scenes/entities/SGCCivilian.tscn"

const CLASSES: Array[String] = [
	SGCNetworkManager.CLASS_CARTER_TECH,
	SGCNetworkManager.CLASS_ONEILL_RECON,
	SGCNetworkManager.CLASS_TEALC_JAFFA,
	SGCNetworkManager.CLASS_SG3_HEAVY
]

func _init() -> void:
	call_deferred("run")

func require(condition: bool, message: String = "Programme acceptance assertion failed") -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(false, message)

func test_player_classes() -> void:
	print("--- 1. Auditing Player Class Roster & Equipment Fits ---")
	var player_packed: PackedScene = load(PLAYER_SCENE)
	require(player_packed != null, "Player scene loads")
	
	for class_id: String in CLASSES:
		var player: PlayerController3D = player_packed.instantiate()
		player.class_id = class_id
		root.add_child(player)
		await process_frame
		
		var rig: Node = player.get_node_or_null(^"Visuals/SquadRig")
		require(rig != null, "Player has SquadRig node for class: " + class_id)
		require(rig.get("skeleton") != null, "SquadRig has valid Skeleton3D for class: " + class_id)
		
		match class_id:
			SGCNetworkManager.CLASS_CARTER_TECH:
				require(rig.get("tech_mount") != null, "Carter has tech scanner mount")
				require(player.primary_weapon_id in ["mp5", "mp5sd"], "Carter primary is MP5/MP5SD: " + player.primary_weapon_id)
				require(player.secondary_weapon_id == "zat", "Carter secondary is Zat")
			SGCNetworkManager.CLASS_ONEILL_RECON:
				require(rig.get("recon_mount") != null, "O'Neill has recon radio mount")
				require(player.primary_weapon_id == "p90", "O'Neill primary is P90")
				require(player.secondary_weapon_id == "m9", "O'Neill secondary is M9")
			SGCNetworkManager.CLASS_TEALC_JAFFA:
				require(rig.get("jaffa_mount") != null, "Teal'c has Jaffa armour mount")
				require(player.primary_weapon_id in ["staff", "staff_weapon"], "Teal'c primary is Staff")
				require(player.secondary_weapon_id == "zat", "Teal'c secondary is Zat")
			SGCNetworkManager.CLASS_SG3_HEAVY:
				require(rig.get("heavy_mount") != null, "SG-3 Heavy has heavy carrier mount")
				require(player.primary_weapon_id == "m249", "SG-3 Heavy primary is M249")
				require(player.secondary_weapon_id == "m9", "SG-3 Heavy secondary is M9")
				
		print("  PASS: Class '%s' verified (rig, mounts, primary=%s, secondary=%s)" % [
			class_id, player.primary_weapon_id, player.secondary_weapon_id
		])
		player.free()
		await process_frame

func test_sgc_civilians() -> void:
	print("--- 2. Auditing SGC Stationary Civilian Presence ---")
	var civ_packed: PackedScene = load(CIVILIAN_SCENE)
	require(civ_packed != null, "Civilian scene loads")
	
	for role: int in [0, 1, 2]: # LAB, MEDICAL, ADMIN
		var civ: SGCCivilianVisual = civ_packed.instantiate()
		civ.role = role as SGCCivilianVisual.Role
		root.add_child(civ)
		await process_frame
		
		require(civ.has_skeletal_body, "Civilian has skeletal body")
		require(civ.head != null, "Civilian has head mesh")
		require(civ.work_prop != null, "Civilian has role work prop")
		require(civ.get_node_or_null("Health") == null, "Civilian has no combat Health component")
		require(civ.get_node_or_null("Inventory") == null, "Civilian has no weapon Inventory")
		print("  PASS: Civilian Role %d verified (appearance, non-combat boundary)" % role)
		civ.free()
		await process_frame

func test_offworld_destinations() -> void:
	print("--- 3. Auditing Offworld Destinations (Alpha Site & Mothership) ---")
	# Alpha Site
	var alpha_packed: PackedScene = load(ALPHA_SITE_SCENE)
	require(alpha_packed != null, "Alpha site mission scene loads")
	var alpha: Node = alpha_packed.instantiate()
	root.add_child(alpha)
	await process_frame
	require(alpha.has_node("LevelAssembly") or alpha.get("level") != null, "Alpha site has level structure")
	print("  PASS: Alpha Site Outpost verified")
	alpha.free()
	await process_frame
	
	# Mothership
	var mothership_packed: PackedScene = load(MOTHERSHIP_OBJECTIVE_SCENE)
	require(mothership_packed != null, "Mothership objective mission scene loads")
	var mothership: Node = mothership_packed.instantiate()
	root.add_child(mothership)
	await process_frame
	require(mothership.has_node("LevelAssembly") or mothership.get("level") != null, "Mothership has level structure")
	print("  PASS: Goa'uld Mothership Objective verified")
	mothership.free()
	await process_frame

func test_normal_vs_alarm_lighting() -> void:
	print("--- 4. Auditing Normal vs Alarm Lighting Systems ---")
	var sgc_packed: PackedScene = load(SGC_BASE_SCENE)
	require(sgc_packed != null, "SGC Base scene loads")
	var sgc: GateRoom = sgc_packed.instantiate() as GateRoom
	root.add_child(sgc)
	await process_frame
	
	require(not sgc.is_emergency_active, "SGC starts in normal lighting")
	sgc.set_emergency_lights(true)
	require(sgc.is_emergency_active, "SGC transitions to emergency alert lighting")
	sgc.set_emergency_lights(false)
	require(not sgc.is_emergency_active, "SGC returns to standby normal lighting")
	print("  PASS: SGC normal/emergency lighting toggle verified")
	sgc.free()
	await process_frame

func test_licensing_integrity() -> void:
	print("--- 5. Auditing Credits and Licensing Ledger ---")
	var attributions_path := "res://../credits/ATTRIBUTIONS.md"
	require(FileAccess.file_exists(attributions_path), "ATTRIBUTIONS.md exists")
	var content := FileAccess.get_file_as_string(attributions_path)
	require(content.contains("Rotuma"), "Credits contain Rotuma P90")
	require(content.contains("skaf13"), "Credits contain skaf13 M249")
	require(content.contains("emran.bayati"), "Credits contain emran.bayati M9")
	require(content.contains("WillyG99"), "Credits contain WillyG99 MP5SD")
	require(content.contains("Stargate"), "Credits contain Stargate")
	require(content.contains("Browning M2"), "Credits contain M2")
	require(content.contains("CC-BY-4.0.txt"), "Credits reference CC-BY-4.0")
	require(content.contains("CC0-1.0.txt"), "Credits reference CC0-1.0")
	print("  PASS: Credits & Licensing integrity verified")

func run() -> void:
	print("================================================================================")
	print("RUNNING SPRINT 35 PROGRAMME ACCEPTANCE SUITE")
	print("================================================================================")
	await test_player_classes()
	await test_sgc_civilians()
	await test_offworld_destinations()
	await test_normal_vs_alarm_lighting()
	test_licensing_integrity()
	print("================================================================================")
	print("PASS: ALL PROGRAMME ACCEPTANCE CRITERIA VERIFIED")
	print("================================================================================")
	await preload("res://tests/support/finish.gd").success(self)
