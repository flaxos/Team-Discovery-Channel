class_name StargateRing
extends Node3D
## SGC Cheyenne Mountain Level 28 Stargate Ring & Event Horizon Controller.
## Coordinates 7-chevron sequential locking, the unstable forward Kawoosh vortex,
## and wormhole stabilization for extraction.

signal chevron_locked(chevron_index: int)
signal kawoosh_erupted()
signal wormhole_opened()
signal wormhole_closed()
signal player_extracted(player: Node)

enum GateState { INACTIVE, DIALING, KAWOOSH, ACTIVE }

@export var max_chevrons: int = 7
@export var kawoosh_reach_m: float = 4.5
@export var kawoosh_duration_s: float = 1.2

var current_state: GateState = GateState.INACTIVE
var locked_chevrons_count: int = 0

@onready var event_horizon_mesh: MeshInstance3D = $EventHorizon if has_node("EventHorizon") else null
@onready var kawoosh_area: Area3D = $KawooshArea if has_node("KawooshArea") else null
@onready var kawoosh_mesh: MeshInstance3D = $KawooshArea/VortexMesh if has_node("KawooshArea/VortexMesh") else null
@onready var extraction_area: Area3D = $ExtractionArea if has_node("ExtractionArea") else null
@onready var chevron_container: Node3D = $Chevrons if has_node("Chevrons") else null
@onready var gate_light: OmniLight3D = $GateLight if has_node("GateLight") else null


func _ready() -> void:
	if kawoosh_area != null:
		kawoosh_area.monitoring = false
		kawoosh_area.body_entered.connect(_on_kawoosh_hit_body)
	if extraction_area != null:
		extraction_area.body_entered.connect(_on_extraction_entered)
	if kawoosh_mesh != null:
		kawoosh_mesh.visible = false
	if event_horizon_mesh != null:
		event_horizon_mesh.visible = false


func _on_extraction_entered(body: Node) -> void:
	if current_state == GateState.ACTIVE and body is PlayerController3D:
		print("Stargate: Operative %s stepped into active event horizon! Extraction sequence initiated!" % body.name)
		player_extracted.emit(body)


## Locks an individual chevron in sequence (1 through 7)
func lock_chevron(chevron_idx: int) -> void:
	if not multiplayer.is_server():
		return
	rpc("sync_lock_chevron", chevron_idx)


@rpc("call_local", "reliable")
func sync_lock_chevron(chevron_idx: int) -> void:
	locked_chevrons_count = maxi(locked_chevrons_count, chevron_idx)
	current_state = GateState.DIALING

	# Light up corresponding chevron visual
	if chevron_container != null and chevron_idx <= chevron_container.get_child_count():
		var chev := chevron_container.get_child(chevron_idx - 1) as GeometryInstance3D
		if chev != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.45, 0.05)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.45, 0.05)
			mat.emission_energy_multiplier = 4.0
			chev.material_override = mat

	# Flash orange light at chevron lock
	if gate_light != null:
		gate_light.light_color = Color(1.0, 0.5, 0.1)
		gate_light.light_energy = 3.5
		var tween := gate_light.create_tween()
		tween.tween_property(gate_light, "light_energy", 1.0, 0.3)

	chevron_locked.emit(chevron_idx)
	print("Stargate: Chevron %d LOCKED!" % chevron_idx)
	_play_sfx("res://audio/sfx_chevron.wav", 70.0)

	# If 7th chevron locked, trigger the Kawoosh!
	if chevron_idx >= max_chevrons and multiplayer.is_server():
		trigger_kawoosh()


## Triggers the unstable forward vortex (Kawoosh), vaporizing anything in front
func trigger_kawoosh() -> void:
	if not multiplayer.is_server():
		return
	rpc("sync_trigger_kawoosh")


@rpc("call_local", "reliable")
func sync_trigger_kawoosh() -> void:
	current_state = GateState.KAWOOSH
	kawoosh_erupted.emit()
	print("Stargate: KAWOOSH! Event horizon erupting forward!")
	_play_sfx("res://audio/sfx_kawoosh.wav", 100.0)

	if gate_light != null:
		gate_light.light_color = Color(0.2, 0.7, 1.0)
		gate_light.light_energy = 8.0

	if event_horizon_mesh != null:
		event_horizon_mesh.visible = true

	# Enable lethal forward vaporization hitbox
	if kawoosh_area != null:
		kawoosh_area.monitoring = true
	if kawoosh_mesh != null:
		kawoosh_mesh.visible = true
		kawoosh_mesh.scale = Vector3(0.1, 0.1, 0.1)
		var tween := create_tween()
		# Erupt forward
		tween.tween_property(kawoosh_mesh, "scale", Vector3(1.0, 1.0, 1.0), kawoosh_duration_s * 0.45)
		# Retract back into stable vertical puddle
		tween.tween_property(kawoosh_mesh, "scale", Vector3(0.01, 0.01, 0.01), kawoosh_duration_s * 0.55)
		tween.tween_callback(func() -> void:
			if kawoosh_mesh != null:
				kawoosh_mesh.visible = false
			if kawoosh_area != null:
				kawoosh_area.monitoring = false
			_stabilize_wormhole()
		)


func _stabilize_wormhole() -> void:
	current_state = GateState.ACTIVE
	wormhole_opened.emit()
	print("Stargate: Wormhole stabilized! Extraction aperture open.")
	if gate_light != null:
		gate_light.light_energy = 2.5


func _on_kawoosh_hit_body(body: Node) -> void:
	if current_state != GateState.KAWOOSH:
		return

	# Canonical Stargate rule: The unstable vortex dissolves anything in its path
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and not health.is_dead:
		print("Stargate Kawoosh vaporized entity: %s" % body.name)
		health.take_damage(9999.0, self, "kawoosh_vortex")
		health.vaporized.emit()


func close_wormhole() -> void:
	if not multiplayer.is_server():
		return
	rpc("sync_close_wormhole")


@rpc("call_local", "reliable")
func sync_close_wormhole() -> void:
	current_state = GateState.INACTIVE
	locked_chevrons_count = 0
	if event_horizon_mesh != null:
		event_horizon_mesh.visible = false
	if gate_light != null:
		gate_light.light_energy = 0.0

	# Reset chevron materials
	if chevron_container != null:
		for child in chevron_container.get_children():
			var chev := child as GeometryInstance3D
			if chev != null:
				chev.material_override = null

	wormhole_closed.emit()
	print("Stargate: Wormhole collapsed. Gate disengaged.")


func _play_sfx(path: String, max_dist: float) -> void:
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 15.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
