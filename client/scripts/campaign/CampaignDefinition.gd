class_name CampaignDefinition
extends Resource
## Data resource defining a multi-stage operational campaign in Stargate SG Extraction.
## Sits above single-mission definitions, sequencing operations with carried squad state,
## persistent debrief records, unlocked gate addresses, and narrative progression.

@export var campaign_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var stages: Array[Dictionary] = []


func get_stage(index: int) -> Dictionary:
	if index >= 0 and index < stages.size():
		return stages[index]
	return {}


func stage_count() -> int:
	return stages.size()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if campaign_id.strip_edges().is_empty():
		errors.append("CampaignDefinition: campaign_id cannot be empty.")
	if title.strip_edges().is_empty():
		errors.append("CampaignDefinition: title cannot be empty.")
	if stages.size() < 2:
		errors.append("CampaignDefinition: campaign requires at least 2 stages, found %d." % stages.size())

	var valid_glyphs := ["UP", "DOWN", "LEFT", "RIGHT"]
	for i in range(stages.size()):
		var stage: Dictionary = stages[i]
		var stage_id: String = stage.get("stage_id", "")
		var mission_id: String = stage.get("mission_id", "")
		var stage_title: String = stage.get("stage_title", "")
		if stage_id.is_empty():
			errors.append("Stage %d: missing stage_id." % i)
		if stage_title.is_empty():
			errors.append("Stage %d: missing stage_title." % i)
		if mission_id.is_empty():
			errors.append("Stage %d: missing mission_id." % i)
		elif not SGCNetworkManager.MISSIONS.has(mission_id):
			errors.append("Stage %d (%s): unknown mission_id '%s'." % [i, stage_id, mission_id])

		var chevrons: Array = stage.get("chevron_sequence", [])
		if chevrons.size() != DHDDialer.TOTAL_CHEVRONS:
			errors.append("Stage %d (%s): chevron_sequence must contain exactly %d glyphs, got %d." % [i, stage_id, DHDDialer.TOTAL_CHEVRONS, chevrons.size()])
		else:
			for g: Variant in chevrons:
				if not str(g) in valid_glyphs:
					errors.append("Stage %d (%s): invalid glyph '%s' in chevron_sequence." % [i, stage_id, str(g)])

		if stage.has("objective_variants"):
			var raw_variants: Variant = stage.get("objective_variants")
			if not (raw_variants is Array):
				errors.append("Stage %d (%s): objective_variants must be an Array." % [i, stage_id])
			else:
				for v_entry: Variant in raw_variants:
					if not (v_entry is Dictionary):
						errors.append("Stage %d (%s): objective_variants entries must be Dictionaries." % [i, stage_id])
					else:
						var v_dict: Dictionary = v_entry as Dictionary
						if str(v_dict.get("id", "")).strip_edges().is_empty() or str(v_dict.get("label", "")).strip_edges().is_empty():
							errors.append("Stage %d (%s): objective variant entry requires non-empty id and label." % [i, stage_id])
	return errors
