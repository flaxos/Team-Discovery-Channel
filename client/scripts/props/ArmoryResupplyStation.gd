class_name ArmoryResupplyStation
extends Node3D
const Interaction = preload("res://scripts/net/ServerInteraction.gd")
## Interactive SGC Munitions & Weapon Station on Sublevel 28.
## Operatives interact with [E] to replenish ammunition, Claymores, and C4,
## or swap weapon loadouts at the armory weapon racks.

signal resupplied(player: PlayerController3D)
signal weapon_swapped(player: PlayerController3D, new_weapon_id: String)

enum StationType { AMMO_CRATE, WEAPON_RACK }

@export var station_type: StationType = StationType.AMMO_CRATE
@export var rack_weapons: Array[String] = ["p90", "m249", "mp5", "zat"]
@export var station_name: String = "Armory Munitions Crate"
@export var cooldown_time: float = 0.0
## AP-1c: an ammo crate drawn as a box is dressed with imported plastic crates. Cosmetic only;
## the box keeps its collision and interaction, and stays visible if the model fails to load.
@export var imported_crate_visual: bool = true

var current_cooldown: float = 0.0
var rack_index: int = 0
var status_light: OmniLight3D = null
var crate_visual: CrateStackVisual = null
var occlusion_visual: GeometryInstance3D = null

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	add_to_group("interactable")
	_setup_visual_indicator()
	# Only the SGC's CSG ammo boxes are dressed; CO-1's offworld station scene draws its own mesh.
	var box := get_node(^".") as CSGBox3D
	if station_type == StationType.AMMO_CRATE and imported_crate_visual and box != null:
		crate_visual = CrateStackVisual.dress_box(box)
		if crate_visual != null:
			occlusion_visual = crate_visual.get_node(^"Crates") as MultiMeshInstance3D
	elif station_type == StationType.WEAPON_RACK and box != null:
		var rack := get_node_or_null(^"RackVisual") as MeshInstance3D
		var envelope := AABB(-box.size * 0.5, box.size).grow(0.001)
		if rack != null and rack.mesh != null and envelope.encloses(rack.transform * rack.get_aabb()):
			occlusion_visual = rack
			box.transparency = 1.0
			box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown -= delta
		if current_cooldown <= 0.0:
			current_cooldown = 0.0
			_update_prompt_ready()
			if status_light != null:
				status_light.light_color = (
					Color(0.2, 0.9, 0.3) if station_type == StationType.AMMO_CRATE else Color(0.3, 0.6, 1.0)
				)


func _format_prompt(text: String) -> String:
	if not is_inside_tree():
		return text
	var bindings := get_node_or_null("/root/KeybindingManager")
	return bindings.format_prompt(text) if bindings != null and bindings.has_method("format_prompt") else text


func _update_prompt_ready() -> void:
	if prompt_label != null:
		var label_text: String = (
			"[E] RESUPPLY MUNITIONS" if station_type == StationType.AMMO_CRATE else "[E] SWAP WEAPON"
		)
		prompt_label.text = _format_prompt(label_text)


func _setup_visual_indicator() -> void:
	if status_light != null:
		return
	if has_node("StationLight"):
		status_light = $StationLight as OmniLight3D
		return
	status_light = OmniLight3D.new()
	status_light.name = "StationLight"
	status_light.position = Vector3(0, 0.8, 0)
	status_light.omni_range = 3.5
	if station_type == StationType.AMMO_CRATE:
		status_light.light_color = Color(0.2, 0.9, 0.3)  # Munitions green
		status_light.light_energy = 1.2
	else:
		status_light.light_color = Color(0.3, 0.6, 1.0)  # Tech blue
		status_light.light_energy = 1.4
	add_child(status_light)


func interact(player: PlayerController3D) -> void:
	if current_cooldown > 0.0 or player == null:
		return
	if has_node("InteractArea") and global_position.distance_to(player.global_position) > 3.5:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_interact.rpc_id(1, get_path_to(player))
	else:
		request_interact(get_path_to(player))


@rpc("any_peer", "call_local", "reliable")
func request_interact(player_path: NodePath) -> void:
	var player: PlayerController3D = Interaction.resolve(self, player_path)
	if player != null:
		_apply_interaction(player)


func _apply_interaction(player: PlayerController3D) -> void:
	if current_cooldown > 0.0 or player == null:
		return

	if station_type == StationType.AMMO_CRATE:
		_perform_ammo_resupply(player)
	elif station_type == StationType.WEAPON_RACK:
		_perform_weapon_swap(player)


func _perform_ammo_resupply(player: PlayerController3D) -> void:
	if player.current_weapon != null:
		player.current_weapon.resupply()

	player.claymore_charges = player.MAX_CLAYMORE_CHARGES
	player.c4_charges_remaining = player.MAX_C4_CHARGES
	player.deployable_shields_count = player.MAX_DEPLOYABLE_SHIELDS
	player.smoke_grenades_count = player.MAX_SMOKE_GRENADES

	_pulse_indicator(Color(0.1, 1.0, 0.4))
	_play_resupply_sfx()

	print("ArmoryResupplyStation: Operative %d resupplied ammo, Claymores (%d), C4 (%d), Shields (%d), and Smoke (%d)!" % [
		player.peer_id,
		player.claymore_charges,
		player.c4_charges_remaining,
		player.deployable_shields_count,
		player.smoke_grenades_count
	])
	sync_feedback(cooldown_time)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		SGCNetworkManager.mission_rpc(self, &"sync_feedback", [cooldown_time])
		SGCNetworkManager.mission_rpc(
			self, &"sync_inventory", [get_path_to(player), player.primary_weapon_id, false], player.health_component
		)
	if player.has_method("_broadcast_weapon_state"):
		player.call("_broadcast_weapon_state")
	resupplied.emit(player)


