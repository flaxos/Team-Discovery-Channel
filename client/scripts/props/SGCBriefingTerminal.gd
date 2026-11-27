class_name SGCBriefingTerminal
extends Node3D
## Interactive Briefing Terminal in SGC Level 27 Briefing Room.
## Displays live campaign status, stage briefing, gate chevron coordinates,
## and operational history to SG operatives.

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null
@onready var screen_label: Label3D = $ScreenLabel if has_node("ScreenLabel") else null
@onready var status_light: OmniLight3D = $StatusLight if has_node("StatusLight") else null

var active_player: PlayerController3D = null


func _ready() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr != null:
		if campaign_mgr.has_signal(&"campaign_state_synced") and not campaign_mgr.is_connected(&"campaign_state_synced", _update_display):
			campaign_mgr.connect(&"campaign_state_synced", _update_display)
		if campaign_mgr.has_signal(&"campaign_stage_advanced") and not campaign_mgr.is_connected(&"campaign_stage_advanced", _on_campaign_stage_advanced):
			campaign_mgr.connect(&"campaign_stage_advanced", _on_campaign_stage_advanced)
		if campaign_mgr.has_signal(&"campaign_completed_event") and not campaign_mgr.is_connected(&"campaign_completed_event", _on_campaign_completed):
			campaign_mgr.connect(&"campaign_completed_event", _on_campaign_completed)
		if campaign_mgr.has_signal(&"campaign_reset_event") and not campaign_mgr.is_connected(&"campaign_reset_event", _update_display):
			campaign_mgr.connect(&"campaign_reset_event", _update_display)

	_update_display()


func _exit_tree() -> void:
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if campaign_mgr == null:
		return
	if campaign_mgr.has_signal(&"campaign_state_synced") and campaign_mgr.is_connected(&"campaign_state_synced", _update_display):
		campaign_mgr.disconnect(&"campaign_state_synced", _update_display)
	if campaign_mgr.has_signal(&"campaign_stage_advanced") and campaign_mgr.is_connected(&"campaign_stage_advanced", _on_campaign_stage_advanced):
		campaign_mgr.disconnect(&"campaign_stage_advanced", _on_campaign_stage_advanced)
	if campaign_mgr.has_signal(&"campaign_completed_event") and campaign_mgr.is_connected(&"campaign_completed_event", _on_campaign_completed):
		campaign_mgr.disconnect(&"campaign_completed_event", _on_campaign_completed)
	if campaign_mgr.has_signal(&"campaign_reset_event") and campaign_mgr.is_connected(&"campaign_reset_event", _update_display):
		campaign_mgr.disconnect(&"campaign_reset_event", _update_display)


func _on_campaign_stage_advanced(_idx: int, _data: Dictionary) -> void:
	_update_display()


func _on_campaign_completed(_summary: Dictionary) -> void:
	_update_display()


func _on_body_entered(body: Node3D) -> void:
	var player := body as PlayerController3D
	if player != null and (not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority()):
		active_player = player
		if prompt_label != null:
			prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body == active_player:
		active_player = null
		if prompt_label != null:
			prompt_label.visible = false


func interact(player: PlayerController3D) -> void:
	if not is_instance_valid(player):
		return
	_update_display()
	print("SGCBriefingTerminal: Accessed by operative %s" % player.name)


func _update_display() -> void:
	var campaign_mgr: Node = get_node_or_null("/root/CampaignManager")
	if screen_label == null:
		return

	if campaign_mgr == null or not campaign_mgr.get("is_campaign_active"):
		var standby := "SGC MISSION BRIEFING TERMINAL\n=================================\nSTATUS: STANDBY — ALL QUIET\nNO ACTIVE CAMPAIGN OPERATION\n\nAccess lobby or select Campaign Mode\nto initiate an expeditionary directive."
		if campaign_mgr != null and campaign_mgr.has_method(&"get_career_records"):
			var rec: Dictionary = campaign_mgr.call(&"get_career_records")
			var clears: int = int(rec.get("total_completions", 0))
			if clears > 0:
				standby += "\n\nSERVICE RECORD: %d CLEARED | BEST: %s (%s)" % [
					clears,
					str(rec.get("best_rating", "A")),
					str(rec.get("highest_difficulty_name", "Easy")).to_upper()
				]
		screen_label.text = standby
		screen_label.modulate = Color(0.4, 0.8, 1.0)
		if status_light != null:
			status_light.light_color = Color(0.2, 0.6, 1.0)
		return

	var is_completed: bool = campaign_mgr.get("campaign_completed")
	var stage_idx: int = int(campaign_mgr.get("current_stage_index"))
	var stage_data: Dictionary = campaign_mgr.call(&"get_current_stage")
	var campaign_title: String = str(campaign_mgr.get("active_campaign").title) if campaign_mgr.get("active_campaign") != null else "OPERATION"
	var tier_label: String = MissionDifficulty.tier_name(int(campaign_mgr.get("campaign_difficulty"))).to_upper()
	var seed_val: int = int(campaign_mgr.get("run_seed"))
	var mods: PackedStringArray = MissionDifficulty.modifier_names(campaign_mgr.get("active_modifiers"))
	var mod_line: String = "" if mods.is_empty() else "\nMUTATORS: %s" % ", ".join(mods)

	if is_completed:
		var summary: Dictionary = campaign_mgr.call(&"get_campaign_summary")
		var honors: Array = summary.get("honors", [])
		var honors_line: String = "" if honors.is_empty() else "\nHONORS: %s" % ", ".join(honors)
		screen_label.text = "CAMPAIGN VICTORY — %s\n=================================\nALL %d OPERATIONAL STAGES ACCOMPLISHED\nTIER: %s | RATING: %s | SEED: #%d%s\nTOTAL HOSTILES ELIMINATED: %d%s\nSTATUS: MISSION COMPLETE — SGC SECURE" % [
			campaign_title.to_upper(),
			int(summary.get("total_stages", 0)),
			tier_label,
			str(summary.get("rating", "A")),
			seed_val,
			mod_line,
			int(summary.get("total_kills", 0)),
			honors_line
		]
		screen_label.modulate = Color(0.2, 1.0, 0.4)
		if status_light != null:
			status_light.light_color = Color(0.2, 1.0, 0.3)
		return

	var stage_title: String = str(stage_data.get("stage_title", "Stage %d" % (stage_idx + 1)))
	var chevrons: Array = stage_data.get("chevron_sequence", [])
	var glyph_str := "  >  ".join(chevrons)
	var targets: String = str(stage_data.get("target_objectives_summary", ""))
	var stage_var: Dictionary = campaign_mgr.call(&"get_stage_variant", stage_idx) if campaign_mgr.has_method(&"get_stage_variant") else {}
	var var_label: String = str(stage_var.get("objective_variant_label", "STANDARD DIRECTIVE"))

	screen_label.text = "%s — STAGE %d\n=================================\n%s\nTIER: %s | SEED: #%d | VARIANT: %s%s\n\nOBJECTIVES:\n%s\n\nGATE ADDRESS:\n[ %s ]" % [
		campaign_title.to_upper(),
		stage_idx + 1,
		stage_title,
		tier_label,
		seed_val,
		var_label,
		mod_line,
		targets,
		glyph_str
	]
	screen_label.modulate = Color(1.0, 0.85, 0.3)
	if status_light != null:
		status_light.light_color = Color(1.0, 0.7, 0.2)
