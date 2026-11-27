class_name MissionDefinition
extends Resource
## Data for a modular mission: the level, its ordered objectives, its patrols and how the
## compound responds once it knows the squad is there. Shown in the HUD banner while it runs.
@export var title: String = ""
@export var layout: LevelLayout
@export var objectives: Array[MissionObjective] = []
@export var patrols: Array[MissionPatrol] = []
## Consoles an alerted Jaffa can reach to raise the alarm. None: the alarm cannot be raised.
@export var alarms: Array[MissionAlarm] = []
## Jaffa that arrive after the alarm. Needs at least one alarm console.
@export var reinforcements: Array[MissionReinforcement] = []
## One-shot objective/alarm conditions that release security doors or start extraction time.
@export var triggers: Array[MissionTrigger] = []
## Optional Airman fireteam staged on either side of the authored entry marker.
@export var airman_support := false
## Optional per-run objective variations (Milestone CA-2).
@export var objective_variants: Array[MissionObjectiveVariant] = []


func objective_variant_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for variant: MissionObjectiveVariant in objective_variants:
		if variant != null and not str(variant.id).is_empty():
			entries.append({"id": str(variant.id), "label": variant.label})
	return entries


func find_variant(variant_id: StringName) -> MissionObjectiveVariant:
	if str(variant_id).is_empty():
		return null
	for variant: MissionObjectiveVariant in objective_variants:
		if variant != null and variant.id == variant_id:
			return variant
	return null


