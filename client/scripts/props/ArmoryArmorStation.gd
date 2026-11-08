class_name ArmoryArmorStation
extends Node3D
const Interaction = preload("res://scripts/net/ServerInteraction.gd")
## SGC Level 28 Armory Tactical Body Armor & Munitions Station.
## Allows operatives to re-armor ballistic plates (restoring Health to 100%)
## and resupply finite combat ammunition reserves.

signal rearmored(player: PlayerController3D)

@export var cooldown_time: float = 3.0
var current_cooldown: float = 0.0

@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null
@onready var prompt_label: Label3D = $PromptLabel if has_node("PromptLabel") else null
@onready var station_light: OmniLight3D = $StationLight if has_node("StationLight") else null


func _ready() -> void:
	add_to_group("interactable")
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown -= delta
		if current_cooldown <= 0.0:
			if prompt_label != null:
				prompt_label.text = _bindings().format_prompt("[E] RE-ARMOR TACTICAL PLATES")
			if station_light != null:
				station_light.light_color = Color(0.2, 0.9, 0.4, 1.0)


func interact(player: PlayerController3D) -> void:
	if player == null:
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
	if multiplayer.has_multiplayer_peer():
		sync_feedback.rpc()
	else:
		sync_feedback()
	rearmored.emit(player)


@rpc("authority", "call_local", "reliable")
func sync_feedback() -> void:
	current_cooldown = cooldown_time
	if prompt_label != null:
		prompt_label.text = "ARMOR REPLACED - COOLDOWN (%.0fs)" % cooldown_time
	if station_light != null:
		station_light.light_color = Color(0.9, 0.6, 0.1, 1.0)

	_play_sfx("res://audio/sfx_p90_reload.wav", 15.0)



func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player != null and player.is_local_authority:
		if prompt_label != null and current_cooldown <= 0.0:
			prompt_label.text = _bindings().format_prompt("[E] RE-ARMOR TACTICAL PLATES")


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


func _bindings() -> Node:
	return get_node("/root/KeybindingManager")