func _perform_weapon_swap(player: PlayerController3D) -> void:
	if rack_weapons.is_empty():
		return

	rack_index = (rack_index + 1) % rack_weapons.size()
	var new_weapon_id := rack_weapons[rack_index]

	player.active_slot = 1
	player.primary_weapon_id = new_weapon_id
	player._equip_weapon_by_id(new_weapon_id)

	_pulse_indicator(Color(0.3, 0.8, 1.0))
	_play_resupply_sfx()

	print("ArmoryResupplyStation: Operative %d equipped %s from weapon rack!" % [
		player.peer_id,
		new_weapon_id
	])
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		SGCNetworkManager.mission_rpc(
			self, &"sync_inventory", [get_path_to(player), new_weapon_id, true], player.health_component
		)
	if player.has_method("_broadcast_weapon_state"):
		player.call("_broadcast_weapon_state")
	weapon_swapped.emit(player, new_weapon_id)


func _pulse_indicator(flash_color: Color) -> void:
	if status_light == null:
		return
	var orig_energy := status_light.light_energy
	status_light.light_energy = 3.5
	var tween := create_tween()
	tween.tween_property(status_light, "light_energy", orig_energy, 0.6)


func _play_resupply_sfx() -> void:
	if ResourceLoader.exists("res://audio/sfx_gdo_beep.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_gdo_beep.wav")
		audio.max_distance = 25.0
		audio.unit_size = 5.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


@rpc("authority", "call_local", "reliable")
func sync_feedback(duration: float = 0.0) -> void:
	if duration > 0.0:
		current_cooldown = duration
		if prompt_label != null:
			prompt_label.text = "RESUPPLIED - COOLDOWN (%.0fs)" % duration
		if status_light != null:
			status_light.light_color = Color(0.9, 0.6, 0.1)
	else:
		current_cooldown = 0.0
		_update_prompt_ready()
		if status_light != null:
			status_light.light_color = (
				Color(0.2, 0.9, 0.3) if station_type == StationType.AMMO_CRATE else Color(0.3, 0.6, 1.0)
			)


@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_snapshot.rpc_id(multiplayer.get_remote_sender_id(), current_cooldown, rack_index)


@rpc("authority", "call_local", "reliable")
func sync_snapshot(cooldown_remaining: float, remote_rack_index: int) -> void:
	rack_index = remote_rack_index
	if cooldown_remaining > current_cooldown:
		current_cooldown = cooldown_remaining
		if prompt_label != null:
			prompt_label.text = "RESUPPLIED - COOLDOWN (%.0fs)" % current_cooldown
		if status_light != null:
			status_light.light_color = Color(0.9, 0.6, 0.1)
	elif current_cooldown <= 0.0 and cooldown_remaining <= 0.0:
		current_cooldown = 0.0
		_update_prompt_ready()
		if status_light != null:
			status_light.light_color = (
				Color(0.2, 0.9, 0.3) if station_type == StationType.AMMO_CRATE else Color(0.3, 0.6, 1.0)
			)


func reset_station() -> void:
	current_cooldown = 0.0
	rack_index = 0
	_update_prompt_ready()
	if status_light != null:
		status_light.light_color = (
			Color(0.2, 0.9, 0.3) if station_type == StationType.AMMO_CRATE else Color(0.3, 0.6, 1.0)
		)


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		if current_cooldown <= 0.0:
			_update_prompt_ready()


func _on_body_exited(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		if prompt_label != null and current_cooldown <= 0.0:
			prompt_label.text = (
				"MUNITIONS RESUPPLY" if station_type == StationType.AMMO_CRATE else "WEAPON RACK"
			)


@rpc("authority", "call_remote", "reliable")
func sync_inventory(player_path: NodePath, primary_id: String, swapped: bool) -> void:
	var player := get_node_or_null(player_path) as PlayerController3D
	if player == null:
		return
	player.primary_weapon_id = primary_id
	if swapped:
		player.active_slot = 1
		player._equip_weapon_by_id(primary_id)
	if not swapped:
		if player.current_weapon != null:
			player.current_weapon.reserve_ammo = player.current_weapon.reserve_capacity
			player.current_weapon.ammo_changed.emit(
				player.current_weapon.current_ammo, player.current_weapon.reserve_ammo
			)
		player.claymore_charges = player.MAX_CLAYMORE_CHARGES
		player.c4_charges_remaining = player.MAX_C4_CHARGES
		player.deployable_shields_count = player.MAX_DEPLOYABLE_SHIELDS
		player.smoke_grenades_count = player.MAX_SMOKE_GRENADES
