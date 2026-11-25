class_name TransportRings
extends Node3D
## Goa'uld Transport Rings with 2-way tactical physics.
## Handles ceiling telegraph, crush hitbox, beaming column flash, and reinforcement drops.

signal telegraph_started()
signal rings_slammed(ground_position: Vector3)
signal beam_discharged()
signal rings_retracted()
signal reinforcement_spawned(enemy: JaffaAI)

const Interaction = preload("res://scripts/net/ServerInteraction.gd")
const PlayerTransportVfx = preload("res://scripts/props/RingTransportVfx.gd")
const BOARDING_RADIUS := 1.72
const PAD_RADIUS := 2.2
const DESCENT_SECONDS := 0.22
const RETRACT_SECONDS := 0.35
const PLAYER_RETRACT_SECONDS := 0.70

enum RingState { INACTIVE, TELEGRAPH, SLAM, BEAM, RETRACT }

@export var ring_count: int = 5
@export var telegraph_duration_s: float = 2.0
@export var beam_duration_s: float = 1.0
@export var crush_damage: float = 80.0
@export var spawn_enemies_on_beam: bool = true
@export var paired_rings_path: NodePath = ""
@export var reinforcement_scene: PackedScene = null
@export var reinforcements_per_beam: int = 1
var paired_rings: TransportRings = null

var current_state: RingState = RingState.INACTIVE
var telegraph_timer: float = 0.0
var _player_transport := false
var _prompt: Label3D
var _vfx: Node3D
var _sending := false
var _phase_started_ms := 0
var _phase_duration := 1.0

@onready var rings_container: Node3D = $RingsStack if has_node("RingsStack") else null
@onready var beam_column: MeshInstance3D = $BeamColumn if has_node("BeamColumn") else null
@onready var telegraph_light: OmniLight3D = $TelegraphLight if has_node("TelegraphLight") else null
@onready var crush_area: Area3D = $CrushArea if has_node("CrushArea") else null


func _ready() -> void:
	_resolve_paired_rings()
	call_deferred("_resolve_paired_rings")

	if beam_column != null:
		beam_column.visible = false
	if crush_area != null:
		crush_area.monitoring = false
		crush_area.body_entered.connect(_on_crush_body_entered)


func _resolve_paired_rings() -> void:
	if paired_rings == null and not paired_rings_path.is_empty() and has_node(paired_rings_path):
		paired_rings = get_node(paired_rings_path) as TransportRings


## ModularMission enables only the reciprocal pair resolved by level assembly.
func enable_player_transport() -> void:
	if _player_transport or paired_rings == null or paired_rings == self or paired_rings.paired_rings != self:
		return
	_player_transport = true
	add_to_group(&"interactable")
	if DisplayServer.get_name() != "headless" and rings_container != null and telegraph_light != null and has_node("FloorPlate"):
		_vfx = PlayerTransportVfx.new()
		add_child(_vfx)
		_vfx.configure(rings_container, $FloorPlate, telegraph_light)
	_prompt = Label3D.new()
	_prompt.position.y = 2.5
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 30
	_prompt.visibility_range_end = 12.0
	add_child(_prompt)
	_update_prompt()
	var net: Node = get_node_or_null("/root/NetworkManager")
	if multiplayer.is_server() and net != null and net.is_in_active_session() and multiplayer == net.multiplayer:
		net.mission_peer_ready.connect(_send_transport_snapshot)


func interact(player: PlayerController3D) -> void:
	if not _player_transport or player == null or not _aboard(player, BOARDING_RADIUS):
		return
	if multiplayer.is_server():
		request_transport(get_path_to(player))
	else:
		request_transport.rpc_id(1, get_path_to(player))


@rpc("any_peer", "call_remote", "reliable")
func request_transport(player_path: NodePath) -> void:
	if not multiplayer.is_server() or not _has_transport_pair():
		return
	var target := paired_rings
	if current_state != RingState.INACTIVE or target.current_state != RingState.INACTIVE:
		return
	var player := Interaction.resolve(self, player_path, PAD_RADIUS)
	if player == null or not _can_board(player) or target._pad_occupied([]):
		return
	_run_transport(target)


