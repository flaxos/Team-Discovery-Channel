class_name GeneralsDefenseTerminal
extends Node3D
## SGC Level 27 General's Office Emergency Defense Override Terminal.
## Operatives interact with [E] to engage facility lockdown protocols,
## deploy automated heavy sentries into the Gate Room, and trigger emergency strobes.

signal defense_grid_activated(player: PlayerController3D)

const TURRET_SCENE_PATH: String = "res://scenes/props/DeployableTurret.tscn"

@export var cooldown_duration_s: float = 15.0
@export var sentry_spawn_pos: Vector3 = Vector3(0.0, 0.0, 5.0)

var current_cooldown: float = 0.0
var terminal_light: OmniLight3D = null
var active_sentry: Node3D = null


func _ready() -> void:
	add_to_group("interactable")
	_setup_visual_indicator()


func _setup_visual_indicator() -> void:
	terminal_light = OmniLight3D.new()
	terminal_light.name = "TerminalLight"
	terminal_light.position = Vector3(0, 0.6, 0)
	terminal_light.light_color = Color(1.0, 0.8, 0.2)  # Amber warning
	terminal_light.light_energy = 1.5
	terminal_light.omni_range = 3.0
	add_child(terminal_light)


func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)


func interact(player: PlayerController3D) -> void:
	if player == null:
		return

	if current_cooldown > 0.0:
		print("GeneralsDefenseTerminal: Cooldown active (%.1f s remaining)." % current_cooldown)
		return

	current_cooldown = cooldown_duration_s
	_activate_defense_protocol(player)


func _activate_defense_protocol(player: PlayerController3D) -> void:
	var gateroom := get_tree().root.find_child("GateRoom", true, false) as GateRoom

	# 1. Deploy automated defense sentry at Gate Room choke point
	var turret_scene := load(TURRET_SCENE_PATH) as PackedScene
	if turret_scene != null and gateroom != null:
		# If an old sentry exists, remove it
		if active_sentry != null and is_instance_valid(active_sentry):
			active_sentry.queue_free()

		var sentry := turret_scene.instantiate() as DeployableTurret
		sentry.name = "GeneralsAutomatedSentry"
		sentry.position = sentry_spawn_pos
		sentry.rotation.y = PI  # Face towards Stargate (-Z)
		sentry.is_automated_sentry = true
		gateroom.add_child(sentry)
		active_sentry = sentry

	# 2. Engage facility emergency strobes
	if gateroom != null and gateroom.has_method("set_emergency_lights"):
		gateroom.set_emergency_lights(true)

	# 3. Seal Gate Room sliding blast doors to protect Level 28 corridor
	if gateroom != null and gateroom.has_method("toggle_blast_doors"):
		if not gateroom.is_blast_doors_closed:
			gateroom.toggle_blast_doors()

	# 4. Visual indicator pulse
	if terminal_light != null:
		terminal_light.light_color = Color(1.0, 0.1, 0.1)  # Flashing Red
		terminal_light.light_energy = 4.0
		var tween := create_tween()
		tween.tween_property(terminal_light, "light_energy", 1.5, 0.6)

	print("GeneralsDefenseTerminal: EMERGENCY DEFENSE PROTOCOL ACTIVE! Deployed sentry at %s by Operative %d." % [
		str(sentry_spawn_pos),
		player.peer_id
	])
	defense_grid_activated.emit(player)
