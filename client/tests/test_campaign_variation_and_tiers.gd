extends SceneTree
## End-to-end verification suite for Milestone CA-2: Campaign Variation, Difficulty Tiers & Replayability.

const CAMPAIGN_MISSION := SGCNetworkManager.MISSION_CAMPAIGN_OPERATION
const TEST_SAVE_PATH := "user://test_ca2_save.json"
const TEST_RECORDS_PATH := "user://test_ca2_records.json"
const TEST_V1_PATH := "user://test_ca2_v1_save.json"

var net: SGCNetworkManager
var campaign_mgr: SGCCampaignManager
var main: MainGameCoordinator


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame


func launch(previous: int = 0) -> Array:
	var home: GateRoom = null
	for _i: int in range(900):
		var current := main.current_gate_room as GateRoom
		if current != null and current.get_instance_id() != previous and main.current_site != null:
			home = current
			break
		await frames(1)
	assert(home != null, "Both worlds must load for CA-2")
	var site := main.current_site as ModularMission
	assert(site != null and main.session != null)
	if not site.is_started:
		await site.started
	assert(site.setup_errors.is_empty(), str(site.setup_errors))
	assert(site.level.last_errors.is_empty(), str(site.level.last_errors))
	await frames(5)
	return [home, site]


func _cleanup_files() -> void:
	for p: String in [TEST_SAVE_PATH, TEST_RECORDS_PATH, TEST_V1_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func run() -> void:
	print("--- Running test_campaign_variation_and_tiers ---")
	_cleanup_files()
	net = root.get_node("NetworkManager") as SGCNetworkManager
	campaign_mgr = root.get_node("CampaignManager") as SGCCampaignManager
	assert(net != null and campaign_mgr != null)
	campaign_mgr.reset_campaign()

	# 1. Pure scaling math, mutator sanitization, rating & honors
	assert(MissionDifficulty.patrol_size_bonus(MissionDifficulty.TIER_EASY) == 0)
	assert(MissionDifficulty.patrol_size_bonus(MissionDifficulty.TIER_MEDIUM) == 0)
	assert(MissionDifficulty.patrol_size_bonus(MissionDifficulty.TIER_HARD) == 1)
	assert(MissionDifficulty.shield_officer_promotions(MissionDifficulty.TIER_EASY) == 0)
	assert(MissionDifficulty.shield_officer_promotions(MissionDifficulty.TIER_MEDIUM) == 1)
	assert(MissionDifficulty.shield_officer_promotions(MissionDifficulty.TIER_HARD, ["shielded_vanguard"]) == 3)
	assert(is_equal_approx(MissionDifficulty.carryover_min_health(MissionDifficulty.TIER_EASY), 25.0))
	assert(is_equal_approx(MissionDifficulty.carryover_min_health(MissionDifficulty.TIER_HARD), 20.0))
	assert(is_equal_approx(MissionDifficulty.carryover_min_health(MissionDifficulty.TIER_HARD, ["iron_discipline"]), 15.0))
	assert(MissionDifficulty.reinforcement_delay_scale(MissionDifficulty.TIER_HARD, ["rapid_response"]) < 0.55)
	assert(MissionDifficulty.alarm_raise_time_scale(MissionDifficulty.TIER_HARD, ["rapid_response"]) < 0.60)
	assert(MissionDifficulty.sight_notice_scale(MissionDifficulty.TIER_HARD, ["heightened_watch"]) < 0.60)
	assert(MissionDifficulty.timer_duration_scale(MissionDifficulty.TIER_HARD, ["tight_extraction"]) < 0.65)

	var mods: Array[String] = MissionDifficulty.sanitize_modifiers(["RAPID_RESPONSE", "invalid_mod", "rapid_response", "iron_discipline"])
	assert(mods == ["rapid_response", "iron_discipline"], "Invalid or duplicate modifiers must be stripped")

	assert(MissionDifficulty.compute_stage_rating(true, "UNDETECTED", 0, MissionDifficulty.TIER_HARD, mods) == "S")
	assert(MissionDifficulty.compute_stage_rating(false, "ALARM RAISED", 1, MissionDifficulty.TIER_HARD) == "F")
	var camp_eval := MissionDifficulty.compute_campaign_rating([
		{"victory": true, "debrief": {"stealth": "UNDETECTED", "lost_count": 0}, "rating": "S"},
		{"victory": true, "debrief": {"stealth": "UNDETECTED", "lost_count": 0}, "rating": "S"},
		{"victory": true, "debrief": {"stealth": "UNDETECTED", "lost_count": 0}, "rating": "S"}
	], MissionDifficulty.TIER_HARD, mods)
	assert(camp_eval["rating"] == "S")
	var honors: Array = camp_eval["honors"]
	assert(honors.has("GHOST SQUAD"))
	assert(honors.has("NO ONE LEFT BEHIND"))
	assert(honors.has("SYSTEM LORD SLAYER"))
	assert(honors.has("MUTATOR VETERAN"))

	# 2. Validate authored campaign stage MissionDefinitions including objective_variants
	for mission_path: String in [
		"res://resources/missions/goauld_infiltration.tres",
		"res://resources/missions/goauld_mothership_boarding.tres",
		"res://resources/missions/goauld_mothership_objective.tres"
	]:
		var m_def := load(mission_path) as MissionDefinition
		assert(m_def != null, "Load %s" % mission_path)
		var m_errs := m_def.validate()
		assert(m_errs.is_empty(), "%s validation failed: %s" % [mission_path, str(m_errs)])
		assert(m_def.objective_variants.size() >= 3, "%s must provide CA-2 objective variants" % mission_path)

	# 3. CLI parsing (--difficulty, --seed, --modifier)
	var cli := net.parse_cli_arguments(PackedStringArray([
		"--mission", CAMPAIGN_MISSION,
		"--difficulty", "hard",
		"--seed", "424242",
		"--modifier", "shielded_vanguard,rapid_response,unknown"
	]))
	assert(cli.get("mission") == CAMPAIGN_MISSION)
	assert(cli.get("difficulty") == SGCNetworkManager.DIFFICULTY_HARD)
	assert(cli.get("seed") == 424242 and net.run_seed == 424242)
	assert(net.selected_modifiers == ["shielded_vanguard", "rapid_response"])
	net.disconnect_game(true)

	# 4. Lobby UI enables difficulty selector for Campaign & Travel without overflowing 1280x720
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate() as MainGameCoordinator
	root.add_child(main)
	await frames(3)
	var lobby := main.current_lobby as LobbyUI
	assert(lobby != null)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	lobby._update_ui_state()
	assert(lobby.difficulty_option_button.disabled, "Single Greybox Infiltration keeps difficulty locked")
	assert(net.set_mission(CAMPAIGN_MISSION))
	lobby._update_ui_state()
	assert(not lobby.difficulty_option_button.disabled, "Campaign must enable difficulty tier selector")
	for t: int in [0, 1, 2]:
		lobby._on_difficulty_selected(t)
		await process_frame
		assert(lobby.difficulty_description_label.get_global_rect().end.y <= lobby.roster_list.get_global_rect().position.y, "Offworld difficulty label must not overlap roster")
		assert(root.get_visible_rect().encloses(lobby.difficulty_description_label.get_global_rect()))

	# 5. Launch Campaign on EASY with fixed seed 101010 -> baseline sentry count preserved
	lobby._on_difficulty_selected(0)
	net.set_run_variation(101010, [])
	assert(net.host_game(0) == OK)
	lobby._on_start_game_pressed()
	await frames(3)
	var res_easy: Array = await launch()
	var home_easy: GateRoom = res_easy[0] as GateRoom
	var site_easy: ModularMission = res_easy[1] as ModularMission
	assert(site_easy.active_difficulty == SGCNetworkManager.DIFFICULTY_EASY)
	assert(site_easy.enemies.get_child_count() == 6, "Easy keeps baseline 6 sentries on Stage 1")
	assert(campaign_mgr.run_seed == 101010)

	# Verify HARD launch with mutators & non-standard variant, retry reproducibility, and seed variation
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._clear_gate_room()
	net.disconnect_game(true)
	campaign_mgr.reset_campaign()

	# Find a deterministic seed that rolls a non-standard Stage 0 objective variant
	var chosen_seed: int = 0
	for candidate_seed: int in [733101, 733102, 733103, 733104, 733105, 733106, 733107]:
		var stage0_var := MissionDifficulty.build_stage_variant(
			candidate_seed, 0, SGCNetworkManager.DIFFICULTY_HARD,
			[{"id": "standard", "label": "STANDARD DIRECTIVE"}, {"id": "armoury_recon", "label": "ARMOURY CACHE RECON"}, {"id": "observation_sweep", "label": "OBSERVATION DECK SWEEP"}]
		)
		if str(stage0_var.get("objective_variant_id", "")) != "standard":
			chosen_seed = candidate_seed
			break
	assert(chosen_seed > 0, "Expected non-standard objective variant from seed sweep")

	assert(net.set_mission(CAMPAIGN_MISSION))
	assert(net.set_mission_difficulty(SGCNetworkManager.DIFFICULTY_HARD))
	assert(net.set_run_variation(chosen_seed, ["shielded_vanguard", "rapid_response", "iron_discipline"]))
	assert(net.host_game(0) == OK)
	campaign_mgr.start_campaign(null, SGCNetworkManager.DIFFICULTY_HARD, chosen_seed, ["shielded_vanguard", "rapid_response", "iron_discipline"])
	net.request_start_game()
	await frames(3)

	var res_hard: Array = await launch()
	var home_hard: GateRoom = res_hard[0] as GateRoom
	var site_hard: ModularMission = res_hard[1] as ModularMission
	assert(site_hard.enemies.get_child_count() > 6, "Hard increases patrol strength across multi-room patrols")

	var shield_count: int = 0
	var base_guard := (load("res://scenes/entities/JaffaGuard.tscn") as PackedScene).instantiate() as JaffaAI
	var base_notice: float = base_guard.notice_time_near
	base_guard.free()
	var saw_faster_notice: bool = false
	for enemy: Node in site_hard.enemies.get_children():
		var jaffa := enemy as JaffaAI
		if jaffa != null:
			if jaffa.has_personal_shield:
				shield_count += 1
			if jaffa.notice_time_near < base_notice * 0.85:
				saw_faster_notice = true
	assert(shield_count >= 3, "Hard + Shielded Vanguard promotes 3 patrol leads to shielded Horus officers (got %d)" % shield_count)
	assert(saw_faster_notice, "Hard must accelerate sentry visual notice timing")
	assert(site_hard.definition.objectives.size() == 4, "Non-standard variant injects bonus objective into Stage 1 (got %d)" % site_hard.definition.objectives.size())

	var terminal := home_hard.find_child("SGCBriefingTerminal", true, false) as SGCBriefingTerminal
	assert(terminal != null)
	assert("HARD" in terminal.screen_label.text)
	assert(str(chosen_seed) in terminal.screen_label.text)
	assert("Shielded Vanguard" in terminal.screen_label.text)

	var op1_hard := home_hard.players_container.get_node("1") as PlayerController3D
	var hard_plans := site_hard.active_patrol_plans.duplicate(true)

	# Verify retry reproduces identical seed, variant, objective count, and patrol plan
	var old_home_id := home_hard.get_instance_id()
	assert(net.request_restart_game())
	var res_retry: Array = await launch(old_home_id)
	var site_retry: ModularMission = res_retry[1] as ModularMission
	assert(site_retry.active_run_seed == chosen_seed)
	assert(site_retry.definition.objectives.size() == 4)
	assert(site_retry.active_patrol_plans.size() == hard_plans.size())
	assert(site_retry.active_patrol_plans[0]["rooms"] == hard_plans[0]["rooms"], "Retry must reproduce identical patrol route variation")

	# Verify iron_discipline + hard carryover min HP floor (15.0 instead of 25.0)
	var low_hp_state := main.session.capture_state(res_retry[0].players_container.get_node("1") as PlayerController3D)
	low_hp_state["health"] = 5.0
	campaign_mgr.squad_carryover[1] = low_hp_state
	var test_player := res_retry[0].players_container.get_node("1") as PlayerController3D
	assert(campaign_mgr.apply_carryover(test_player))
	assert(is_equal_approx(test_player.health_component.current_health, 15.0), "Hard + Iron Discipline must clamp carryover floor at 15.0 HP")

	# Verify debrief contains TIER & RATING metadata
	var debrief: Dictionary = main.session._build_debrief(true)
	assert("TIER: HARD" in debrief["status"])
	assert("RATING: S" in debrief["status"] or "RATING: A" in debrief["status"])

	# 6. Isolated CampaignManager tests: v1 backward compatibility, v2 roundtrip, career records across reset/replay
	var mgr := SGCCampaignManager.new()
	mgr.name = "IsolatedCA2Mgr"
	root.add_child(mgr)

	var v1_payload := {
		"version": 1,
		"is_campaign_active": true,
		"campaign_id": "operation_hatak_strike",
		"current_stage_index": 1,
		"campaign_completed": false,
		"stage_history": [{"stage_index": 0, "victory": true, "debrief": {"kill_count": 10, "duration_seconds": 90}}],
		"squad_carryover": {}
	}
	var f1 := FileAccess.open(TEST_V1_PATH, FileAccess.WRITE)
	f1.store_string(JSON.stringify(v1_payload))
	f1.close()
	assert(mgr.load_from_disk(TEST_V1_PATH), "Must load legacy CA-1 v1 save cleanly")
	assert(mgr.campaign_difficulty == SGCNetworkManager.DIFFICULTY_EASY)
	assert(mgr.run_seed == 0)

	mgr.clear_records(TEST_RECORDS_PATH)
	mgr.start_campaign(null, SGCNetworkManager.DIFFICULTY_HARD, 551199, ["rapid_response"])
	assert(mgr.save_to_disk(TEST_SAVE_PATH))
	var mgr_reload := SGCCampaignManager.new()
	mgr_reload.name = "IsolatedCA2MgrReload"
	root.add_child(mgr_reload)
	assert(mgr_reload.load_from_disk(TEST_SAVE_PATH))
	assert(mgr_reload.campaign_difficulty == SGCNetworkManager.DIFFICULTY_HARD)
	assert(mgr_reload.run_seed == 551199)
	assert(mgr_reload.active_modifiers == ["rapid_response"])

	for s_i: int in range(3):
		mgr_reload.record_stage_completion({"kill_count": 7, "duration_seconds": 60, "stealth": "UNDETECTED", "lost_count": 0}, true, {})
		if s_i < 2:
			assert(mgr_reload.advance_to_next_stage())
	assert(mgr_reload.campaign_completed)
	var rec := mgr_reload.get_career_records()
	assert(int(rec.get("total_completions", 0)) >= 1)
	assert(rec.get("best_rating") == "S")
	mgr_reload.save_records(TEST_RECORDS_PATH)

	# Resetting campaign preserves career records while clearing active run
	mgr_reload.reset_campaign()
	assert(not mgr_reload.is_campaign_active)
	assert(int(mgr_reload.get_career_records().get("total_completions", 0)) >= 1, "Reset must keep career records")

	mgr_reload.replay_campaign(SGCNetworkManager.DIFFICULTY_MEDIUM, 662288, ["tight_extraction"])
	assert(mgr_reload.is_campaign_active)
	assert(mgr_reload.campaign_difficulty == SGCNetworkManager.DIFFICULTY_MEDIUM)
	assert(mgr_reload.run_seed == 662288)

	# Cleanup
	mgr.clear_records(TEST_RECORDS_PATH)
	mgr.queue_free()
	mgr_reload.queue_free()
	campaign_mgr.reset_campaign()
	campaign_mgr.clear_records()
	_cleanup_files()

	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.queue_free()
	await frames(3)
	net.disconnect_game(true)

	print("PASS: test_campaign_variation_and_tiers completed successfully.")
	await preload("res://tests/support/finish.gd").success(self)