func _has_transport_pair() -> bool:
	return (
		_player_transport and is_inside_tree() and is_instance_valid(paired_rings)
		and paired_rings.is_inside_tree() and paired_rings._player_transport
		and paired_rings.paired_rings == self
	)


func _aboard(actor: Node3D, radius: float) -> bool:
	var pos := to_local(actor.global_position)
	return absf(pos.y) <= 0.45 and Vector2(pos.x, pos.z).length_squared() <= radius * radius


func _can_board(player: PlayerController3D) -> bool:
	var health := player.health_component
	return (
		player.is_inside_tree() and not player.is_queued_for_deletion()
		and player.get_parent() == MissionWorld.find(self, "Players")
		and health != null and not (health.is_dead or health.is_downed or health.is_stunned or health.frozen)
		and not is_instance_valid(player.mounted_turret) and not player.is_dragging_body
		and _aboard(player, BOARDING_RADIUS)
	)


func _pad_occupied(arrived: Array[Node]) -> bool:
	for container_name: String in ["Players", "Enemies"]:
		var container := MissionWorld.find(self, container_name)
		if container == null:
			continue
		for body: Node in container.get_children():
			if body is Node3D and body not in arrived and _aboard(body, PAD_RADIUS):
				var health := body.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and not health.is_dead:
					return true
	return false


func _run_transport(target: TransportRings) -> void:
	_set_pair_state(target, RingState.TELEGRAPH)
	await get_tree().create_timer(telegraph_duration_s).timeout
	if not _has_transport_pair():
		return
	_set_pair_state(target, RingState.SLAM)
	var players := MissionWorld.find(self, "Players")
	if not target._pad_occupied([]):
		for player: Node in players.get_children():
			if player is PlayerController3D and _can_board(player):
				_show_rider_scan(player, true)
	await get_tree().create_timer(DESCENT_SECONDS).timeout
	if not _has_transport_pair():
		return
	_set_pair_state(target, RingState.BEAM)
	var started := Time.get_ticks_msec()
	var arrived: Array[Node] = []
	var net: Node = get_node_or_null("/root/NetworkManager")
	for player: Node in players.get_children():
		if not _has_transport_pair() or target._pad_occupied(arrived):
			break
		if not is_instance_valid(player) or not player is PlayerController3D or not _can_board(player):
			continue
		var destination := _arrival_for.bind(player, target, arrived)
		if net != null and net.is_in_active_session() and multiplayer == net.multiplayer:
			if await net.relocate_player(player, destination):
				arrived.append(player)
				_show_rider_scan(player, false)
		else:
			var point: Vector3 = destination.call()
			if point.is_finite():
				player.apply_transport_arrival(point)
				arrived.append(player)
				_show_rider_scan(player, false)
	if not _has_transport_pair():
		return
	var remaining := beam_duration_s - (Time.get_ticks_msec() - started) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
	if not _has_transport_pair():
		return
	_set_pair_state(target, RingState.RETRACT)
	await get_tree().create_timer(PLAYER_RETRACT_SECONDS).timeout
	if _has_transport_pair():
		_set_pair_state(target, RingState.INACTIVE)


func _arrival_for(player: PlayerController3D, target: TransportRings, arrived: Array[Node]) -> Vector3:
	if not _has_transport_pair() or not is_instance_valid(player) or not _can_board(player) or target._pad_occupied(arrived):
		return Vector3.INF
	var offset := to_local(player.global_position)
	offset.y = 0.08
	return target.to_global(offset)


func _set_pair_state(target: TransportRings, state: RingState) -> void:
	var duration: float = [1.0, telegraph_duration_s, DESCENT_SECONDS, beam_duration_s, PLAYER_RETRACT_SECONDS][state]
	show_transport_state(state, true, duration)
	target.show_transport_state(state, false, duration)
	SGCNetworkManager.mission_rpc(self, &"show_transport_state", [state, true, duration])
	SGCNetworkManager.mission_rpc(target, &"show_transport_state", [state, false, duration])


