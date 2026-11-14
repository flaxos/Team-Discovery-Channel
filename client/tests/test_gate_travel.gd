extends SceneTree
## Outbound gate travel from SGC to offworld site (roadmap GT-2; docs/plans/gate-travel-split-worlds.md).
## Tests the travel mission flow:
## 1. Production lobby selection and launching of MISSION_TRAVEL_INFILTRATION.
## 2. Coexistence of SGC (home) and Goa'uld compound (site 2km away) under MissionSession.
## 3. SGC HUD objective text for travel mission.
## 4. Dialing out on SGC dialing computer and stepping through the event horizon.
## 5. Seamless hand-off: carried state (health, ammo, reserves, equipment, patch ROM, slot) before vs after travel.
## 6. Presentation transfer: viewport, visibility, environment, audio presentation switches to site.
## 7. Late joiner placement: late joiner spawns at SGC (home) and can travel out.
## 8. Split-squad fail rule: away team downed while operative at home standing keeps mission alive; all down fails.
## 9. SGC Abort Mission control on dialing computer triggers session abort.

const MISSION := SGCNetworkManager.MISSION_TRAVEL_INFILTRATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var home: GateRoom
var site: ModularMission
var session: MissionSession


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func launch(previous: int = 0) -> void:
	home = null
	for i in range(900):
		var current := main.current_gate_room as GateRoom
		if current != null and current.get_instance_id() != previous and main.current_site != null:
			home = current
			break
		await frames(1)
	assert(home != null, "Both worlds load")
	site = main.current_site as ModularMission
	session = main.session
	assert(site != null and session != null)
	if not site.is_started:
		await site.started
	assert(site.setup_errors.is_empty(), str(site.setup_errors))
	assert(site.level.last_errors.is_empty(), str(site.level.last_errors))
	await frames(5)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)

	# --- 1. Lobby selection and verification
	var lobby := main.current_lobby as LobbyUI
	assert(lobby.mission_option_button.item_count == 5, "Travel mission offered when selected by CLI")
	assert(lobby.mission_option_button.get_item_metadata(4) == MISSION)
	assert(lobby.mission_option_button.selected == 4)
	assert(lobby.start_game_button.text == "LAUNCH TRAVEL MISSION")
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	await launch()

	# --- 2. Initial Coexistence and SGC Objective
	assert(session.worlds.size() == 2 and session.home() == home)
	assert(session.presented == home and home.is_presented and not site.is_presented)
	assert(home.visible and home.hud.visible and not site.visible and not site.hud.visible)
	assert(home.hud.objective_label.text.contains("TRAVEL MISSION: DIAL STARGATE"))

	var op1 := home.players_container.get_node_or_null("1") as PlayerController3D
	assert(op1 != null, "Host operative spawned in SGC")
	assert(site.players_container.get_child_count() == 0, "No operatives in site yet")
	assert(session.world_of(1) == home)

	# --- 3. Carried State Preparation
	# Modify operative state to test full persistence across gate travel
	op1.health_component.max_health = 150.0
	op1.health_component.current_health = 85.0
	op1.switch_slot(1)
	assert(op1.current_weapon != null)
	op1.current_weapon.current_ammo = 17
	op1.current_weapon.reserve_ammo = 64
	op1.switch_slot(2)
	assert(op1.current_weapon != null)
	op1.current_weapon.current_ammo = 7
	op1.current_weapon.reserve_ammo = 21
	op1.claymore_charges = 2
	op1.c4_charges_remaining = 3
	op1.turret_cooldown = 4.5
	op1.is_carrying_patch_rom = true

	var before_state: Dictionary = session.capture_state(op1)
	assert(before_state["health"] == 85.0)
	assert(before_state["active_slot"] == 2)
	assert(before_state["is_carrying_patch_rom"] == true)
	assert(before_state["weapons"].size() >= 2)

	# --- 4. SGC Gate Dialing & Travel Hand-off
	var sgc_gate: StargateRing = home.stargate_mesh
	assert(sgc_gate != null)
	# Authorize outbound travel through SGC gate
	sgc_gate.reserve_connection(false)
	sgc_gate.current_state = StargateRing.GateState.ACTIVE
	sgc_gate.authorize_extraction()
	assert(sgc_gate.extraction_authorized and sgc_gate.direction == StargateRing.GateDirection.OUTBOUND)

	# Trigger extraction through gate event horizon
	sgc_gate._on_extraction_entered(op1)
	await frames(5)

	# Verify op1 has moved from home to site
	assert(home.players_container.get_node_or_null("1") == null, "Operative despawned from SGC")
	var op1_site := site.players_container.get_node_or_null("1") as PlayerController3D
	assert(op1_site != null, "Operative spawned in offworld compound")
	assert(session.world_of(1) == site, "Session placement updated to site")
	assert(site.hosts_peer(1) and not home.hosts_peer(1))

	# --- 5. Verify Carried State Completeness After Travel
	assert(op1_site.class_id == before_state["class_id"])
	assert(op1_site.health_component.max_health == 150.0)
	assert(op1_site.health_component.current_health == 85.0)
	assert(op1_site.active_slot == 2, "Active slot preserved as secondary")
	assert(op1_site.current_weapon != null and op1_site.current_weapon.weapon_id == before_state["secondary_weapon_id"])
	assert(op1_site.current_weapon.current_ammo == 7)
	assert(op1_site.current_weapon.reserve_ammo == 21)
	op1_site.switch_slot(1)
	assert(op1_site.current_weapon != null and op1_site.current_weapon.weapon_id == before_state["primary_weapon_id"])
	assert(op1_site.current_weapon.current_ammo == 17)
	assert(op1_site.current_weapon.reserve_ammo == 64)
	assert(op1_site.claymore_charges == 2)
	assert(op1_site.c4_charges_remaining == 3)
	assert(op1_site.turret_cooldown > 4.0 and op1_site.turret_cooldown <= 4.5)
	assert(op1_site.is_carrying_patch_rom == true)

	# --- 6. Verify Presentation Switch
	assert(session.presented == site, "Session presented switched to site")
	assert(site.is_presented and not home.is_presented)
	assert(site.visible and site.hud.visible and site.hud.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(not home.visible and not home.hud.visible and home.hud.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(site.hud.local_player == op1_site, "Site HUD bound to travelling operative")

	# --- 7. Late Joiner Placement
	# Simulate late joiner (peer 42) connecting while away team is offworld
	assert(home.hosts_peer(42) and not site.hosts_peer(42), "Late joiner is placed in SGC (home)")
	home._spawn_player(42, SGCNetworkManager.CLASS_CARTER_TECH, (home.spawns_container.get_child(0) as Node3D).global_position)
	await frames(3)
	var op42 := home.players_container.get_node_or_null("42") as PlayerController3D
	assert(op42 != null, "Late joiner spawned in SGC")
	assert(home.squad_state() == Vector2i(1, 1), "SGC has 1 standing operative")
	assert(site.squad_state() == Vector2i(1, 1), "Site has 1 standing operative")

	# Late joiner can also travel through the gate to join the away team
	sgc_gate._on_extraction_entered(op42)
	await frames(5)
	assert(home.players_container.get_node_or_null("42") == null)
	var op42_site := site.players_container.get_node_or_null("42") as PlayerController3D
	assert(op42_site != null, "Late joiner successfully traveled to compound")
	assert(site.squad_state() == Vector2i(2, 2))

	# --- 8. Split-squad Failure Rule (D-017)
	# Spawn a third operative back at home in SGC
	home._spawn_player(99, SGCNetworkManager.CLASS_ONEILL_RECON, (home.spawns_container.get_child(0) as Node3D).global_position)
	await frames(3)
	var op_home := home.players_container.get_node_or_null("99") as PlayerController3D
	assert(op_home != null)

	# Down the entire away team offworld (op1_site and op42_site)
	op1_site.health_component.take_damage(999.0, null, "bullet")
	op42_site.health_component.take_damage(999.0, null, "bullet")
	await frames(5)
	assert(op1_site.health_component.is_downed and op42_site.health_component.is_downed)
	assert(site.squad_state() == Vector2i(2, 0), "Entire away team is downed")
	assert(home.squad_state() == Vector2i(1, 1), "Operative at home in SGC is standing")
	assert(session.result == -1, "Mission continues while operative at home is standing")

	# Now neutralize the operative at home
	op_home.health_component.can_be_downed = false
	op_home.health_component.take_damage(999.0, null, "bullet")
	await frames(5)
	assert(op_home.health_component.is_dead)
	assert(home.squad_state() == Vector2i(1, 0))
	assert(session.result == 0, "Mission fails when all operatives in both worlds are down")
	assert(home.mission_result == 0 and site.mission_result == 0)

	# --- 9. SGC Abort Mission Control
	var console := MissionWorld.find(home, "SGCDialingConsole") as SGCDialingConsole
	assert(console != null, "SGC has SGCDialingConsole")
	session.result = -1 # Reset for abort test
	console._execute_abort()
	assert(session.result == 0, "Aborting from SGC dialing console ends mission with defeat")

	print("PASS test_gate_travel")
	quit(0)
