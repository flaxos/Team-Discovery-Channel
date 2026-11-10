class_name MissionObjectives
extends Node
## Host-owned sequential objective progression for a modular level. The server decides
## every completion; clients receive the index of the active objective and a snapshot on
## joining. Objectives before `index` are complete; `index == size` means all are.
signal objective_changed(index: int)
signal completed
var definition: MissionDefinition
var level: LevelAssembly
var players: Node
var index := 0
var beacon: MeshInstance3D
var beacon_label: Label3D


func setup(mission: MissionDefinition, assembly: LevelAssembly, players_container: Node) -> void:
	definition = mission
	level = assembly
	players = players_container
	for objective in definition.objectives:
		if objective.kind == "interact":
			var station := MissionInteractable.new()
			station.name = "MissionInteract"
			station.objectives = self
			station.objective = objective
			_attachment_node(objective).add_child(station)
	_build_beacon()
	_show()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


func current() -> MissionObjective:
	return definition.objectives[index] if index < definition.objectives.size() else null


func is_complete() -> bool:
	return definition != null and index >= definition.objectives.size()


func position_of(objective: MissionObjective) -> Vector3:
	if objective.kind == "interact":
		return _attachment_node(objective).global_position
	if objective.marker == &"":
		return (level.get_node(str(objective.room)) as Node3D).global_position
	return level.marker(objective.room, objective.marker)


func _attachment_node(objective: MissionObjective) -> Node3D:
	return (
		level
		. get_node(str(objective.room))
		. get_node(LevelRoomComposer.node_path(definition.attachment(objective)))
	)


## Operatives able to act: alive and not downed.
func standing() -> Array[PlayerController3D]:
	var result: Array[PlayerController3D] = []
	for child in players.get_children():
		var player := child as PlayerController3D
		if player != null and player.health_component != null:
			if not player.health_component.is_dead and not player.health_component.is_downed:
				result.append(player)
	return result


func inside(player: Node3D, objective: MissionObjective) -> bool:
	if objective.marker == &"":
		var module := level.get_node(str(objective.room)) as Node3D
		var bounds := level.layout.instance(objective.room).module.occupied
		return bounds.has_point(module.to_local(player.global_position))
	var offset := player.global_position - position_of(objective)
	return Vector2(offset.x, offset.z).length() <= objective.radius and absf(offset.y) < 2.0


func _physics_process(_delta: float) -> void:
	if definition == null or not multiplayer.is_server() or is_complete():
		return
	var objective := current()
	var present := 0
	var squad := standing()
	for player in squad:
		if inside(player, objective):
			present += 1
	if objective.kind == "reach" and present > 0:
		_advance(index)
	elif objective.kind == "extract" and present > 0 and present == squad.size():
		_advance(index)


## Called by the objective's station after the server validated the operative.
func complete_interaction(objective: MissionObjective) -> bool:
	return objective != null and objective == current() and _advance(index)


func _advance(expected: int) -> bool:
	if not multiplayer.is_server() or expected != index or is_complete():
		return false
	if multiplayer.has_multiplayer_peer():
		sync_state.rpc(index + 1)
	else:
		sync_state(index + 1)
	return true


@rpc("authority", "call_local", "reliable")
func sync_state(value: int) -> void:
	# Monotonic: a snapshot crossing a live update, or a repeat, changes nothing.
	if value <= index or value > definition.objectives.size():
		return
	index = value
	_show()
	objective_changed.emit(index)
	if is_complete():
		completed.emit()


@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if multiplayer.is_server():
		sync_state.rpc_id(multiplayer.get_remote_sender_id(), index)


func _build_beacon() -> void:
	beacon = MeshInstance3D.new()
	beacon.name = "ObjectiveBeacon"
	var mesh := CylinderMesh.new()
	mesh.height = 0.06
	beacon.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = material
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(beacon)
	beacon_label = Label3D.new()
	beacon_label.position = Vector3(0, 2.4, 0)
	beacon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon_label.font_size = 28
	beacon_label.outline_size = 6
	beacon_label.no_depth_test = true
	beacon.add_child(beacon_label)


## Floor ring on the active reach/extract location, so the region is unmistakable.
func _show() -> void:
	var objective := current()
	beacon.visible = objective != null and objective.kind != "interact"
	if not beacon.visible:
		return
	var extraction := objective.kind == "extract"
	var mesh := beacon.mesh as CylinderMesh
	mesh.top_radius = objective.radius
	mesh.bottom_radius = objective.radius
	var colour := Color(0.2, 1.0, 0.4) if extraction else Color(0.3, 0.8, 1.0)
	(beacon.material_override as StandardMaterial3D).albedo_color = Color(colour, 0.3)
	beacon_label.text = "EXTRACTION" if extraction else "OBJECTIVE"
	beacon_label.modulate = colour
	beacon.global_position = position_of(objective) + Vector3(0, 0.05, 0)
