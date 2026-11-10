class_name MissionInteractable
extends Node3D
## Makes an existing room attachment usable for one interact objective. Clients send
## identity only; the server validates sender, reach, health and objective order.
const Interaction = preload("res://scripts/net/ServerInteraction.gd")
const REACH := 3.5
var objectives: MissionObjectives
var objective: MissionObjective
var prompt: Label3D


func _ready() -> void:
	prompt = Label3D.new()
	prompt.position = Vector3(0, 1.7, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 22
	prompt.outline_size = 4
	prompt.no_depth_test = true
	add_child(prompt)
	objectives.objective_changed.connect(_refresh)
	_refresh(objectives.index)


func _refresh(_index: int) -> void:
	var mine := objectives.definition.objectives.find(objective)
	var active := objectives.index == mine
	# Only the active objective answers the interact key, so a finished console
	# cannot swallow input meant for a door.
	if active:
		add_to_group("interactable")
	elif is_in_group("interactable"):
		remove_from_group("interactable")
	prompt.visible = objectives.index >= mine
	var bindings := get_node_or_null("/root/KeybindingManager")
	var label := "[E] " + objective.prompt
	prompt.text = (bindings.format_prompt(label) if bindings != null else label) if active else "COMPLETE"
	prompt.modulate = Color(0.3, 0.9, 1.0) if active else Color(0.3, 1.0, 0.5)


func interact(player: Node = null) -> void:
	if not player is PlayerController3D:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_interact.rpc_id(1, get_path_to(player))
	else:
		_use(player)


@rpc("any_peer", "call_remote", "reliable")
func request_interact(player_path: NodePath) -> void:
	_use(Interaction.resolve(self, player_path, REACH))


func _use(player: PlayerController3D) -> void:
	if not multiplayer.is_server() or player == null or player.health_component == null:
		return
	var health := player.health_component
	if health.is_dead or health.is_downed or health.is_stunned:
		return
	if player.global_position.distance_to(global_position) <= REACH:
		objectives.complete_interaction(objective)
