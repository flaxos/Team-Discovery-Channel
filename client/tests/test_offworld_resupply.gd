extends SceneTree
## Functional offworld co-op resupply & armoury suite (CO-1).
## Exercises real player interaction with ArmoryArmorStation and ArmoryResupplyStation
## in the authored armoury room of Goa'uld Infiltration Mission.
## Validates:
## 1. Authored armoury stations instanced with collision, visual indicators and prompt labels.
## 2. Real player interaction restores body armor (health to 100%) and replenishes reserve ammo (+150 up to 300).
## 3. Cooldown enforcement on armor station prevents interaction spam.
## 4. Munitions resupply restores primary reserve ammo to capacity, Claymores, C4, deployable shields, and smoke.
## 5. Cooldown enforcement on munitions resupply prevents interaction spam.
## 6. ServerInteraction rejects downed or dead operatives.
## 7. Retry/reset restores stations to ready state with green indicators.
const MISSION := SGCNetworkManager.MISSION_GOAULD_INFILTRATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var room: ModularMission
var level: LevelAssembly
var player: PlayerController3D


func _init() -> void:
	call_deferred("run_test")


func frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func place(actor: CharacterBody3D, spot: Vector3) -> void:
	actor.global_position = spot + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO


func run_test() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	assert(net != null, "NetworkManager autoload required")
	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)

	var lobby := main.current_lobby as LobbyUI
	assert(lobby != null, "LobbyUI must be present")
	lobby._on_mission_selected(3)
	assert(net.selected_mission_id == MISSION)
	assert(net.host_game(0) == OK, "Host game on ephemeral port must succeed")
	lobby._on_start_game_pressed()
	await frames(3)

	for _i: int in range(600):
		var current := main.current_gate_room as ModularMission
		if current != null and current.mission_id == MISSION:
			room = current
			break
		await frames(1)

	assert(room != null, "GoauldInfiltrationMission must load as current gate room")
	if not room.is_started:
		await room.started

	assert(room.setup_errors.is_empty(), "Modular mission setup must have no errors: " + str(room.setup_errors))
	assert(room.level.last_errors.is_empty(), "Level layout must have no assembly errors: " + str(room.level.last_errors))

	level = room.level
	player = room.players_container.get_node_or_null("1") as PlayerController3D
	assert(player != null, "Operative 1 must be present in players container")
	player.is_local_authority = true

	# --- TEST 1: Authored armoury stations discovery ---
	print("[CO-1 TEST 1] Verifying offworld armoury room and stations...")
	var armoury_module := level.get_node_or_null("armoury") as LevelModule
	assert(armoury_module != null, "Authored armoury module must exist in Goa'uld compound")

	var armor_station := armoury_module.get_node_or_null("Attachments/RoomContent/armour_station") as ArmoryArmorStation
	assert(armor_station != null, "ArmoryArmorStation must be instanced in armoury room")
	assert(armor_station.is_in_group("interactable"), "ArmoryArmorStation must be in 'interactable' group")
	assert(armor_station.has_node("RoomCollision"), "ArmoryArmorStation must have physical RoomCollision")
	assert(armor_station.prompt_label != null, "ArmoryArmorStation must have 3D prompt label")
	assert(armor_station.station_light != null, "ArmoryArmorStation must have visual indicator light")
	assert(armor_station.current_cooldown == 0.0, "Initial armor cooldown must be 0")

	var resupply_station := armoury_module.get_node_or_null("Attachments/RoomContent/resupply_station") as ArmoryResupplyStation
	assert(resupply_station != null, "ArmoryResupplyStation must be instanced in armoury room")
	assert(resupply_station.is_in_group("interactable"), "ArmoryResupplyStation must be in 'interactable' group")
	assert(resupply_station.has_node("RoomCollision"), "ArmoryResupplyStation must have physical RoomCollision")
	assert(resupply_station.prompt_label != null, "ArmoryResupplyStation must have 3D prompt label")
	assert(resupply_station.status_light != null, "ArmoryResupplyStation must have visual indicator light")
	assert(resupply_station.current_cooldown == 0.0, "Initial resupply cooldown must be 0")
	print("✓ Authored armoury stations verified with geometry, collision, and indicators.")

	# --- TEST 2: Tactical Body Armor Re-armor and Limits ---
	print("[CO-1 TEST 2] Testing ArmoryArmorStation tactical plates restore and ammo refill...")
	var wb := player.current_weapon as WeaponBase
	assert(wb != null, "Operative must hold an active weapon")

	# Damage operative and deplete reserve ammo
	player.health_component.current_health = 35
	wb.reserve_ammo = 100

	# Move operative to armor station approach
	place(player, armor_station.global_position + Vector3(0.5, 0.0, 0.5))
	await frames(10)

	# Verify in-game prompt updates
	assert(armor_station.prompt_label.text.contains("RE-ARMOR"), "Prompt label must show RE-ARMOR prompt on approach")

	# Real player interaction
	player._try_interact()
	await frames(5)

	assert(player.health_component.current_health == player.health_component.max_health, "Tactical plates must restore Health to 100%")
	assert(wb.reserve_ammo == 250, "Ballistic weapon reserve must replenish +150 (Found: %d, Expected: 250)" % wb.reserve_ammo)
	assert(armor_station.current_cooldown > 0.0, "Armor station must enter cooldown after use")
	assert(armor_station.prompt_label.text.contains("COOLDOWN"), "Prompt label must indicate cooldown status")
	assert(armor_station.station_light.light_color == Color(0.9, 0.6, 0.1, 1.0), "Status light must turn orange during cooldown")

	# Anti-spam during cooldown
	player.health_component.current_health = 50
	player._try_interact()
	await frames(5)
	assert(player.health_component.current_health == 50, "Armor station must reject interaction during cooldown")

	# Wait for cooldown to expire
	for _i: int in range(240):
		await frames(1)
		if armor_station.current_cooldown == 0.0:
			break
	assert(armor_station.current_cooldown == 0.0, "Cooldown must expire cleanly")
	assert(armor_station.station_light.light_color == Color(0.2, 0.9, 0.4, 1.0), "Status light must return to green")
	print("✓ ArmoryArmorStation tactical plates restore and cooldown anti-spam verified.")

	# --- TEST 3: Munitions Resupply and Tactical Equipment Restock ---
	print("[CO-1 TEST 3] Testing ArmoryResupplyStation munitions and tactical restock...")
	wb.current_ammo = 5
	wb.reserve_ammo = 20
	player.claymore_charges = 0
	player.c4_charges_remaining = 0
	player.deployable_shields_count = 0
	player.smoke_grenades_count = 0

	# Move operative to resupply station approach
	place(player, resupply_station.global_position + Vector3(0.5, 0.0, 0.5))
	await frames(10)

	assert(resupply_station.prompt_label.text.contains("RESUPPLY"), "Prompt label must show RESUPPLY prompt on approach")

	# Real player interaction
	player._try_interact()
	await frames(5)

	assert(wb.reserve_ammo == wb.reserve_capacity, "Munitions resupply must replenish reserve ammo to capacity (%d)" % wb.reserve_capacity)
	assert(player.claymore_charges == player.MAX_CLAYMORE_CHARGES, "Claymores must be replenished to MAX (%d)" % player.MAX_CLAYMORE_CHARGES)
	assert(player.c4_charges_remaining == player.MAX_C4_CHARGES, "C4 charges must be replenished to MAX (%d)" % player.MAX_C4_CHARGES)
	assert(player.deployable_shields_count == player.MAX_DEPLOYABLE_SHIELDS, "Deployable shields must be replenished to MAX (%d)" % player.MAX_DEPLOYABLE_SHIELDS)
	assert(player.smoke_grenades_count == player.MAX_SMOKE_GRENADES, "Smoke grenades must be replenished to MAX (%d)" % player.MAX_SMOKE_GRENADES)
	assert(resupply_station.current_cooldown > 0.0, "Resupply station must enter cooldown after use")
	assert(resupply_station.prompt_label.text.contains("COOLDOWN"), "Prompt label must indicate cooldown status")
	assert(resupply_station.status_light.light_color == Color(0.9, 0.6, 0.1), "Status light must turn orange during cooldown")

	# Anti-spam during cooldown
	player.claymore_charges = 0
	player._try_interact()
	await frames(5)
	assert(player.claymore_charges == 0, "Resupply station must reject interaction during cooldown")

	# Wait for cooldown to expire
	for _i: int in range(240):
		await frames(1)
		if resupply_station.current_cooldown == 0.0:
			break
	assert(resupply_station.current_cooldown == 0.0, "Resupply cooldown must expire cleanly")
	assert(resupply_station.status_light.light_color == Color(0.2, 0.9, 0.3), "Status light must return to munitions green")
	print("✓ ArmoryResupplyStation munitions restock, tactical gear, and cooldown anti-spam verified.")

	# --- TEST 4: Downed/Dead Operative Rejection ---
	print("[CO-1 TEST 4] Testing ServerInteraction downed operative rejection...")
	player.health_component.current_health = 0
	player.health_component.is_downed = true
	await frames(5)

	# Downed operative attempts interact
	player.claymore_charges = 0
	resupply_station.interact(player)
	await frames(5)
	assert(player.claymore_charges == 0, "Downed operative cannot resupply munitions")

	armor_station.interact(player)
	await frames(5)
	assert(player.health_component.current_health == 0, "Downed operative cannot re-armor plates")

	# Restore operative
	player.health_component.is_downed = false
	player.health_component.current_health = 100
	print("✓ Downed operative interaction rejection verified.")

	# --- TEST 5: Retry Reset ---
	print("[CO-1 TEST 5] Testing station reset on retry...")
	armor_station.current_cooldown = 2.5
	armor_station.station_light.light_color = Color(0.9, 0.6, 0.1, 1.0)
	resupply_station.current_cooldown = 2.5
	resupply_station.status_light.light_color = Color(0.9, 0.6, 0.1)

	armor_station.reset_station()
	resupply_station.reset_station()

	assert(armor_station.current_cooldown == 0.0, "Armor station cooldown must be 0 after reset")
	assert(armor_station.station_light.light_color == Color(0.2, 0.9, 0.4, 1.0), "Armor station light must be green after reset")
	assert(armor_station.prompt_label.text.contains("RE-ARMOR"), "Armor station prompt must be restored after reset")

	assert(resupply_station.current_cooldown == 0.0, "Resupply station cooldown must be 0 after reset")
	assert(resupply_station.status_light.light_color == Color(0.2, 0.9, 0.3), "Resupply station light must be munitions green after reset")
	assert(resupply_station.prompt_label.text.contains("RESUPPLY"), "Resupply station prompt must be restored after reset")
	print("✓ Station reset on retry verified.")

	print("\n========================================================")
	print("  CO-1 OFFWORLD RESUPPLY & ARMOURY TEST PASSED!        ")
	print("  ✓ Offworld Armoury Station Discovery & Collision     ")
	print("  ✓ Body Armor Restoration & Ammo Top-Off              ")
	print("  ✓ Munitions Resupply & Tactical Gear Restock         ")
	print("  ✓ Server Cooldown Enforcement & Anti-Spam            ")
	print("  ✓ Downed Operative Rejection (ServerInteraction)     ")
	print("  ✓ Station Cooldown Reset for Mission Retry           ")
	print("========================================================\n")

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	await preload("res://tests/support/finish.gd").success(self)
