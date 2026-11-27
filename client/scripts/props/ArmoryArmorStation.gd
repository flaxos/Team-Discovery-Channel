class_name ArmoryArmorStation
extends Node3D
const Interaction = preload("res://scripts/net/ServerInteraction.gd")
## SGC Level 28 Armory Tactical Body Armor & Munitions Station.
## Allows operatives to re-armor ballistic plates (restoring Health to 100%)
## and resupply finite combat ammunition reserves.

signal rearmored(player: PlayerController3D)

const SHELF_MODEL := "res://assets/props/worn_metal_rack.glb"
const SHELF_SCALE := 0.83

@export var cooldown_time: float = 3.0
@export var sgc_shelf_dressing := false
var current_cooldown: float = 0.0

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null
@onready var station_light: OmniLight3D = $StationLight if has_node("StationLight") else null


func _ready() -> void:
	add_to_group("interactable")
	if sgc_shelf_dressing:
		_fit_shelf()
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


func _fit_shelf() -> void:
	var original := $RackMesh as MeshInstance3D
	var shelf := RuntimeGLB.load_scene(SHELF_MODEL)
	if shelf == null:
		return
	var imported := shelf.get_node_or_null(^"worn_metal_rack") as MeshInstance3D
	if imported == null or imported.mesh == null or imported.mesh.get_surface_count() != 1:
		shelf.free()
		return
	var material := imported.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		shelf.free()
		return
	var bounds := imported.transform * imported.get_aabb()
	var floor_center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * SHELF_SCALE), -floor_center * SHELF_SCALE)
	if not (original.transform * original.get_aabb()).grow(0.001).encloses(fit * bounds):
		shelf.free()
		return
	# The steel shares the room's matte finish under the existing station light.
	material.metallic = 0.25
	RuntimeGLB.add_mipmaps(material)
	shelf.transform = fit
	shelf.name = "ImportedShelf"
	add_child(shelf)
	original.hide()
	var plates := $PlatesMesh as MeshInstance3D
	plates.scale = Vector3(0.54, 0.12, 0.67)
	plates.position = Vector3(0, 0.815, 0.04)
	if station_light != null:
		station_light.light_energy = 0.63


func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown -= delta
		if current_cooldown <= 0.0:
			current_cooldown = 0.0
			if prompt_label != null:
				prompt_label.text = _format_prompt("[E] RE-ARMOR TACTICAL PLATES")
			if station_light != null:
				station_light.light_color = Color(0.2, 0.9, 0.4, 1.0)


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

	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.heal(health.max_health)

	# Resupply reserve ammo for finite ballistic weapons
	if player.current_weapon != null and not player.current_weapon.uses_heat:
		if player.current_weapon is WeaponBase:
			var wb := player.current_weapon as WeaponBase
			# Restore to standard class reserve capacity
			if wb.reserve_ammo < 300:
				wb.reserve_ammo = mini(300, wb.reserve_ammo + 150)
				wb.ammo_changed.emit(wb.current_ammo, wb.reserve_ammo)

	if player.has_method("_broadcast_weapon_state"):
		player.call("_broadcast_weapon_state")
	sync_feedback()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		SGCNetworkManager.mission_rpc(self, &"sync_feedback", [])
	rearmored.emit(player)


@rpc("authority", "call_local", "reliable")
func sync_feedback() -> void:
	current_cooldown = cooldown_time
	if prompt_label != null:
		prompt_label.text = "ARMOR REPLACED - COOLDOWN (%.0fs)" % cooldown_time
	if station_light != null:
		station_light.light_color = Color(0.9, 0.6, 0.1, 1.0)

	_play_sfx("res://audio/sfx_gdo_beep.wav", 15.0)



@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_snapshot.rpc_id(multiplayer.get_remote_sender_id(), current_cooldown)


@rpc("authority", "call_local", "reliable")
func sync_snapshot(cooldown_remaining: float) -> void:
	if cooldown_remaining > current_cooldown:
		current_cooldown = cooldown_remaining
		if prompt_label != null:
			prompt_label.text = "ARMOR REPLACED - COOLDOWN (%.0fs)" % current_cooldown
		if station_light != null:
			station_light.light_color = Color(0.9, 0.6, 0.1, 1.0)
	elif current_cooldown <= 0.0 and cooldown_remaining <= 0.0:
		current_cooldown = 0.0
		if prompt_label != null:
			prompt_label.text = _format_prompt("[E] RE-ARMOR TACTICAL PLATES")
		if station_light != null:
			station_light.light_color = Color(0.2, 0.9, 0.4, 1.0)


func reset_station() -> void:
	current_cooldown = 0.0
	if prompt_label != null:
		prompt_label.text = _format_prompt("[E] RE-ARMOR TACTICAL PLATES")
	if station_light != null:
		station_light.light_color = Color(0.2, 0.9, 0.4, 1.0)


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		if prompt_label != null and current_cooldown <= 0.0:
			prompt_label.text = _format_prompt("[E] RE-ARMOR TACTICAL PLATES")


func _on_body_exited(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		if prompt_label != null and current_cooldown <= 0.0:
			prompt_label.text = "SGC TACTICAL ARMOR RACK"


func _play_sfx(path: String, max_dist: float) -> void:
	if ResourceLoader.exists(path):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load(path)
		audio.max_distance = max_dist
		audio.unit_size = 8.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _format_prompt(text: String) -> String:
	if not is_inside_tree():
		return text
	var bindings := get_node_or_null("/root/KeybindingManager")
	return bindings.format_prompt(text) if bindings != null and bindings.has_method("format_prompt") else text


func _bindings() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/KeybindingManager")
