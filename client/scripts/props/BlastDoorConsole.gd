class_name BlastDoorConsole
extends CSGBox3D
## Interactive SGC Hydraulic Blast Door Control Console.
## Installed adjacent to all primary blast door portals (Central, West, East).
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
		prompt_label.text = "[E] TOGGLE BLAST DOORS"
		prompt_label.font_size = 18
		prompt_label.outline_size = 4
		prompt_label.position = Vector3(0, 0.9, 0)
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_label.modulate = Color(0.2, 0.9, 0.3)
		add_child(prompt_label)

	var gr := get_tree().root.find_child("GateRoom", true, false)
	if gr != null and gr.has_signal("blast_doors_toggled"):
		gr.blast_doors_toggled.connect(_on_doors_toggled)


func interact(_operative: Node = null) -> void:
	if is_locked:
		print("BlastDoorConsole [%s]: Console is LOCKED by base lockdown!" % door_id)
		return

	var gr := get_tree().root.find_child("GateRoom", true, false)
	if gr != null and gr.has_method("toggle_blast_doors"):
		gr.toggle_blast_doors()


func _on_doors_toggled(closed: bool) -> void:
	if console_light != null:
		console_light.light_color = Color(1.0, 0.2, 0.2) if closed else Color(0.2, 0.9, 0.3)
	if prompt_label != null:
		prompt_label.modulate = Color(1.0, 0.3, 0.3) if closed else Color(0.2, 0.9, 0.3)
		prompt_label.text = "[E] OPEN BLAST DOORS" if closed else "[E] SEAL BLAST DOORS"
	blast_door_toggled.emit(closed)
