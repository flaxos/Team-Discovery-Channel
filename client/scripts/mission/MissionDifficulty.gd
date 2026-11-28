class_name MissionDifficulty
extends RefCounted
## Pure static helpers for offworld difficulty tiers, operational mutators,
## deterministic per-run variation, and tactical debrief ratings (Milestone CA-2).
## Deliberately avoids naming autoloads or mission world classes to prevent reference cycles.

const TIER_EASY: int = 0
const TIER_MEDIUM: int = 1
const TIER_HARD: int = 2

const TIER_NAMES: Array[String] = ["Easy", "Medium", "Hard"]

const OFFWORLD_DESCRIPTIONS: Array[String] = [
	"Standard patrols, baseline sentry awareness and standard reinforcement cadence.",
	"Veteran patrols with shielded Horus leads, faster alarm response and heightened watch.",
	"System Lord garrison: reinforced patrols, shielded officers, rapid alarms and strict carryover."
]

const VARIANT_CODES: Array[String] = ["ALPHA", "BRAVO", "CHARLIE", "DELTA"]

const MUTATORS: Dictionary = {
	"shielded_vanguard": {
		"name": "Shielded Vanguard",
		"desc": "Deploys an additional Horus officer equipped with a personal shield."
	},
	"rapid_response": {
		"name": "Rapid Response",
		"desc": "Reduces alarm console raise time and incoming reinforcement delays."
	},
	"heightened_watch": {
		"name": "Heightened Watch",
		"desc": "Enemy sentries acquire visual targets more rapidly."
	},
	"tight_extraction": {
		"name": "Tight Extraction",
		"desc": "Compresses extraction and emergency countdown windows."
	},
	"iron_discipline": {
		"name": "Iron Discipline",
		"desc": "Stricter between-stage trauma recovery floor (15 HP)."
	}
}


static func clamp_tier(tier: int) -> int:
	return clampi(tier, TIER_EASY, TIER_HARD)


static func supports_difficulty_selection(mission_id: String) -> bool:
	return mission_id in [
		"sgc_defense",
		"campaign_operation",
		"travel_infiltration",
		"travel_mothership",
		"mothership_objective"
	]


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clamp_tier(tier)]


static func offworld_description(tier: int) -> String:
	return OFFWORLD_DESCRIPTIONS[clamp_tier(tier)]


static func sanitize_modifiers(raw: Array) -> Array[String]:
	var clean: Array[String] = []
	for item: Variant in raw:
		var key := str(item).strip_edges().to_lower()
		if MUTATORS.has(key) and not clean.has(key):
			clean.append(key)
	return clean


