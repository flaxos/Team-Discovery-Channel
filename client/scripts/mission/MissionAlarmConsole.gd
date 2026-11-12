class_name MissionAlarmConsole
extends Node3D
## Makes a room attachment an alarm console (MissionAlarm). Operatives can disable it until the
## alarm is raised. Clients send identity only; the server validates sender, reach and health.
const Interaction = preload("res://scripts/net/ServerInteraction.gd")
const REACH := 3.5
## The prompt is shown only this close, so consoles are not advertised through the compound.
const PROMPT_RANGE := 12.0
## The mission's MissionAlert. Untyped on purpose: the two scripts would otherwise reference
## each other and never be freed.
var alert: Node
var index := 0
var prompt: Label3D


func _ready() -> void:
	prompt = Label3D.new()
	prompt.position = Vector3(0, 1.7, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 22
	prompt.outline_size = 4
	prompt.no_depth_test = true
	prompt.visibility_range_end = PROMPT_RANGE
	add_child(prompt)
	refresh()


## Text and interactability follow the replicated alert state.
func refresh() -> void:
	if prompt == null:
		return
	var disabled: bool = alert.is_disabled(index)
	var raised: bool = alert.is_raised()
	var usable := not disabled and not raised
	if usable:
		add_to_group("interactable")
	elif is_in_group("interactable"):
		remove_from_group("interactable")
	if raised and not disabled:
		prompt.text = "ALARM ACTIVE"
		prompt.modulate = Color(1.0, 0.3, 0.2)
	elif disabled:
		prompt.text = "ALARM DISABLED"
		prompt.modulate = Color(0.3, 1.0, 0.5)
	else:
		var bindings := get_node_or_null("/root/KeybindingManager")
		var label := "[E] " + str(alert.definition.alarms[index].prompt)
		prompt.text = bindings.format_prompt(label) if bindings != null else label
		prompt.modulate = Color(1.0, 0.75, 0.2)


func interact(player: Node = null) -> void:
	if not player is PlayerController3D:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_disable.rpc_id(1, get_path_to(player))
	else:
		_use(player)


@rpc("any_peer", "call_remote", "reliable")
func request_disable(player_path: NodePath) -> void:
	_use(Interaction.resolve(self, player_path, REACH))


func _use(player: PlayerController3D) -> void:
	if not multiplayer.is_server() or player == null or player.health_component == null:
		return
	var health := player.health_component
	if health.is_dead or health.is_downed or health.is_stunned:
		return
	if player.global_position.distance_to(global_position) <= REACH:
		alert.disable(index)
