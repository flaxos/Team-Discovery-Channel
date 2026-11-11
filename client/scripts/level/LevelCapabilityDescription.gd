@tool
class_name LevelCapabilityDescription
extends Resource
@export var id: StringName
@export var label: String
@export_multiline var description: String
@export var synonyms: PackedStringArray = []
## Designer intent, not measured in play. Physical facts are derived from the module.
@export var gameplay_roles: PackedStringArray = []
@export var sightlines: String = ""
