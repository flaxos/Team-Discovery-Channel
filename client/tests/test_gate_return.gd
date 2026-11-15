extends SceneTree
## Return gate travel, D-017 success rule, SGC debrief, and two-world retry (roadmap GT-3;
## docs/plans/gate-travel-split-worlds.md).
## Tests:
## 1. Real SGC dialing computer activation (7 chevrons + 4 GDO beats) for travel mission.
## 2. Site DHD and Stargate wiring inside ModularMission; DHD denied before objectives complete.
## 3. Completing objectives opens the site's Stargate for home instead of ending immediately.
## 4. Returning operative arrives on SGC Stargate platform (not Armory) outside ExtractionArea.
## 5. Decision D-017 success rule: waits until no standing operative remains offworld and >= 1 came home.
## 6. SGC debrief displays real figures (kills, 3/3 objectives, duration) and who was lost.
## 7. Gates close on mission result; two-world retry resets both worlds and all state cleanly.

const MISSION := SGCNetworkManager.MISSION_TRAVEL_INFILTRATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var home: GateRoom
var site: ModularMission
var session: MissionSession


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func launch(previous: int = 0) -> void:
	home = null
	for _i in range(900):
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


func console_spot(room_id: StringName) -> Vector3:
	var console := site.level.get_node(str(room_id)).find_child("MissionInteract", true, false) as Node3D
	assert(console != null, "Mission console in " + str(room_id))
	var best := Vector3.INF
	for offset: Vector3 in [Vector3(0, 0, 1.5), Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		var spot := NavigationServer3D.map_get_closest_point(site.level.navigation_map, console.global_position + offset)
		if spot.distance_to(console.global_position) < MissionInteractable.REACH - 0.3:
			if best == Vector3.INF or spot.distance_to(console.global_position) < best.distance_to(console.global_position):
				best = spot
	assert(best != Vector3.INF)
	return best


func use_console(room_id: StringName, actor: PlayerController3D) -> void:
	var console := site.level.get_node(str(room_id)).find_child("MissionInteract", true, false) as MissionInteractable
	var before := site.objectives.index
	for _i in range(30):
		console.interact(actor)
		await frames(2)
		if site.objectives.index > before:
			return
	assert(false, "Console in %s did not complete its objective" % room_id)


func run() -> void:
	net = root.get_node("NetworkManager") as SGCNetworkManager
	net.player_name = "Major"
	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)

	var lobby := main.current_lobby as LobbyUI
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	await launch()

	# --- 1. Real SGC dialing sequence opens the SGC gate in travel_infiltration
	var op1 := home.players_container.get_node("1") as PlayerController3D
	var sgc_dialer := home.dhd_console
	var sgc_gate := home.stargate_mesh
	assert(sgc_dialer != null and sgc_gate != null)
	sgc_gate.kawoosh_duration_s = 0.08
	op1.global_position = sgc_dialer.global_position + Vector3(0, 0, 1.0)
	sgc_dialer.start_dialing(op1)
	assert(sgc_dialer.current_phase == DHDDialer.DialPhase.CHEVRONS, "SGC dialer accepts outbound sequence in travel mission")
	for _g in range(7):
		sgc_dialer.input_glyph(sgc_dialer.chevron_sequence[sgc_dialer.current_chevron_index])
	for _b in range(4):
		sgc_dialer.input_glyph(sgc_dialer.gdo_sequence[sgc_dialer.gdo_index])
	for _f in range(30):
		await frames(1)
		if sgc_gate.current_state == StargateRing.GateState.ACTIVE:
			break
	assert(sgc_gate.current_state == StargateRing.GateState.ACTIVE and sgc_gate.extraction_authorized)

	# --- 2. Outbound travel for two operatives (host peer 1 and guest peer 42)
	sgc_gate._on_extraction_entered(op1)
	await frames(5)
	var op1_site := site.players_container.get_node_or_null("1") as PlayerController3D
	assert(op1_site != null and session.presented == site)

	home._spawn_player(42, SGCNetworkManager.CLASS_CARTER_TECH, (home.spawns_container.get_child(0) as Node3D).global_position)
	await frames(3)
	var op42_home := home.players_container.get_node("42") as PlayerController3D
	sgc_gate._on_extraction_entered(op42_home)
	await frames(5)
	var op42_site := site.players_container.get_node_or_null("42") as PlayerController3D
	assert(op42_site != null and site.squad_state() == Vector2i(2, 2))

	# --- 3. Verify site Stargate and DHD wiring; dialing home is denied before objectives complete (D-017)
	assert(site.stargate_mesh != null, "Site StargateRing discovered inside Level")
	assert(site.dialing_console != null, "Site DHD discovered inside Level")
	assert(site.dialing_console.target_stargate == site.stargate_mesh, "Site DHD targets site Stargate")
	assert(site.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	site.stargate_mesh.kawoosh_duration_s = 0.08

	op1_site.global_position = site.dialing_console.global_position + Vector3(0, 0, 1.0)
	site.dialing_console.start_dialing(op1_site)
	assert(site.dialing_console.current_phase == DHDDialer.DialPhase.INACTIVE, "Cannot dial home before objectives complete")
	assert(site.dialing_console.denial_reason == "COMPLETE OBJECTIVES BEFORE DIALING HOME")
	assert(site.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)

	# Direct travel attempt back to home before objectives complete must also be ignored
	session.travel_player(op1_site, site)
	await frames(2)
	assert(site.players_container.has_node("1"), "Travel home rejected before objectives complete")

	# --- 4. Combat & Objectives completion opens site Stargate instead of concluding immediately
	op1_site.health_component.current_health = 100000.0
	op42_site.health_component.current_health = 100000.0
	var eliminated := 0
	for child in site.enemies.get_children():
		var jaffa := child as JaffaAI
		if jaffa != null and not jaffa.health_component.is_dead:
			jaffa.health_component.take_damage(9999.0, op1_site, "test")
			eliminated += 1
			if eliminated == 2:
				break
	assert(site.hostiles_eliminated_count() == 2)

	op1_site.global_position = console_spot(&"generator")
	await use_console(&"generator", op1_site)
	op1_site.global_position = console_spot(&"cmd_command")
	await use_console(&"cmd_command", op1_site)
	assert(site.objectives.index == 2)

	var entry := site.level.marker(&"gate", &"entry")
	op1_site.global_position = entry + Vector3(-0.5, 0.05, 0.0)
	op42_site.global_position = entry + Vector3(0.5, 0.05, 0.0)
	for _i in range(60):
		await frames(1)
		if site.objectives.is_complete():
			break
	assert(site.objectives.is_complete(), "All 3 compound objectives completed")
	assert(session.result == -1 and site.mission_result == -1, "Split-world mission stays active until away team returns")
	assert("STARGATE OPEN FOR HOME" in site.hud.objective_label.text)

	for _i in range(60):
		await frames(1)
		if site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE:
			break
	assert(site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE)
	assert(site.stargate_mesh.direction == StargateRing.GateDirection.OUTBOUND)
	assert(site.stargate_mesh.extraction_authorized)
	assert(site.stargate_mesh.event_horizon_mesh.visible)

	# Attempting DHD use while gate is already open informs operative without closing it
	site.dialing_console.start_dialing(op1_site)
	assert("STARGATE OPEN FOR HOME" in site.dialing_console.denial_reason)
	assert(site.stargate_mesh.current_state == StargateRing.GateState.ACTIVE)

	# --- 5. First operative returns home to SGC ramp; second remains offworld -> mission continues
	site.stargate_mesh._on_extraction_entered(op1_site)
	await frames(5)
	assert(site.players_container.get_node_or_null("1") == null, "Host despawned from site")
	var op1_home := home.players_container.get_node_or_null("1") as PlayerController3D
	assert(op1_home != null, "Host respawned in SGC")
	assert(op1_home.global_position.y > 1.8 and absf(op1_home.global_position.z - (-9.5)) < 0.5,
		"Returning operative arrives on SGC Stargate platform, not Armory: " + str(op1_home.global_position))
	assert(op1_home.global_position.distance_to(sgc_gate.global_position) > 4.0,
		"Returning spawn stays outside SGC ExtractionArea")
	assert(session.presented == home and home.is_presented and not site.is_presented)
	assert(session.result == -1, "Mission waits while standing operative (op42) remains offworld")

	# --- 6. Second operative is downed offworld -> zero standing offworld & >=1 came home -> Victory!
	op42_site.health_component.current_health = 10.0
	op42_site.health_component.take_damage(500.0, null, "bullet")
	await frames(5)
	assert(op42_site.health_component.is_downed)
	assert(site.squad_state() == Vector2i(1, 0))
	assert(session.result == 1, "Success rule triggers once no standing operative remains offworld")
	assert(home.mission_result == 1 and site.mission_result == 1)

	# Gates close across both worlds when mission concludes
	assert(home.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(site.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(not site.stargate_mesh.event_horizon_mesh.visible)

	# --- 7. Verify SGC Debrief shows real figures and lost operative callsign
	assert(home.hud.is_mission_ended and site.hud.is_mission_ended)
	assert(home.hud.debrief_title.text == "EXTRACTION SUCCESSFUL")
	assert(home.hud.stat_kills.text == "HOSTILES ELIMINATED: 2", home.hud.stat_kills.text)
	assert(home.hud.stat_waves.text == "OBJECTIVES COMPLETE: 3 / 3", home.hud.stat_waves.text)
	assert("RETURNED: 1 (Major)" in home.hud.stat_chevrons.text, home.hud.stat_chevrons.text)
	assert("LOST: 1 (OPERATIVE 42)" in home.hud.stat_chevrons.text, home.hud.stat_chevrons.text)
	assert("RETURNED WITH LOSSES" in home.hud.stat_status.text, home.hud.stat_status.text)

	# --- 8. Two-world retry after victory
	var old_home := home.get_instance_id()
	var old_site := site.get_instance_id()
	var old_session := session.get_instance_id()
	assert(net.request_restart_game())
	await launch(old_home)
	assert(site.get_instance_id() != old_site and session.get_instance_id() != old_session)
	assert(session.result == -1 and home.mission_result == -1 and site.mission_result == -1)
	var restarted_op1 := home.players_container.get_node_or_null("1") as PlayerController3D
	assert(restarted_op1 != null and restarted_op1.global_position.x > 30.0, "Operative starts back in SGC Armory on retry")
	assert(site.players_container.get_child_count() == 0 and site.objectives.index == 0)
	assert(home.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(site.stargate_mesh.current_state == StargateRing.GateState.INACTIVE)
	assert(site.enemies.get_child_count() == 6)

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()
	print("PASS test_gate_return")
	await preload("res://tests/support/finish.gd").success(self)
