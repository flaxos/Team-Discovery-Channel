class_name SGCCampaignManager
extends Node
## Central manager for multi-stage operational campaigns (Milestone CA-1).
## Tracks active campaign progression, stage outcomes, squad inventory carryover,
## and host-authoritative persistence to disk (Decision D-007).

signal campaign_started(campaign_id: String)
signal campaign_stage_advanced(stage_index: int, stage_data: Dictionary)
signal campaign_completed_event(summary: Dictionary)
signal campaign_reset_event()
signal campaign_state_synced()

const DEFAULT_SAVE_PATH: String = "user://campaign_save.json"
const CANONICAL_CAMPAIGN_PATH: String = "res://resources/campaigns/operation_hatak_strike.tres"

var active_campaign: CampaignDefinition = null
var is_campaign_active: bool = false
var current_stage_index: int = 0
var stage_history: Array[Dictionary] = []
var squad_carryover: Dictionary = {}
var campaign_completed: bool = false


func _ready() -> void:
	# Connect to peer connection events to sync campaign state to new joiners
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server() and is_campaign_active:
		sync_campaign_state.rpc_id(peer_id, get_state_snapshot())


func start_campaign(def: CampaignDefinition = null) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		push_warning("CampaignManager: Only server can start a campaign.")
		return

	if def == null:
		def = load(CANONICAL_CAMPAIGN_PATH) as CampaignDefinition
	if def == null:
		push_error("CampaignManager: Failed to load campaign definition.")
		return

	var errors := def.validate()
	if not errors.is_empty():
		push_error("CampaignManager: Campaign validation failed: %s" % str(errors))
		return

	active_campaign = def
	is_campaign_active = true
	current_stage_index = 0
	stage_history.clear()
	squad_carryover.clear()
	campaign_completed = false

	var current_mission_id := get_current_mission_id()
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not current_mission_id.is_empty():
		net.set_mission(current_mission_id)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	campaign_started.emit(active_campaign.campaign_id)
	save_to_disk()
	print("CampaignManager: Started campaign '%s' (%s), stage 0: %s" % [
		active_campaign.campaign_id, active_campaign.title, current_mission_id
	])


func get_current_stage() -> Dictionary:
	if active_campaign == null or not is_campaign_active:
		return {}
	return active_campaign.get_stage(current_stage_index)


func get_current_mission_id() -> String:
	var stage := get_current_stage()
	return stage.get("mission_id", "")


func get_current_chevron_sequence() -> Array:
	var stage := get_current_stage()
	return stage.get("chevron_sequence", [])


func record_stage_completion(debrief: Dictionary, victory: bool, captured_states: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_campaign_active or active_campaign == null:
		return

	var current_stage := get_current_stage()
	var record := {
		"stage_index": current_stage_index,
		"stage_id": current_stage.get("stage_id", ""),
		"stage_title": current_stage.get("stage_title", ""),
		"mission_id": current_stage.get("mission_id", ""),
		"victory": victory,
		"debrief": debrief,
		"timestamp": Time.get_unix_time_from_system()
	}
	stage_history.append(record)

	if victory:
		squad_carryover = captured_states.duplicate(true)
		if current_stage_index + 1 >= active_campaign.stage_count():
			campaign_completed = true
			var summary := get_campaign_summary()
			campaign_completed_event.emit(summary)
			print("CampaignManager: CAMPAIGN COMPLETED! All %d stages successful." % active_campaign.stage_count())

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	save_to_disk()


func advance_to_next_stage() -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		push_warning("CampaignManager: Only server can advance campaign stage.")
		return false
	if not is_campaign_active or active_campaign == null or campaign_completed:
		return false

	if current_stage_index + 1 >= active_campaign.stage_count():
		return false

	current_stage_index += 1
	var next_stage := get_current_stage()
	var next_mission_id := str(next_stage.get("mission_id", ""))

	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and not next_mission_id.is_empty():
		net.set_mission(next_mission_id)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())

	campaign_stage_advanced.emit(current_stage_index, next_stage)
	save_to_disk()
	print("CampaignManager: Advanced to stage %d: %s (%s)" % [
		current_stage_index, next_stage.get("stage_title", ""), next_mission_id
	])
	return true


func reset_campaign() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	is_campaign_active = false
	current_stage_index = 0
	stage_history.clear()
	squad_carryover.clear()
	campaign_completed = false
	active_campaign = null

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_campaign_state.rpc(get_state_snapshot())
	campaign_reset_event.emit()

	# Remove saved state on disk
	if FileAccess.file_exists(DEFAULT_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEFAULT_SAVE_PATH))
	print("CampaignManager: Campaign reset cleanly.")


func has_carryover(peer_id: int) -> bool:
	return squad_carryover.has(peer_id) or squad_carryover.has(str(peer_id))


func get_carryover(peer_id: int) -> Dictionary:
	if squad_carryover.has(peer_id):
		return squad_carryover[peer_id]
	if squad_carryover.has(str(peer_id)):
		return squad_carryover[str(peer_id)]
	return {}


