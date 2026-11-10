class_name MissionDefinition
extends Resource
## Data for a modular mission: the level, its ordered objectives and its patrols.
@export var layout: LevelLayout
@export var objectives: Array[MissionObjective] = []
@export var patrols: Array[MissionPatrol] = []


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
	return errors


func attachment(objective: MissionObjective) -> LevelRoomAttachment:
	var item := layout.instance(objective.room)
	if item != null:
		for value in LevelRoomComposer.resolved(item):
			if value.id == objective.attachment:
				return value
	return null
