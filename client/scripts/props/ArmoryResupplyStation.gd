class_name ArmoryResupplyStation
extends Node3D
## Interactive SGC Munitions & Weapon Station on Sublevel 28.
## Operatives interact with [E] to replenish ammunition, Claymores, and C4,
## or swap weapon loadouts at the armory weapon racks.

signal resupplied(player: PlayerController3D)
signal weapon_swapped(player: PlayerController3D, new_weapon_id: String)

enum StationType { AMMO_CRATE, WEAPON_RACK }

@export var station_type: StationType = StationType.AMMO_CRATE
@export var rack_weapons: Array[String] = ["p90", "m249", "mp5", "zat"]
@export var station_name: String = "Armory Munitions Crate"

var rack_index: int = 0
var status_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("interactable")
	_setup_visual_indicator()


func _setup_visual_indicator() -> void:
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
	if player == null:
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
	resupplied.emit(player)


func _perform_weapon_swap(player: PlayerController3D) -> void:
	if rack_weapons.is_empty():
		return

	rack_index = (rack_index + 1) % rack_weapons.size()
	var new_weapon_id := rack_weapons[rack_index]

	player.primary_weapon_id = new_weapon_id
	player._equip_weapon_by_id(new_weapon_id)

	_pulse_indicator(Color(0.3, 0.8, 1.0))
	_play_resupply_sfx()

	print("ArmoryResupplyStation: Operative %d equipped %s from weapon rack!" % [
		player.peer_id,
		new_weapon_id
	])
	weapon_swapped.emit(player, new_weapon_id)


func _pulse_indicator(flash_color: Color) -> void:
	if status_light == null:
		return
	var orig_energy := status_light.light_energy
	var orig_color := status_light.light_color
	status_light.light_color = flash_color
	status_light.light_energy = 3.5

	var tween := create_tween()
	tween.tween_property(status_light, "light_energy", orig_energy, 0.4)
	tween.parallel().tween_property(status_light, "light_color", orig_color, 0.4)


func _play_resupply_sfx() -> void:
	if ResourceLoader.exists("res://audio/sfx_resupply.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_resupply.wav")
		audio.max_distance = 25.0
		audio.unit_size = 5.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