func _show_rider_scan(player: PlayerController3D, sending: bool) -> void:
	player.show_ring_transport_scan(player.global_position, sending)
	SGCNetworkManager.mission_rpc(
		self, &"present_rider_scan", [get_path_to(player), player.global_position, sending], player.health_component
	)


@rpc("authority", "call_remote", "reliable")
func present_rider_scan(player_path: NodePath, point: Vector3, sending: bool) -> void:
	var player := get_node_or_null(player_path) as PlayerController3D
	if player != null:
		player.show_ring_transport_scan(point, sending)


func _send_transport_snapshot(peer_id: int) -> void:
	if current_state != RingState.INACTIVE:
		show_transport_state.rpc_id(
			peer_id, current_state, _sending, _phase_duration,
			(Time.get_ticks_msec() - _phase_started_ms) * 0.001
		)


@rpc("authority", "call_remote", "reliable")
func show_transport_state(state: RingState, sending: bool, duration: float, elapsed: float = 0.0) -> void:
	if not _player_transport or state == current_state:
		return
	current_state = state
	_sending = sending
	_phase_duration = duration
	_phase_started_ms = Time.get_ticks_msec() - int(elapsed * 1000.0)
	if telegraph_light != null:
		telegraph_light.visible = state != RingState.INACTIVE
	if _vfx != null:
		_vfx.show_phase(StringName(RingState.keys()[state]), sending, elapsed, maxf(duration, 0.01))
	match state:
		RingState.TELEGRAPH:
			telegraph_started.emit()
			if elapsed < 0.20:
				_play_sfx("res://audio/sfx_rings.wav", 24.0)
		RingState.SLAM:
			rings_slammed.emit(global_position)
		RingState.BEAM:
			beam_discharged.emit()
			if elapsed < 0.20:
				_play_sfx("res://audio/sfx_ring_transfer.wav", 24.0, 1.0 if sending else 0.86)
		RingState.RETRACT:
			rings_retracted.emit()
			if elapsed < 0.20:
				_play_sfx("res://audio/sfx_ring_retract.wav", 24.0)
	_update_prompt()


func _update_prompt() -> void:
	_prompt.visible = current_state == RingState.INACTIVE
	var bindings := get_node_or_null("/root/KeybindingManager")
	var caption := "[E] TRANSPORT RINGS"
	_prompt.text = bindings.format_prompt(caption) if bindings != null else caption


## Initiates the transport ring drop sequence
func trigger_ring_drop() -> void:
	if _player_transport or not multiplayer.is_server():
		return
	rpc("sync_trigger_ring_drop")


@rpc("call_local", "reliable")
func sync_trigger_ring_drop() -> void:
	if _player_transport:
		return
	current_state = RingState.TELEGRAPH
	telegraph_started.emit()
	print("Transport Rings: Ceiling hatch opening! Rings descending in 2s...")
	_play_sfx("res://audio/sfx_rings.wav", 60.0)

	if telegraph_light != null:
		telegraph_light.visible = true
		telegraph_light.light_color = Color(1.0, 0.75, 0.2)
		telegraph_light.light_energy = 4.0

	# Telegraph timer
	var timer := get_tree().create_timer(telegraph_duration_s)
	timer.timeout.connect(_slam_rings_down)


func _slam_rings_down() -> void:
	current_state = RingState.SLAM
	rings_slammed.emit(global_position)
	print("Transport Rings: SLAM! Concentric rings hit floor plate.")

	# Screen shake on kinetic floor slam
	var players_node := MissionWorld.find(self, "Players")
	if players_node != null:
		for p in players_node.get_children():
			if p is PlayerController3D:
				p.add_screen_shake(0.55)

	# Enable crush hitbox
	if crush_area != null:
		crush_area.monitoring = true

	# Animate rings stack descending rapidly
	if rings_container != null:
		rings_container.position.y = 8.0
		rings_container.visible = true
		var tween := create_tween()
		tween.tween_property(rings_container, "position:y", 0.0, 0.22)
		tween.tween_callback(_discharge_beam)
	else:
		_discharge_beam()


