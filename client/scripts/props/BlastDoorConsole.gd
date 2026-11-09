class_name BlastDoorConsole
extends CSGBox3D
const Interaction = preload("res://scripts/net/ServerInteraction.gd")
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
		prompt_label.text = _bindings().format_prompt(
			(
				"[E] TOGGLE OBSERVATION BLAST SHUTTERS"
				if door_id == "observation"
				else "[E] TOGGLE BLAST DOORS"
			)
		)
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

	if door_id == "control_observation":
		prompt_label.text = _bindings().format_prompt("[E] CONTROL WINDOW BLAST SHUTTER")
	var gr: Node = _room()
	if gr != null:
		if door_id == "control_observation":
			gr.connect("control_window_toggled", _on_doors_toggled)
		elif door_id == "observation":
			if gr.has_signal("observation_shutters_toggled"):
				gr.connect("observation_shutters_toggled", _on_doors_toggled)
			elif gr.has_signal("blast_doors_toggled"):
				gr.connect("blast_doors_toggled", _on_doors_toggled)
		else:
			if gr.has_signal("blast_doors_toggled"):
				gr.connect("blast_doors_toggled", _on_doors_toggled)


func _room() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is GateRoom:
			return node
		node = node.get_parent()
	return null


func interact(operative: Node = null) -> void:
	if is_locked:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if operative is PlayerController3D:
			request_interact.rpc_id(1, get_path_to(operative))
		return
	_apply_interaction()


@rpc("any_peer", "call_local", "reliable")
func request_interact(player_path: NodePath) -> void:
	if not is_locked and Interaction.resolve(self, player_path) != null:
		_apply_interaction()


func _apply_interaction() -> void:
	var room: Node = _room()
	if room != null:
		if door_id == "control_observation":
			room.toggle_control_window()
		elif door_id == "observation":
			room.toggle_observation_shutters()
		else:
			room.toggle_blast_doors()


func _on_doors_toggled(closed: bool) -> void:
	if console_light != null:
		console_light.light_color = Color(1.0, 0.2, 0.2) if closed else Color(0.2, 0.9, 0.3)
	if prompt_label != null:
		prompt_label.modulate = Color(1.0, 0.3, 0.3) if closed else Color(0.2, 0.9, 0.3)
		if door_id == "control_observation":
			prompt_label.text = _bindings().format_prompt(
				"[E] OPEN CONTROL WINDOW SHUTTER" if closed else "[E] CLOSE CONTROL WINDOW SHUTTER"
			)
		elif door_id == "observation":
			prompt_label.text = _bindings().format_prompt(
				"[E] OPEN OBSERVATION SHUTTERS" if closed else "[E] LOWER OBSERVATION SHUTTERS"
			)
		else:
			prompt_label.text = _bindings().format_prompt(
				"[E] OPEN BLAST DOORS" if closed else "[E] SEAL BLAST DOORS"
			)
	blast_door_toggled.emit(closed)


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")
