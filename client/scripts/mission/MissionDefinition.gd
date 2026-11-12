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
