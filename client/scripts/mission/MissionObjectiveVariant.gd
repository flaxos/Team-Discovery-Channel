class_name MissionObjectiveVariant
extends Resource
## Optional per-run objective variation inserted before a designated mission step (Milestone CA-2).
## Bonus steps reuse existing MissionObjective room/marker rules without altering layout files.

@export var id: StringName = &""
@export var label: String = ""
@export_multiline var briefing_note: String = ""
@export var insert_before_id: StringName = &"extract"
@export var bonus_objectives: Array[MissionObjective] = []
