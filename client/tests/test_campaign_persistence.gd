extends SceneTree
## Test suite for CampaignManager lifecycle, stage advancement, squad carryover, and disk persistence.

const TEST_SAVE_PATH: String = "user://test_campaign_save.json"

func _init() -> void:
	call_deferred("run")


func run() -> void:
	print("--- Running test_campaign_persistence ---")

	var mgr := SGCCampaignManager.new()
	mgr.name = "TestCampaignManager"
	root.add_child(mgr)

	# 1. Start campaign
	mgr.start_campaign()
	assert(mgr.is_campaign_active, "Campaign should be active after start")
	assert(mgr.active_campaign != null, "Active campaign must be loaded")
	assert(mgr.current_stage_index == 0, "Initial stage is 0")
	assert(mgr.get_current_mission_id() == SGCNetworkManager.MISSION_TRAVEL_INFILTRATION)

	var stage0_chevrons := mgr.get_current_chevron_sequence()
	assert(stage0_chevrons.size() == 7, "Chevron sequence must have 7 glyphs")

	# 2. Stage 0 completion with squad state carryover
	var mock_debrief := {
		"title": "EXTRACTION SUCCESSFUL",
		"kill_count": 14,
		"duration_seconds": 185
	}
	var mock_squad := {
		1: {
			"health": 110.0,
			"max_health": 150.0,
			"active_slot": 1,
			"weapons": {
				"m249": {"current_ammo": 75, "reserve_ammo": 200, "current_heat": 0.0, "is_overheated": false}
			},
			"c4_charges_remaining": 2,
			"claymore_charges": 1
		}
	}

	mgr.record_stage_completion(mock_debrief, true, mock_squad)
	assert(mgr.stage_history.size() == 1, "One stage recorded")
	assert(mgr.stage_history[0]["victory"] == true)
	assert(mgr.has_carryover(1), "Carryover stored for peer 1")
	assert(mgr.get_carryover(1)["health"] == 110.0)
	assert(not mgr.campaign_completed, "Campaign not yet complete after stage 0")

	# 3. Advance to Stage 1
	var advanced := mgr.advance_to_next_stage()
	assert(advanced, "Stage advancement should succeed")
	assert(mgr.current_stage_index == 1)
	assert(mgr.get_current_mission_id() == SGCNetworkManager.MISSION_TRAVEL_MOTHERSHIP)

	# 4. Save to disk and reload in a fresh manager instance
	var saved := mgr.save_to_disk(TEST_SAVE_PATH)
	assert(saved, "Save to disk should succeed")

	var mgr2 := SGCCampaignManager.new()
	mgr2.name = "TestCampaignManager2"
	root.add_child(mgr2)

	var loaded := mgr2.load_from_disk(TEST_SAVE_PATH)
	assert(loaded, "Load from disk should succeed")
	assert(mgr2.is_campaign_active == true)
	assert(mgr2.current_stage_index == 1)
	assert(mgr2.get_current_mission_id() == SGCNetworkManager.MISSION_TRAVEL_MOTHERSHIP)
	assert(mgr2.stage_history.size() == 1)
	assert(mgr2.has_carryover(1) == true)
	assert(mgr2.get_carryover(1)["health"] == 110.0)

	# 5. Complete Stage 1 and Stage 2 to verify Campaign Completion
	mgr2.record_stage_completion(mock_debrief, true, mock_squad)
	assert(mgr2.current_stage_index == 1)
	assert(not mgr2.campaign_completed)

	advanced = mgr2.advance_to_next_stage()
	assert(advanced)
	assert(mgr2.current_stage_index == 2)
	assert(mgr2.get_current_mission_id() == SGCNetworkManager.MISSION_MOTHERSHIP_OBJECTIVE)

	# Complete final stage
	mgr2.record_stage_completion(mock_debrief, true, mock_squad)
	assert(mgr2.campaign_completed, "Campaign must be marked completed after final stage victory")

	var summary := mgr2.get_campaign_summary()
	assert(summary["completed"] == true)
	assert(summary["total_stages"] == 3)
	assert(summary["stages_won"] == 3)
	assert(summary["total_kills"] == 42) # 14 * 3

	# Attempt to advance past final stage
	assert(not mgr2.advance_to_next_stage(), "Cannot advance past final stage")

	# 6. Reset campaign
	mgr2.reset_campaign()
	assert(not mgr2.is_campaign_active)
	assert(mgr2.stage_history.is_empty())
	assert(mgr2.current_stage_index == 0)

	# Cleanup test file
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	mgr.queue_free()
	mgr2.queue_free()

	print("PASS: test_campaign_persistence completed successfully.")
	quit(0)