## Returns `Resource` (not `MissionDefinition`) because naming its own class inside a script
## creates a GDScript reference cycle with LevelRoomComposer/StargateRing that leaks at exit.
func with_variant(variant_id: StringName) -> Resource:
	if str(variant_id).is_empty() or variant_id == &"standard":
		return self
	var variant: MissionObjectiveVariant = find_variant(variant_id)
	if variant == null or variant.bonus_objectives.is_empty():
		return self
	var copy: Resource = duplicate(false)
	if copy == null:
		return self
	var existing_ids := {}
	for existing_obj: MissionObjective in objectives:
		if existing_obj != null and existing_obj.id != &"":
			existing_ids[existing_obj.id] = true
	var next_objectives: Array[MissionObjective] = []
	var inserted := false
	for obj: MissionObjective in objectives:
		if not inserted and obj != null and variant.insert_before_id != &"" and obj.id == variant.insert_before_id:
			for bonus: MissionObjective in variant.bonus_objectives:
				if bonus != null and not existing_ids.has(bonus.id):
					next_objectives.append(bonus)
					existing_ids[bonus.id] = true
			inserted = true
		next_objectives.append(obj)
	if not inserted:
		var fallback: Array[MissionObjective] = []
		for i: int in range(next_objectives.size()):
			var obj: MissionObjective = next_objectives[i]
			if not inserted and obj != null and obj.kind == "extract":
				for bonus: MissionObjective in variant.bonus_objectives:
					if bonus != null and not existing_ids.has(bonus.id):
						fallback.append(bonus)
						existing_ids[bonus.id] = true
				inserted = true
			fallback.append(obj)
		next_objectives = fallback
	var empty_variants: Array[MissionObjectiveVariant] = []
	copy.set(&"objectives", next_objectives)
	copy.set(&"objective_variants", empty_variants)
	return copy


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if layout == null or objectives.is_empty():
		errors.append("Mission needs a layout and at least one objective")
		return errors
	var ids := {}
	for objective in objectives:
		if objective == null or objective.id == &"" or ids.has(objective.id):
			errors.append("Duplicate/empty objective id")
			continue
		ids[objective.id] = true
		var item := layout.instance(objective.room)
		if item == null:
			errors.append("Unknown objective room: %s/%s" % [objective.id, objective.room])
		elif objective.kind == "interact" and attachment(objective) == null:
			errors.append(
				"Unknown objective attachment: %s/%s" % [objective.room, objective.attachment]
			)
	if objectives[-1] != null and objectives[-1].kind != "extract":
		errors.append("The final objective must be an extraction")
	for patrol in patrols:
		if patrol == null or patrol.rooms.is_empty():
			errors.append("Empty patrol")
			continue
		for room in patrol.rooms:
			if layout.instance(StringName(room)) == null:
				errors.append("Unknown patrol room: " + room)
	var consoles := {}
	for alarm in alarms:
		if alarm == null or room_attachment(alarm.room, alarm.attachment) == null:
			errors.append(
				"Unknown alarm console: %s/%s"
				% ([alarm.room, alarm.attachment] if alarm != null else ["?", "?"])
			)
			continue
		var key := "%s/%s" % [alarm.room, alarm.attachment]
		for objective in objectives:
			if objective.kind == "interact" and "%s/%s" % [objective.room, objective.attachment] == key:
				errors.append("Alarm console is also an objective: " + key)
		if consoles.has(key):
			errors.append("Duplicate alarm console: " + key)
		consoles[key] = true
	for group in reinforcements:
		if group == null or room_attachment(group.room, group.attachment) == null:
			errors.append(
				"Unknown reinforcement point: %s/%s"
				% ([group.room, group.attachment] if group != null else ["?", "?"])
			)
	if not reinforcements.is_empty() and alarms.is_empty():
		errors.append("Reinforcements need at least one alarm console")
	var trigger_ids := {}
	var door_ids := {}
	var timer_count := 0
	for trigger in triggers:
		if trigger == null:
			errors.append("Null mission trigger")
			continue
		if str(trigger.id).strip_edges().is_empty() or trigger_ids.has(trigger.id):
			errors.append("Duplicate/empty mission trigger id: %s" % trigger.id)
		trigger_ids[trigger.id] = true
		if trigger.condition == "alarm_raised":
			if trigger.objective_id != &"":
				errors.append("Alarm trigger cannot also name an objective: %s" % trigger.id)
			if alarms.is_empty():
				errors.append("Alarm trigger needs an alarm console: %s" % trigger.id)
			if trigger.action != "start_timer":
				errors.append("Alarm trigger supports start_timer only: %s" % trigger.id)
		elif trigger.condition != "objective_completed":
			errors.append("Unknown mission condition: %s/%s" % [trigger.id, trigger.condition])
		elif not ids.has(trigger.objective_id):
			errors.append("Unknown trigger objective: %s/%s" % [trigger.id, trigger.objective_id])
		else:
			for objective in objectives:
				if objective != null and objective.id == trigger.objective_id and objective.kind == "extract":
					errors.append("Mission action must precede extraction: %s" % trigger.id)
		if trigger.action == "start_timer":
			timer_count += 1
			if not is_finite(trigger.duration_seconds) or trigger.duration_seconds <= 0.0 or trigger.duration_seconds > 86400.0:
				errors.append("Timer duration must be finite and within (0, 86400]: %s" % trigger.id)
			if trigger.timer_label.strip_edges().is_empty():
				errors.append("Timer needs a label: %s" % trigger.id)
			if trigger.security_id != &"":
				errors.append("Timer cannot also target a security door: %s" % trigger.id)
			continue
		if trigger.action != "release_door":
			errors.append("Unknown mission action: %s/%s" % [trigger.id, trigger.action])
			continue
		var matches := 0
		for connection in layout.connections:
			if connection.state == "security_door" and connection.security_id == trigger.security_id:
				matches += 1
		if str(trigger.security_id).strip_edges().is_empty() or matches != 1:
			errors.append("Trigger needs one named security door: %s/%s" % [trigger.id, trigger.security_id])
		if door_ids.has(trigger.security_id):
			errors.append("Security door has multiple release triggers: %s" % trigger.security_id)
		door_ids[trigger.security_id] = true
	if timer_count > 1:
		errors.append("Mission supports one extraction timer")
	if errors.is_empty() and not triggers.is_empty():
		# Prove the authored sequence can earn each release. In particular, a console
		# cannot be placed behind the door that only that console can unlock.
		var links := LevelTopology.graph(layout)
		for edges: Array in links.values():
			for edge: Dictionary in edges:
				if door_ids.has(StringName(edge.security_id)):
					edge.locked = true
		var previous := str(layout.entry_instance)
		for objective in objectives:
			if LevelTopology.path(links, previous, str(objective.room), [], true).is_empty():
				errors.append("Mission doors block objective: %s" % objective.id)
			for trigger in triggers:
				if trigger.condition == "objective_completed" and trigger.action == "release_door" and trigger.objective_id == objective.id:
					for edges: Array in links.values():
						for edge: Dictionary in edges:
							if edge.security_id == str(trigger.security_id):
								edge.locked = false
			previous = str(objective.room)

	var variant_ids := {}
	for variant: MissionObjectiveVariant in objective_variants:
		if variant == null or str(variant.id).strip_edges().is_empty() or variant_ids.has(variant.id):
			errors.append("Duplicate/empty objective variant id")
			continue
		variant_ids[variant.id] = true
		if variant.label.strip_edges().is_empty():
			errors.append("Objective variant needs a label: %s" % variant.id)
		if not variant.bonus_objectives.is_empty():
			var applied: Resource = with_variant(variant.id)
			var empty_variants: Array[MissionObjectiveVariant] = []
			applied.set(&"objective_variants", empty_variants)
			for err: String in (applied.call(&"validate") as PackedStringArray):
				errors.append("Variant %s: %s" % [variant.id, err])
	return errors


func attachment(objective: MissionObjective) -> LevelRoomAttachment:
	return room_attachment(objective.room, objective.attachment)


## The resolved attachment `id` of layout room `room`, or null.
func room_attachment(room: StringName, id: StringName) -> LevelRoomAttachment:
	var item := layout.instance(room)
	if item != null:
		for value in LevelRoomComposer.resolved(item):
			if value.id == id:
				return value
	return null
