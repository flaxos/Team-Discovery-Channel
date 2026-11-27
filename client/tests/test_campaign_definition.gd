extends SceneTree
## Unit test suite for CampaignDefinition schema, stage structure, and validation rules.

func _init() -> void:
	call_deferred("run")


func run() -> void:
	print("--- Running test_campaign_definition ---")

	# 1. Load canonical campaign resource
	var campaign := load("res://resources/campaigns/operation_hatak_strike.tres") as CampaignDefinition
	assert(campaign != null, "Canonical campaign resource must load")
	assert(campaign.campaign_id == "operation_hatak_strike")
	assert(campaign.title == "Operation Ha'tak Strike")
	assert(campaign.stage_count() == 3)

	var val_errors := campaign.validate()
	assert(val_errors.is_empty(), "Canonical campaign must pass validation: %s" % str(val_errors))

	# 2. Stage retrieval
	var stage0: Dictionary = campaign.get_stage(0)
	assert(stage0.get("stage_id") == "stage_1_intel")
	assert(stage0.get("mission_id") == SGCNetworkManager.MISSION_TRAVEL_INFILTRATION)
	assert(stage0.get("chevron_sequence", []).size() == 7)

	var stage1: Dictionary = campaign.get_stage(1)
	assert(stage1.get("stage_id") == "stage_2_breach")
	assert(stage1.get("mission_id") == SGCNetworkManager.MISSION_TRAVEL_MOTHERSHIP)

	var stage2: Dictionary = campaign.get_stage(2)
	assert(stage2.get("stage_id") == "stage_3_objective")
	assert(stage2.get("mission_id") == SGCNetworkManager.MISSION_MOTHERSHIP_OBJECTIVE)

	var stage_oob: Dictionary = campaign.get_stage(99)
	assert(stage_oob.is_empty(), "Out-of-bounds stage returns empty Dictionary")

	# 3. Validation rejection cases
	var bad_campaign := CampaignDefinition.new()
	var errs := bad_campaign.validate()
	assert(errs.size() >= 3, "Empty campaign yields missing ID, title, and count errors")

	bad_campaign.campaign_id = "test"
	bad_campaign.title = "Test"
	bad_campaign.stages = [
		{
			"stage_id": "s1",
			"stage_title": "T1",
			"mission_id": "invalid_mission_xyz",
			"chevron_sequence": ["UP", "DOWN", "LEFT", "RIGHT", "UP", "DOWN", "LEFT"]
		},
		{
			"stage_id": "s2",
			"stage_title": "T2",
			"mission_id": SGCNetworkManager.MISSION_SGC_DEFENSE,
			"chevron_sequence": ["UP", "BAD_GLYPH"]
		}
	]
	var bad_errs := bad_campaign.validate()
	assert(bad_errs.size() >= 2, "Invalid mission ID and chevron count/glyph yield validation errors: %s" % str(bad_errs))

	print("PASS: test_campaign_definition completed successfully.")
	quit(0)
