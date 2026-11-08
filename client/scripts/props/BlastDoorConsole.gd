class_name BlastDoorConsole
extends CSGBox3D
## Interactive SGC Hydraulic Blast Door Control Console.
## Installed adjacent to all primary blast door portals (Central, West, East)
## and in the Briefing Room for the Observation Lounge Overlook Blast Shutters.
## Allows manual emergency sealing and opening of blast doors with glowing status indicators.

signal blast_door_toggled(is_closed: bool)

@export var door_id: String = "all"
@export var is_locked: bool = false

@onready var console_light: OmniLight3D = $ConsoleLight if has_node("ConsoleLight") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("blast_door_console")

	if prompt_label == null:
		prompt_label = Label3D.new()
		prompt_label.name = "PromptLabel"
		prompt_label.text = _bindings().format_prompt("[E] TOGGLE OBSERVATION BLAST SHUTTERS" if door_id == "observation" else "[E] TOGGLE BLAST DOORS")
		prompt_label.font_size = 18
		prompt_label.outline_size = 4
		prompt_label.position = Vector3(0, 0.9, 0)
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_label.modulate = Color(0.2, 0.9, 0.3)
		add_child(prompt_label)
	else:
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		if door_id == "observation":
			prompt_label.text = _bindings().format_prompt("[E] TOGGLE OBSERVATION BLAST SHUTTERS")

	var gr: Node = get_tree().root.find_child("GateRoom", true, false)
	if gr != null:
		if door_id == "observation":
			if gr.has_signal("observation_shutters_toggled"):
				gr.connect("observation_shutters_toggled", _on_doors_toggled)
			elif gr.has_signal("blast_doors_toggled"):
				gr.connect("blast_doors_toggled", _on_doors_toggled)
		else:
			if gr.has_signal("blast_doors_toggled"):
				gr.connect("blast_doors_toggled", _on_doors_toggled)


func interact(_operative: Node = null) -> void:
	if is_locked:
		print("BlastDoorConsole [%s]: Console is LOCKED by base lockdown!" % door_id)
		return

	var gr: Node = get_tree().root.find_child("GateRoom", true, false)
	if gr != null:
		if door_id == "observation" and gr.has_method("toggle_observation_shutters"):
			gr.call("toggle_observation_shutters")
		elif gr.has_method("toggle_blast_doors"):
			gr.call("toggle_blast_doors")


func _on_doors_toggled(closed: bool) -> void:
	if console_light != null:
		console_light.light_color = Color(1.0, 0.2, 0.2) if closed else Color(0.2, 0.9, 0.3)
	if prompt_label != null:
		prompt_label.modulate = Color(1.0, 0.3, 0.3) if closed else Color(0.2, 0.9, 0.3)
		if door_id == "observation":
			prompt_label.text = _bindings().format_prompt("[E] OPEN OBSERVATION SHUTTERS" if closed else "[E] LOWER OBSERVATION SHUTTERS")
		else:
			prompt_label.text = _bindings().format_prompt("[E] OPEN BLAST DOORS" if closed else "[E] SEAL BLAST DOORS")
	blast_door_toggled.emit(closed)


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")