func apply_carryover(player: PlayerController3D) -> bool:
	if not is_instance_valid(player):
		return false
	var state := get_carryover(player.peer_id)
	if state.is_empty():
		return false

	# Apply weapons and reserve counts
	if state.has("weapons"):
		for wid: String in state["weapons"]:
			var w_data: Dictionary = state["weapons"][wid]
			if not player._weapon_inventory.has(wid):
				player._equip_weapon_by_id(wid)
			var w: WeaponBase = player._weapon_inventory.get(wid) as WeaponBase
			if is_instance_valid(w):
				w.current_ammo = w_data.get("current_ammo", w.current_ammo)
				w.reserve_ammo = w_data.get("reserve_ammo", w.reserve_ammo)
				w.current_heat = w_data.get("current_heat", w.current_heat)
				w.is_overheated = w_data.get("is_overheated", false)
				w.is_reloading = false

	if state.has("active_slot"):
		player._equip_slot_local(state["active_slot"])
	if player.current_weapon != null:
		player.weapon_ammo_changed.emit(player.current_weapon.current_ammo, player.current_weapon.reserve_ammo)
	player._broadcast_weapon_state()

	# Apply health, preserving partial damage from prior stage (minimum 25.0 HP for survival)
	var health: HealthComponent = player.health_component
	if health != null:
		if state.has("max_health"):
			health.max_health = state["max_health"]
		if state.has("health"):
			health.current_health = maxf(25.0, float(state["health"]))
		health.is_downed = false
		health.is_dead = false
		health.is_stunned = false
		health.health_changed.emit(health.current_health, health.max_health)
		health._publish_state()

	# Apply tactical supplies
	player.turret_cooldown = state.get("turret_cooldown", 0.0)
	player.claymore_charges = state.get("claymore_charges", player.claymore_charges)
	player.c4_charges_remaining = state.get("c4_charges_remaining", player.c4_charges_remaining)
	player.smoke_grenades_count = state.get("smoke_grenades_count", player.smoke_grenades_count)
	player.deployable_shields_count = state.get("deployable_shields_count", player.deployable_shields_count)
	return true


func get_campaign_summary() -> Dictionary:
	var total_kills := 0
	var total_duration := 0
	var stages_won := 0
	for record: Dictionary in stage_history:
		if record.get("victory", false):
			stages_won += 1
		var debrief: Dictionary = record.get("debrief", {})
		total_kills += int(debrief.get("kill_count", 0))
		total_duration += int(debrief.get("duration_seconds", 0))

	return {
		"campaign_id": active_campaign.campaign_id if active_campaign != null else "",
		"title": active_campaign.title if active_campaign != null else "",
		"total_stages": active_campaign.stage_count() if active_campaign != null else 0,
		"stages_won": stages_won,
		"completed": campaign_completed,
		"total_kills": total_kills,
		"total_duration_seconds": total_duration,
		"stage_history": stage_history
	}


func get_state_snapshot() -> Dictionary:
	return {
		"is_campaign_active": is_campaign_active,
		"campaign_id": active_campaign.campaign_id if active_campaign != null else "",
		"current_stage_index": current_stage_index,
		"campaign_completed": campaign_completed,
		"stage_history": stage_history,
		"squad_carryover": squad_carryover
	}


@rpc("authority", "call_local", "reliable")
func sync_campaign_state(state: Dictionary) -> void:
	is_campaign_active = state.get("is_campaign_active", false)
	current_stage_index = int(state.get("current_stage_index", 0))
	campaign_completed = state.get("campaign_completed", false)
	stage_history = state.get("stage_history", [])
	squad_carryover = state.get("squad_carryover", {})

	var cid: String = state.get("campaign_id", "")
	if not cid.is_empty():
		if active_campaign == null or active_campaign.campaign_id != cid:
			if cid == "operation_hatak_strike":
				active_campaign = load(CANONICAL_CAMPAIGN_PATH) as CampaignDefinition
	else:
		active_campaign = null

	campaign_state_synced.emit()


func save_to_disk(path: String = DEFAULT_SAVE_PATH) -> bool:
	var data := {
		"version": 1,
		"is_campaign_active": is_campaign_active,
		"campaign_id": active_campaign.campaign_id if active_campaign != null else "",
		"current_stage_index": current_stage_index,
		"campaign_completed": campaign_completed,
		"stage_history": stage_history,
		"squad_carryover": squad_carryover
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("CampaignManager: Could not open %s for saving: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	var json_str := JSON.stringify(data, "\t")
	file.store_string(json_str)
	file.close()
	return true


func load_from_disk(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_warning("CampaignManager: Failed to parse campaign save from %s." % path)
		return false

	var data: Dictionary = json.data as Dictionary
	if data == null or not data.has("is_campaign_active"):
		return false

	is_campaign_active = bool(data.get("is_campaign_active", false))
	current_stage_index = int(data.get("current_stage_index", 0))
	campaign_completed = bool(data.get("campaign_completed", false))
	stage_history.clear()
	for record: Variant in data.get("stage_history", []):
		if record is Dictionary:
			stage_history.append(record)
	squad_carryover = data.get("squad_carryover", {})

	var cid: String = data.get("campaign_id", "")
	if not cid.is_empty():
		if cid == "operation_hatak_strike":
			active_campaign = load(CANONICAL_CAMPAIGN_PATH) as CampaignDefinition
	else:
		active_campaign = null

	if is_campaign_active and active_campaign != null:
		var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
		var cur_mission := get_current_mission_id()
		if net != null and not cur_mission.is_empty():
			net.set_mission(cur_mission)

	campaign_state_synced.emit()
	print("CampaignManager: Loaded campaign save from %s (stage %d)." % [path, current_stage_index])
	return true