static func modifier_names(modifiers: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for key: String in sanitize_modifiers(modifiers):
		names.append(str(MUTATORS[key]["name"]))
	return names


static func patrol_size_bonus(tier: int) -> int:
	return 1 if clamp_tier(tier) == TIER_HARD else 0


static func shield_officer_promotions(tier: int, modifiers: Array = []) -> int:
	var base: int = 0
	match clamp_tier(tier):
		TIER_MEDIUM:
			base = 1
		TIER_HARD:
			base = 2
	if sanitize_modifiers(modifiers).has("shielded_vanguard"):
		base += 1
	return base


static func should_promote_reinforcement_lead(tier: int, group_index: int, modifiers: Array = []) -> bool:
	var has_vanguard: bool = sanitize_modifiers(modifiers).has("shielded_vanguard")
	match clamp_tier(tier):
		TIER_EASY:
			return has_vanguard and group_index == 0
		TIER_MEDIUM:
			return group_index == 0 or has_vanguard
		TIER_HARD:
			return true
	return false


static func reinforcement_delay_scale(tier: int, modifiers: Array = []) -> float:
	var scale: float = 1.0
	match clamp_tier(tier):
		TIER_MEDIUM:
			scale = 0.80
		TIER_HARD:
			scale = 0.65
	if sanitize_modifiers(modifiers).has("rapid_response"):
		scale *= 0.75
	return maxf(0.40, scale)


static func alarm_raise_time_scale(tier: int, modifiers: Array = []) -> float:
	var scale: float = 1.0
	match clamp_tier(tier):
		TIER_MEDIUM:
			scale = 0.85
		TIER_HARD:
			scale = 0.70
	if sanitize_modifiers(modifiers).has("rapid_response"):
		scale *= 0.80
	return maxf(0.45, scale)


static func timer_duration_scale(tier: int, modifiers: Array = []) -> float:
	var scale: float = 1.0
	match clamp_tier(tier):
		TIER_MEDIUM:
			scale = 0.85
		TIER_HARD:
			scale = 0.75
	if sanitize_modifiers(modifiers).has("tight_extraction"):
		scale *= 0.85
	return maxf(0.50, scale)


static func sight_notice_scale(tier: int, modifiers: Array = []) -> float:
	var scale: float = 1.0
	match clamp_tier(tier):
		TIER_MEDIUM:
			scale = 0.85
		TIER_HARD:
			scale = 0.72
	if sanitize_modifiers(modifiers).has("heightened_watch"):
		scale *= 0.80
	return maxf(0.45, scale)


static func carryover_min_health(tier: int, modifiers: Array = []) -> float:
	if sanitize_modifiers(modifiers).has("iron_discipline"):
		return 15.0
	if clamp_tier(tier) == TIER_HARD:
		return 20.0
	return 25.0


static func build_stage_variant(
	run_seed: int,
	stage_index: int,
	tier: int,
	available_variants: Array = []
) -> Dictionary:
	if run_seed <= 0:
		return {
			"stage_index": stage_index,
			"variant_code": "STANDARD",
			"objective_variant_id": "",
			"objective_variant_label": "STANDARD DIRECTIVE",
			"patrol_seed": 0
		}

	var rng := RandomNumberGenerator.new()
	var mixed_seed: int = int(abs((run_seed * 2654435761 + (stage_index + 1) * 97531 + clamp_tier(tier) * 7919)) & 0x7fffffff)
	if mixed_seed <= 0:
		mixed_seed = 1
	rng.seed = mixed_seed

	var variant_code: String = VARIANT_CODES[rng.randi_range(0, VARIANT_CODES.size() - 1)]
	var obj_id: String = ""
	var obj_label: String = "STANDARD DIRECTIVE"
	var valid_entries: Array[Dictionary] = []
	for entry_v: Variant in available_variants:
		if entry_v is Dictionary:
			var entry: Dictionary = entry_v as Dictionary
			if not str(entry.get("id", "")).is_empty():
				valid_entries.append(entry)
	if not valid_entries.is_empty():
		var chosen: Dictionary = valid_entries[rng.randi_range(0, valid_entries.size() - 1)]
		obj_id = str(chosen.get("id", ""))
		obj_label = str(chosen.get("label", obj_id.to_upper()))
	var patrol_seed: int = rng.randi_range(1, 2147483646)

	return {
		"stage_index": stage_index,
		"variant_code": variant_code,
		"objective_variant_id": obj_id,
		"objective_variant_label": obj_label,
		"patrol_seed": patrol_seed
	}


## `definition` and `patrol` stay typed as `Resource` so MissionDifficulty remains a leaf class
## and never closes a GDScript reference cycle with SGCNetworkManager via MissionDefinition ->
## LevelRoomComposer -> StargateRing (which causes resources still in use at exit).
static func resolve_patrol_plans(
	definition: Resource,
	tier: int,
	run_seed: int,
	stage_index: int,
	modifiers: Array = []
) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	if definition == null:
		return plans
	var raw_patrols: Variant = definition.get(&"patrols")
	if not (raw_patrols is Array):
		return plans
	var patrols_arr: Array = raw_patrols as Array

	var clean_tier: int = clamp_tier(tier)
	var clean_mods: Array[String] = sanitize_modifiers(modifiers)
	var eligible_indices: Array[int] = []

	for p: int in range(patrols_arr.size()):
		var patrol: Resource = patrols_arr[p] as Resource
		if patrol == null:
			continue
		var raw_rooms: Variant = patrol.get(&"rooms")
		var rooms: PackedStringArray = (raw_rooms as PackedStringArray).duplicate() if raw_rooms is PackedStringArray else PackedStringArray()
		var route_reversed: bool = false
		var start_offset: int = 0

		if run_seed > 0 and rooms.size() >= 2:
			var rng := RandomNumberGenerator.new()
			var p_seed: int = int(abs((run_seed * 1103515245 + (stage_index + 1) * 12345 + p * 31337)) & 0x7fffffff)
			if p_seed <= 0:
				p_seed = 1
			rng.seed = p_seed

			if rng.randf() < 0.5:
				route_reversed = true
				var rev := PackedStringArray()
				for ri: int in range(rooms.size() - 1, -1, -1):
					rev.append(rooms[ri])
				rooms = rev

			start_offset = rng.randi_range(0, rooms.size() - 1)
			if start_offset > 0:
				var rotated := PackedStringArray()
				for ri: int in range(rooms.size()):
					rotated.append(rooms[(ri + start_offset) % rooms.size()])
				rooms = rotated

		var base_size: int = int(patrol.get(&"size"))
		var bonus: int = patrol_size_bonus(clean_tier) if rooms.size() >= 2 else 0
		var final_size: int = mini(3, base_size + bonus) if bonus > 0 else base_size
		var marker_val: StringName = patrol.get(&"marker") as StringName
		var use_shock: bool = bool(patrol.get(&"shock_guard"))
		var has_shield: bool = bool(patrol.get(&"personal_shield"))
		var role_val: String = str(patrol.get(&"combat_role")) if patrol.get(&"combat_role") != null else "trooper"
		var lead_role_val: String = str(patrol.get(&"lead_role")) if patrol.get(&"lead_role") != null else ""
		var boss_name_val: String = str(patrol.get(&"boss_name")) if patrol.get(&"boss_name") != null else ""

		var plan := {
			"index": p,
			"rooms": rooms,
			"marker": marker_val,
			"base_size": base_size,
			"size": final_size,
			"shock_guard": use_shock,
			"personal_shield": has_shield,
			"combat_role": role_val,
			"lead_role": lead_role_val,
			"boss_name": boss_name_val,
			"promoted_lead_shield": false,
			"route_reversed": route_reversed,
			"start_offset": start_offset
		}
		plans.append(plan)
		if not has_shield:
			eligible_indices.append(plans.size() - 1)

	var promotions_left: int = shield_officer_promotions(clean_tier, clean_mods)
	if promotions_left > 0 and not eligible_indices.is_empty():
		var ordered_candidates: Array[int] = eligible_indices.duplicate()
		if run_seed > 0 and ordered_candidates.size() > 1:
			var promo_rng := RandomNumberGenerator.new()
			var s: int = int(abs((run_seed * 48271 + (stage_index + 1) * 997 + clean_tier * 131)) & 0x7fffffff)
			promo_rng.seed = maxi(1, s)
			for i: int in range(ordered_candidates.size() - 1, 0, -1):
				var j: int = promo_rng.randi_range(0, i)
				var tmp: int = ordered_candidates[i]
				ordered_candidates[i] = ordered_candidates[j]
				ordered_candidates[j] = tmp
		for idx: int in ordered_candidates:
			if promotions_left <= 0:
				break
			plans[idx]["promoted_lead_shield"] = true
			promotions_left -= 1

	return plans


static func compute_stage_rating(
	victory: bool,
	stealth: String,
	lost_count: int,
	tier: int,
	modifiers: Array = []
) -> String:
	if not victory:
		return "F"
	var score: int = 100
	if stealth == "UNDETECTED":
		score += 25
	elif "NO ALARM" in stealth:
		score += 10
	else:
		score -= 15
	score -= 20 * maxi(0, lost_count)
	score += 10 * clamp_tier(tier)
	score += 5 * sanitize_modifiers(modifiers).size()

	if score >= 115:
		return "S"
	if score >= 95:
		return "A"
	if score >= 75:
		return "B"
	return "C"


static func rating_rank(rating: String) -> int:
	return int({"S": 4, "A": 3, "B": 2, "C": 1, "F": 0}.get(rating, 0))


static func compute_campaign_rating(
	stage_history: Array,
	tier: int,
	modifiers: Array = []
) -> Dictionary:
	var clean_tier: int = clamp_tier(tier)
	var clean_mods: Array[String] = sanitize_modifiers(modifiers)
	var stages_won: int = 0
	var all_undetected: bool = true
	var zero_losses: bool = true
	var score_sum: int = 0

	for record_v: Variant in stage_history:
		if not (record_v is Dictionary):
			continue
		var record: Dictionary = record_v as Dictionary
		if not bool(record.get("victory", false)):
			continue
		stages_won += 1
		var debrief: Dictionary = record.get("debrief", {})
		var stealth: String = str(debrief.get("stealth", ""))
		if stealth.is_empty():
			var status_str: String = str(debrief.get("status", ""))
			if "ALARM RAISED" in status_str:
				stealth = "ALARM RAISED"
			elif "SPOTTED" in status_str:
				stealth = "SPOTTED, NO ALARM"
			else:
				stealth = "UNDETECTED"
		if stealth != "UNDETECTED":
			all_undetected = false
		var lost_count: int = int(debrief.get("lost_count", 0))
		if lost_count > 0:
			zero_losses = false
		var stage_rating: String = str(record.get("rating", ""))
		if stage_rating.is_empty():
			stage_rating = compute_stage_rating(true, stealth, lost_count, clean_tier, clean_mods)
		score_sum += rating_rank(stage_rating)

	var honors: Array[String] = []
	if stages_won == 0:
		return {"rating": "F", "honors": honors}

	var avg_rank: float = float(score_sum) / float(stages_won)
	var overall_rating: String = "C"
	if avg_rank >= 3.5:
		overall_rating = "S"
	elif avg_rank >= 2.5:
		overall_rating = "A"
	elif avg_rank >= 1.5:
		overall_rating = "B"

	if all_undetected:
		honors.append("GHOST SQUAD")
	if zero_losses:
		honors.append("NO ONE LEFT BEHIND")
	if clean_tier == TIER_HARD:
		honors.append("SYSTEM LORD SLAYER")
	if not clean_mods.is_empty():
		honors.append("MUTATOR VETERAN")

	return {
		"rating": overall_rating,
		"honors": honors
	}
