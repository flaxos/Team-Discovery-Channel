extends SceneTree
## Full end-to-end integration test for Milestone CA-1: Campaign Progression & Linked Mission Chains.
## Validates:
## 1. Launching MISSION_CAMPAIGN_OPERATION with CampaignManager active.
## 2. Level 27 Briefing Terminal live status and chevron address display.
## 3. SGC Dialing Computer fixed chevron sequence alignment with campaign stage.
## 4. Stage 1 completion, debrief badges, and squad state capture into carryover.
## 5. Advancement to Stage 2 with carried inventory and health applied to SGC spawn.
## 6. Advancement to Stage 3 and final Campaign Victory completion.

const MISSION := SGCNetworkManager.MISSION_CAMPAIGN_OPERATION
var net: SGCNetworkManager
var main: MainGameCoordinator
var home: GateRoom
var site: ModularMission
var session: MissionSession
var campaign_mgr: SGCCampaignManager


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


func run() -> void:
	print("--- Running test_campaign_progression ---")
	net = root.get_node("NetworkManager") as SGCNetworkManager
	campaign_mgr = root.get_node("CampaignManager") as SGCCampaignManager
	assert(net != null and campaign_mgr != null, "Autoloads must be present")

	# Clean reset before test
	campaign_mgr.reset_campaign()

	assert(net.parse_cli_arguments(PackedStringArray(["--mission", MISSION])).get("mission") == MISSION)
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)

	var lobby := main.current_lobby as LobbyUI
	assert(lobby != null, "Lobby loads")
	assert(net.host_game(0) == OK)

	# Verify lobby displays campaign
	assert(net.selected_mission_id == MISSION)
	lobby._on_start_game_pressed()
	await frames(3)
	await launch()

	# --- 1. Stage 0 (Stage 1 of 3: Infiltration & Intel Recovery)
	assert(campaign_mgr.is_campaign_active, "CampaignManager is active")
	assert(campaign_mgr.current_stage_index == 0)
	var stage0 := campaign_mgr.get_current_stage()
	assert(stage0.get("stage_id") == "stage_1_intel")

	# Verify Briefing Terminal exists and reflects Stage 1
	var terminal: SGCBriefingTerminal = home.find_child("SGCBriefingTerminal", true, false) as SGCBriefingTerminal
	assert(terminal != null, "Briefing Terminal must be present in SGC Level 27")
	assert("STAGE 1" in terminal.screen_label.text)
	assert("OPERATION HA'TAK STRIKE" in terminal.screen_label.text)

	# Verify SGC dialer uses Stage 0 chevron sequence
	var op1 := home.players_container.get_node("1") as PlayerController3D
	assert(op1 != null, "Host player spawned")
	var dialer := home.dhd_console
	assert(dialer != null)
	op1.global_position = dialer.global_position + Vector3(0, 0, 1.0)
	dialer.start_dialing(op1)
	assert(dialer.current_phase == DHDDialer.DialPhase.CHEVRONS)
	assert(dialer.chevron_sequence == stage0.get("chevron_sequence"), "Dialer sequence must match campaign stage address")
	dialer.cancel_dialing()

	# Simulate stage 0 victory with squad carryover
	op1.health_component.current_health = 95.0
	op1.switch_slot(1)
	if op1.current_weapon != null:
		op1.current_weapon.current_ammo = 42
		op1.current_weapon.reserve_ammo = 150
	op1.c4_charges_remaining = 1
	op1.claymore_charges = 2

	var captured_state := session.capture_state(op1)
	var mock_debrief := {
		"title": "EXTRACTION SUCCESSFUL",
		"kill_count": 8,
		"duration_seconds": 120
	}
	campaign_mgr.record_stage_completion(mock_debrief, true, {1: captured_state})

	# Verify debrief wording for campaign stage 0
	var debrief_dict: Dictionary = session._build_debrief(true)
	assert("STAGE 1 SECURED" in debrief_dict["title"])
	assert("PROCEED TO NEXT STAGE (STAGE 2/3)" == debrief_dict["leave"])

	# --- 2. Advance to Stage 1 (Stage 2 of 3: Mothership Cargo Bay Breach)
	assert(campaign_mgr.advance_to_next_stage())
	assert(campaign_mgr.current_stage_index == 1)
	var stage1 := campaign_mgr.get_current_stage()
	assert(stage1.get("stage_id") == "stage_2_breach")

	# Reload session for Stage 1
	var old_home := home.get_instance_id()
	assert(net.request_restart_game())
	await launch(old_home)

	# Verify operative spawned with Stage 0 carried inventory and health
	var op1_stage1 := home.players_container.get_node("1") as PlayerController3D
	assert(op1_stage1 != null)
	assert(op1_stage1.health_component.current_health == 95.0, "Carried health must be preserved across stages")
	assert(op1_stage1.c4_charges_remaining == 1, "Carried C4 charges preserved")
	assert(op1_stage1.claymore_charges == 2, "Carried claymores preserved")

	# Verify Briefing Terminal updated to Stage 2
	terminal = home.find_child("SGCBriefingTerminal", true, false) as SGCBriefingTerminal
	assert(terminal != null)
	assert("STAGE 2" in terminal.screen_label.text)

	# Verify SGC dialer uses Stage 1 chevron sequence
	dialer = home.dhd_console
	op1_stage1.global_position = dialer.global_position + Vector3(0, 0, 1.0)
	dialer.start_dialing(op1_stage1)
	assert(dialer.chevron_sequence == stage1.get("chevron_sequence"), "Stage 2 dialer sequence matches campaign stage address")
	dialer.cancel_dialing()

	# --- 3. Advance to Stage 2 (Stage 3 of 3: Bridge & Reactor Sabotage)
	campaign_mgr.record_stage_completion(mock_debrief, true, {1: captured_state})
	assert(campaign_mgr.advance_to_next_stage())
	assert(campaign_mgr.current_stage_index == 2)
	var stage2 := campaign_mgr.get_current_stage()
	assert(stage2.get("stage_id") == "stage_3_objective")

	old_home = home.get_instance_id()
	assert(net.request_restart_game())
	await launch(old_home)

	# Complete final stage
	campaign_mgr.record_stage_completion(mock_debrief, true, {1: captured_state})
	assert(campaign_mgr.campaign_completed, "Campaign must be marked completed")

	# Verify final victory debrief
	var final_debrief: Dictionary = session._build_debrief(true)
	assert("CAMPAIGN VICTORY — OPERATION COMPLETE" in final_debrief["title"])
	assert("FINALIZE CAMPAIGN" == final_debrief["leave"])

	# Briefing Terminal displays Campaign Victory
	terminal = home.find_child("SGCBriefingTerminal", true, false) as SGCBriefingTerminal
	assert(terminal != null)
	assert("CAMPAIGN VICTORY" in terminal.screen_label.text)

	# Clean reset and teardown
	campaign_mgr.reset_campaign()
	assert(not campaign_mgr.is_campaign_active)

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game()

	print("PASS: test_campaign_progression completed successfully.")
	await preload("res://tests/support/finish.gd").success(self)
