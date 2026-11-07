class_name LabDataPatchDrive
extends Node3D
## SGC Level 28 Optical ROM Data Patch Drive.
## Hard Mode Climax Objective: Contains clean dialing software to purge Goa'uld buffer lockout.
## An operative interacts to retrieve the ROM and escorts it back to the Control Room Mezzanine.

signal patch_retrieved(carrier: PlayerController3D)
signal patch_dropped(carrier: PlayerController3D)

@export var is_retrieved: bool = false
var carrier_player: PlayerController3D = null

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var rom_mesh: MeshInstance3D = $ROMMesh if has_node("ROMMesh") else null
@onready var glow_light: OmniLight3D = $GlowLight if has_node("GlowLight") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func pickup_patch(player: PlayerController3D) -> void:
	if is_retrieved:
		return

	is_retrieved = true
	carrier_player = player
	if rom_mesh != null:
		rom_mesh.visible = false
	if glow_light != null:
		glow_light.visible = false
	if prompt_label != null:
		prompt_label.visible = false

	print("LabDataPatchDrive: Clean dialing ROM retrieved by %s! ESCORT TO CONTROL ROOM MAINFRAME!" % player.name)
	patch_retrieved.emit(player)
	_play_sfx("res://audio/sfx_gdo_beep.wav", 25.0)


func reset_patch() -> void:
	is_retrieved = false
	carrier_player = null
	if rom_mesh != null:
		rom_mesh.visible = true
	if glow_light != null:
		glow_light.visible = true
	if prompt_label != null:
		prompt_label.visible = true


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_retrieved and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = "[E] RETRIEVE CLEAN DIALING ROM"


func _on_body_exited(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_retrieved and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = "SGC OPTICAL ROM DRIVE"


func _play_sfx(path: String, max_dist: float) -> void:
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 10.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