func _discharge_beam() -> void:
	current_state = RingState.BEAM
	beam_discharged.emit()
	print("Transport Rings: Beaming matter stream activated!")

	if crush_area != null:
		crush_area.monitoring = false

	if beam_column != null:
		beam_column.visible = true
		beam_column.scale = Vector3(1, 1, 1)

	if multiplayer.is_server():
		_discharge_tactical_payload()
	var timer := get_tree().create_timer(beam_duration_s)
	timer.timeout.connect(_retract_rings)


func _discharge_tactical_payload() -> void:
	var intercepted_explosive: bool = false

	# 1. Check for explosives inside the rings (Tactical Interception)
	var satchels := MissionWorld.of(self).find_children("", "C4Satchel", true, false)
	for s in satchels:
		var satchel := s as Node3D
		if satchel != null and global_position.distance_to(satchel.global_position) <= 2.2:
			intercepted_explosive = true
			satchel.queue_free()
			print("Transport Rings: Explosive beamed up to mothership! Reserve wave neutralized!")
			if ResourceLoader.exists("res://audio/sfx_explosion.wav"):
				_play_sfx("res://audio/sfx_explosion.wav", 80.0)

	# 2. Check for operatives inside the rings (2-Way Teleportation)
	if paired_rings == null:
		_resolve_paired_rings()
	if paired_rings != null and is_instance_valid(paired_rings):
		var players := MissionWorld.of(self).find_children("", "PlayerController3D", true, false)
		for p in players:
			var player := p as PlayerController3D
			if player != null and global_position.distance_to(player.global_position) <= 2.2:
				var dest: Vector3 = paired_rings.global_position + Vector3(0, 0.1, 0)
				player.apply_transport_arrival(dest)
				print("Transport Rings: Operative %s beamed to paired rings at %s!" % [player.name, str(dest)])

	# 3. If server and not intercepted, spawn reinforcements
	if spawn_enemies_on_beam and not intercepted_explosive:
		_spawn_ring_reinforcements()


func _spawn_ring_reinforcements() -> void:
	var jaffa_scene: PackedScene = reinforcement_scene
	if jaffa_scene == null:
		jaffa_scene = load("res://scenes/entities/JaffaGuard.tscn") as PackedScene
	var enemies_container := MissionWorld.find(self, "Enemies")
	if jaffa_scene != null and enemies_container != null:
		for i in range(reinforcements_per_beam):
			var jaffa := jaffa_scene.instantiate() as JaffaAI
			jaffa.name = "RingJaffa_%d" % randi()
			var offset := Vector3(randf_range(-0.7, 0.7), 0.1, randf_range(-0.7, 0.7)) if reinforcements_per_beam > 1 else Vector3(0, 0.1, 0)
			jaffa.position = MissionWorld.local(enemies_container, global_position + offset)
			enemies_container.add_child(jaffa, true)
			reinforcement_spawned.emit(jaffa)
			print("Transport Rings: Beamed down reinforcement %s!" % ("Shock Guard" if jaffa.is_shock_guard else "Jaffa Guard"))


func _retract_rings() -> void:
	current_state = RingState.RETRACT
	rings_retracted.emit()
	print("Transport Rings: Matter transfer complete. Rings ascending.")

	if beam_column != null:
		beam_column.visible = false

	if rings_container != null:
		var tween := create_tween()
		tween.tween_property(rings_container, "position:y", 8.0, RETRACT_SECONDS)
		tween.tween_callback(func() -> void:
			current_state = RingState.INACTIVE
			rings_container.visible = false
			if telegraph_light != null:
				telegraph_light.visible = false
		)
	else:
		current_state = RingState.INACTIVE
		if telegraph_light != null:
			telegraph_light.visible = false


func _on_crush_body_entered(body: Node) -> void:
	if not multiplayer.is_server() or current_state != RingState.SLAM:
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and not health.is_dead:
		print("Transport Rings: Entity %s crushed by slamming rings!" % body.name)
		health.take_damage(crush_damage, self, "ring_crush")


func _play_sfx(path: String, max_dist: float, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.bus = &"SFX"
		audio.max_distance = max_dist
		audio.pitch_scale = pitch
		audio.unit_size = 12.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
