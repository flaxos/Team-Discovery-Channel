class_name IrisServoHousing
extends Node3D
## SGC Gate Room Manual Iris Servo Housing.
## Tactical sub-mission: Allows operatives under fire to manually release the jammed
## Trinium Iris gear assembly at the Stargate base, sealing off inbound reinforcements.

signal repair_progress(progress: float)
signal iris_repaired()

@export var repair_time_required: float = 6.0
@export var is_repaired: bool = false

var current_repair_time: float = 0.0
var is_repairing: bool = false
var repairer_player: PlayerController3D = null

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var servo_light: OmniLight3D = $ServoLight if has_node("ServoLight") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func start_repair(player: PlayerController3D) -> void:
	if is_repaired:
		return
	repairer_player = player
	is_repairing = true
	current_repair_time = 0.0
	print("IrisServoHousing: Operative %s started manual Iris servo override..." % player.name)


func cancel_repair() -> void:
	if is_repairing:
		print("IrisServoHousing: Iris servo repair interrupted!")
		is_repairing = false
		current_repair_time = 0.0
		repairer_player = null


func update_repair(delta: float) -> bool:
	if not is_repairing or is_repaired:
		return false

	current_repair_time += delta
	var progress: float = clampf(current_repair_time / repair_time_required, 0.0, 1.0)
	repair_progress.emit(progress)

	if current_repair_time >= repair_time_required:
		complete_repair()
		return true
	return false


func complete_repair() -> void:
	is_repairing = false
	is_repaired = true
	current_repair_time = 0.0
	repairer_player = null
	iris_repaired.emit()
	print("IrisServoHousing: TRINIUM IRIS OVERRIDE ENGAGED! Iris snapped SHUT! Gate room secured!")

	if servo_light != null:
		servo_light.light_color = Color(0.1, 0.9, 0.3)
		servo_light.light_energy = 3.0
	if prompt_label != null:
		prompt_label.text = "IRIS SECURED (CLOSED)"
		prompt_label.modulate = Color(0.2, 0.95, 0.4)

	_play_sfx("res://audio/sfx_iris_open.wav", 40.0)


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_repaired and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = "[E] MANUAL IRIS SERVO OVERRIDE (6s)"


func _on_body_exited(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and not is_repaired and player.is_local_authority:
		if prompt_label != null:
			prompt_label.text = "IRIS SERVO HOUSING"


func _play_sfx(path: String, max_dist: float) -> void:
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 10.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
