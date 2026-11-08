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
enum GateDirection { NONE, INBOUND, OUTBOUND }

var direction: GateDirection = GateDirection.NONE
var extraction_authorized: bool = false
var activation_id: int = 0
var kawoosh_tween: Tween = null

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
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_gate_snapshot.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func request_gate_snapshot() -> void:
	if multiplayer.is_server():
		sync_gate_snapshot.rpc_id(multiplayer.get_remote_sender_id(), current_state, direction, locked_chevrons_count, extraction_authorized)


@rpc("authority", "call_remote", "reliable")
func sync_gate_snapshot(state: int, connection: int, chevrons: int, authorized: bool) -> void:
	activation_id += 1
	current_state = state as GateState
	direction = connection as GateDirection
	locked_chevrons_count = chevrons
	extraction_authorized = authorized
	if event_horizon_mesh != null:
		event_horizon_mesh.visible = current_state in [GateState.KAWOOSH, GateState.ACTIVE]
	if gate_light != null:
		gate_light.light_energy = 2.5 if current_state == GateState.ACTIVE else 0.0


func _on_extraction_entered(body: Node) -> void:
	if multiplayer.is_server() and current_state == GateState.ACTIVE and direction == GateDirection.OUTBOUND and extraction_authorized and body is PlayerController3D:
		print("Stargate: Operative %s stepped into active event horizon! Extraction sequence initiated!" % body.name)
		player_extracted.emit(body)


func reserve_connection(incoming: bool) -> bool:
	if not multiplayer.is_server() or current_state != GateState.INACTIVE or direction != GateDirection.NONE:
		return false
	var connection: int = GateDirection.INBOUND if incoming else GateDirection.OUTBOUND
	if multiplayer.has_multiplayer_peer():
		sync_reserve_connection.rpc(connection)
	else:
		sync_reserve_connection(connection)
	return true


@rpc("authority", "call_local", "reliable")
func sync_reserve_connection(connection: int) -> void:
	activation_id += 1
	direction = connection as GateDirection
	extraction_authorized = false
	locked_chevrons_count = 0
	current_state = GateState.DIALING


func authorize_extraction() -> void:
	if not multiplayer.is_server() or direction != GateDirection.OUTBOUND:
		return
	if multiplayer.has_multiplayer_peer():
		sync_authorize_extraction.rpc()
	else:
		sync_authorize_extraction()


@rpc("authority", "call_local", "reliable")
func sync_authorize_extraction() -> void:
	extraction_authorized = direction == GateDirection.OUTBOUND


## Locks an individual chevron in sequence (1 through 7)
func lock_chevron(chevron_idx: int) -> void:
	if not multiplayer.is_server() or chevron_idx < 1 or chevron_idx > max_chevrons:
		return
	if direction == GateDirection.NONE and not reserve_connection(false):
		return
	if current_state != GateState.DIALING:
		return
	if multiplayer.has_multiplayer_peer():
		sync_lock_chevron.rpc(chevron_idx)
	else:
		sync_lock_chevron(chevron_idx)


## Resets all chevrons on dialing sequence failure
func reset_chevrons() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		sync_reset_chevrons.rpc()
	else:
		sync_reset_chevrons()


@rpc("authority", "call_local", "reliable")
func sync_reset_chevrons() -> void:
	locked_chevrons_count = 0
	_reset_chevron_visuals()


@rpc("authority", "call_local", "reliable")
func sync_lock_chevron(chevron_idx: int) -> void:
	if current_state != GateState.DIALING or chevron_idx != locked_chevrons_count + 1:
		return
	locked_chevrons_count = chevron_idx
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
	if multiplayer.has_multiplayer_peer():
		sync_trigger_kawoosh.rpc()
	else:
		sync_trigger_kawoosh()


@rpc("authority", "call_local", "reliable")
func sync_trigger_kawoosh() -> void:
	current_state = GateState.KAWOOSH
	kawoosh_erupted.emit()
	print("Stargate: KAWOOSH! Event horizon erupting forward!")
	_play_sfx("res://audio/sfx_kawoosh.wav", 100.0)

	# Cinematic camera shake for all active operatives
	var players_node := get_tree().root.find_child("Players", true, false)
	if players_node != null:
		for p in players_node.get_children():
			if p is PlayerController3D:
				p.add_screen_shake(0.85)

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
	kawoosh_tween = create_tween()
	if kawoosh_mesh != null:
		kawoosh_tween.tween_property(kawoosh_mesh, "scale", Vector3.ONE, kawoosh_duration_s * 0.45)
		kawoosh_tween.tween_property(kawoosh_mesh, "scale", Vector3.ONE * 0.01, kawoosh_duration_s * 0.55)
	else:
		kawoosh_tween.tween_interval(kawoosh_duration_s)
	kawoosh_tween.tween_callback(_finish_kawoosh.bind(activation_id))


func _finish_kawoosh(token: int) -> void:
	if token != activation_id or current_state != GateState.KAWOOSH:
		return
	if kawoosh_mesh != null:
		kawoosh_mesh.visible = false
	if kawoosh_area != null:
		kawoosh_area.set_deferred("monitoring", false)
	_stabilize_wormhole()


func _stabilize_wormhole() -> void:
	if current_state != GateState.KAWOOSH:
		return
	if event_horizon_mesh != null:
		event_horizon_mesh.visible = true
	current_state = GateState.ACTIVE
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_stabilized.rpc()
	wormhole_opened.emit()
	print("Stargate: Wormhole stabilized! Extraction aperture open.")
	if gate_light != null:
		gate_light.light_energy = 2.5


@rpc("authority", "call_remote", "reliable")
func sync_stabilized() -> void:
	if current_state not in [GateState.DIALING, GateState.KAWOOSH]:
		return
	current_state = GateState.ACTIVE
	if event_horizon_mesh != null:
		event_horizon_mesh.visible = true
	if kawoosh_mesh != null:
		kawoosh_mesh.hide()
	if kawoosh_area != null:
		kawoosh_area.set_deferred("monitoring", false)
	wormhole_opened.emit()


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
	if multiplayer.has_multiplayer_peer():
		sync_close_wormhole.rpc()
	else:
		sync_close_wormhole()


@rpc("authority", "call_local", "reliable")
func sync_close_wormhole() -> void:
	activation_id += 1
	if kawoosh_tween != null and kawoosh_tween.is_valid():
		kawoosh_tween.kill()
	direction = GateDirection.NONE
	extraction_authorized = false
	if kawoosh_mesh != null:
		kawoosh_mesh.visible = false
	if kawoosh_area != null:
		kawoosh_area.set_deferred("monitoring", false)
	current_state = GateState.INACTIVE
	locked_chevrons_count = 0
	if event_horizon_mesh != null:
		event_horizon_mesh.visible = false
	if gate_light != null:
		gate_light.light_energy = 0.0

	_reset_chevron_visuals()
	wormhole_closed.emit()
	print("Stargate: Wormhole collapsed. Gate disengaged.")


func _reset_chevron_visuals() -> void:
	if chevron_container != null:
		for child: Node in chevron_container.get_children():
			var chev := child as GeometryInstance3D
			if chev != null:
				chev.material_override = null


func _play_sfx(path: String, max_dist: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 15.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
