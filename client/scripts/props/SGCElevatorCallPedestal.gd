class_name SGCElevatorCallPedestal
extends Node3D
## Interactive SGC Elevator Call Pedestal & Cabin Panel Script.
## Positioned on either side of the freight elevator doors (Level 28 and 27)
## and inside the elevator cabin for floor dispatch.

@export var target_floor: int = 28
@export var is_cabin_panel: bool = false
@export var elevator_path: NodePath = ".."

@onready var pedestal_light: OmniLight3D = $PedestalLight if has_node("PedestalLight") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else ($Label28 if has_node("Label28") else ($Label27 if has_node("Label27") else ($Label28Right if has_node("Label28Right") else ($Label27Right if has_node("Label27Right") else null))))


func _ready() -> void:
	add_to_group("interactable")
	if prompt_label != null:
		if is_cabin_panel:
			prompt_label.text = "[E] DISPATCH LIFT"
		else:
			prompt_label.text = "[E] CALL LIFT"
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func interact(_player: Node = null) -> void:
	var elev: SGCElevator = get_node_or_null(elevator_path) as SGCElevator
	if elev == null:
		elev = get_parent() as SGCElevator
	if elev == null and get_parent() != null:
		elev = get_parent().get_parent() as SGCElevator

	if elev == null:
		print("SGCElevatorCallPedestal: Elevator reference not found!")
		return

	# Responsive feedback flash on pedestal light
	if pedestal_light != null:
		var orig_energy := pedestal_light.light_energy
		pedestal_light.light_energy = 3.0
		var tw := create_tween()
		if tw != null:
			tw.tween_property(pedestal_light, "light_energy", orig_energy, 0.3)

	if is_cabin_panel:
		print("SGCElevatorCallPedestal: Cabin dispatch panel pressed by %s." % (_player.name if _player != null else "operative"))
		elev.toggle_elevator()
	else:
		print("SGCElevatorCallPedestal: Floor %d call button pressed by %s." % [target_floor, _player.name if _player != null else "operative"])
		elev.call_elevator(target_floor)
