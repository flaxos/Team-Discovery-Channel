class_name MissionEvents
extends Node
## Host-owned, one-shot objective -> security-door releases. Doors retain their own
## authority, collision, occupied-door protection and late-join snapshots.
signal trigger_fired(id: StringName)
signal notice_shown(text: String)

var definition: MissionDefinition
var objectives: MissionObjectives
var fired := PackedStringArray()
var active := false
var _doors: Dictionary = {}
var _started := false
var _waiting_peers: Dictionary = {}


func setup(mission: MissionDefinition, level: LevelAssembly, progress: MissionObjectives) -> void:
	definition = mission
	objectives = progress
	for trigger in definition.triggers:
		for child in level.get_children():
			var door := child as ModularDoor
			if door != null and door.is_security and door.security_id == trigger.security_id:
				_doors[trigger.id] = door
	objectives.objective_changed.connect(_on_objective_changed)
	if not definition.triggers.is_empty() and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


## Lock after navigation validation, before patrol startup: these are temporary mission
## gates, not permanently inaccessible rooms in the native structural layout.
func start() -> PackedStringArray:
	var errors := PackedStringArray()
	if _started or definition.triggers.is_empty():
		return errors
	for trigger in definition.triggers:
		if not _doors.has(trigger.id):
			errors.append("Missing runtime security door: %s" % trigger.security_id)
	if not errors.is_empty():
		return errors
	active = true
	_started = true
	if multiplayer.is_server():
		for trigger in definition.triggers:
			if not (_doors[trigger.id] as ModularDoor).set_locked(true):
				errors.append("Could not initialize mission door: %s" % trigger.security_id)
		_on_objective_changed(objectives.index)
		for peer: int in _waiting_peers:
			_send_snapshot(peer)
		_waiting_peers.clear()
	else:
		# Constructors can snapshot doors before the host has finished its bake. This
		# request waits for host initialization and refreshes both event and door state.
		request_snapshot.rpc_id(1)
	return errors


func stop() -> void:
	active = false


func _on_objective_changed(index: int) -> void:
	if not active or not multiplayer.is_server():
		return
	for trigger in definition.triggers:
		if fired.has(str(trigger.id)):
			continue
		for i in range(mini(index, objectives.index)):
			if definition.objectives[i].id != trigger.objective_id:
				continue
			var door := _doors[trigger.id] as ModularDoor
			if door.set_locked(false):
				fired.append(str(trigger.id))
				trigger_fired.emit(trigger.id)
				notice_shown.emit(trigger.notice)
				SGCNetworkManager.mission_rpc(self, &"sync_fired", [fired, str(trigger.id)])
			break


@rpc("authority", "call_remote", "reliable")
func sync_fired(ids: PackedStringArray, live_id: String = "") -> void:
	# Monotonic within a world. A snapshot crossing a live update cannot undo a release,
	# and duplicate packets cannot replay a notice. Snapshots deliberately show no toast.
	if definition == null:
		return
	for trigger in definition.triggers:
		var id := str(trigger.id)
		if ids.has(id) and not fired.has(id):
			fired.append(id)
			trigger_fired.emit(trigger.id)
			if id == live_id:
				notice_shown.emit(trigger.notice)


@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		if sender in multiplayer.get_peers():
			if _started:
				_send_snapshot(sender)
			else:
				_waiting_peers[sender] = true


func _send_snapshot(peer: int) -> void:
	if peer not in multiplayer.get_peers():
		return
	for door: ModularDoor in _doors.values():
		door.sync_security_state.rpc_id(peer, door.is_open, door.locked)
	sync_fired.rpc_id(peer, fired)
