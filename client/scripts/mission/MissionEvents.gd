class_name MissionEvents
extends Node
## Host-owned, one-shot objective actions: security releases and an extraction timer.
## Doors retain collision, occupied-door protection and their own late-join snapshots.
signal trigger_fired(id: StringName)
signal notice_shown(text: String)
signal countdown_changed(label: String, remaining: float, running: bool)
signal timer_expired(id: StringName)
enum TimerState { IDLE, RUNNING, STOPPED, EXPIRED }

var definition: MissionDefinition
var objectives: MissionObjectives
var fired := PackedStringArray()
var active := false
var _doors: Dictionary = {}
var _started := false
var _waiting_peers: Dictionary = {}
var timer_state := TimerState.IDLE
var timer_id: StringName
var _deadline_msec := 0
var _stopped_remaining := 0.0
var _timer_revision := 0
var _last_timer_revision := -1
var _next_timer_sync := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(mission: MissionDefinition, level: LevelAssembly, progress: MissionObjectives) -> void:
	definition = mission
	objectives = progress
	for trigger in definition.triggers:
		if trigger.action != "release_door":
			continue
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
		if trigger.action == "release_door" and not _doors.has(trigger.id):
			errors.append("Missing runtime security door: %s" % trigger.security_id)
	if not errors.is_empty():
		return errors
	active = true
	_started = true
	if multiplayer.is_server():
		for trigger in definition.triggers:
			if trigger.action == "release_door" and not (_doors[trigger.id] as ModularDoor).set_locked(true):
				errors.append("Could not initialize mission door: %s" % trigger.security_id)
		_on_objective_changed(objectives.index)
		for peer: int in _waiting_peers:
			_send_snapshot(peer)
		_waiting_peers.clear()
	else:
		# Constructors can snapshot doors before the host has finished its bake. This
		# request waits for host initialization and refreshes both event and door state.
		request_snapshot.rpc_id(1)
	_show_timer()
	return errors


func stop() -> void:
	active = false
	if multiplayer.is_server() and timer_state == TimerState.RUNNING:
		_stopped_remaining = remaining_seconds()
		timer_state = TimerState.STOPPED
		_publish_timer()
	_show_timer()


func remaining_seconds() -> float:
	return maxf(0.0, (_deadline_msec - Time.get_ticks_msec()) / 1000.0) if timer_state == TimerState.RUNNING else _stopped_remaining


## Central objective admission: expiry wins before accepting a late interaction or extraction.
func allow_progress() -> bool:
	if timer_state == TimerState.EXPIRED or timer_state == TimerState.STOPPED:
		return false
	if multiplayer.is_server() and timer_state == TimerState.RUNNING and remaining_seconds() <= 0.0:
		_expire_timer()
		return false
	return true


func _process(_delta: float) -> void:
	if not active or timer_state != TimerState.RUNNING:
		return
	if multiplayer.is_server():
		if not allow_progress():
			return
		if Time.get_ticks_msec() >= _next_timer_sync:
			_publish_timer()
	_show_timer()


func _expire_timer() -> bool:
	if not multiplayer.is_server() or not active or timer_state != TimerState.RUNNING or remaining_seconds() > 0.0:
		return false
	timer_state = TimerState.EXPIRED
	_stopped_remaining = 0.0
	_publish_timer()
	_show_timer()
	timer_expired.emit(timer_id)
	return true


func _timer_trigger(id: StringName) -> MissionTrigger:
	if definition != null:
		for trigger in definition.triggers:
			if trigger.action == "start_timer" and trigger.id == id:
				return trigger
	return null


func _show_timer() -> void:
	var trigger := _timer_trigger(timer_id)
	countdown_changed.emit(trigger.timer_label if trigger != null else "", remaining_seconds(), active and timer_state == TimerState.RUNNING)


func _publish_timer() -> void:
	_timer_revision += 1
	_next_timer_sync = Time.get_ticks_msec() + 250
	SGCNetworkManager.mission_rpc(self, &"sync_countdown", [_timer_revision, str(timer_id), timer_state, remaining_seconds()])


@rpc("authority", "call_remote", "reliable")
func sync_countdown(revision: int, id: String, state: int, seconds: float) -> void:
	if multiplayer.is_server() or revision <= _last_timer_revision or not is_finite(seconds) or seconds < 0.0:
		return
	if state < TimerState.IDLE or state > TimerState.EXPIRED:
		return
	var trigger := _timer_trigger(StringName(id))
	if state == TimerState.IDLE:
		if id != "" or timer_state != TimerState.IDLE or seconds != 0.0:
			return
	elif trigger == null or seconds > trigger.duration_seconds:
		return
	if timer_state in [TimerState.STOPPED, TimerState.EXPIRED] and state != timer_state:
		return
	var next_deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	# Receipt-anchored estimates refresh without extending an already displayed window.
	if timer_state == TimerState.RUNNING and state == TimerState.RUNNING:
		next_deadline = mini(_deadline_msec, next_deadline)
	_last_timer_revision = revision
	timer_id = StringName(id)
	timer_state = state as TimerState
	_deadline_msec = next_deadline
	_stopped_remaining = seconds
	_show_timer()


func _on_objective_changed(index: int) -> void:
	if not active or not multiplayer.is_server():
		return
	for trigger in definition.triggers:
		if fired.has(str(trigger.id)):
			continue
		for i in range(mini(index, objectives.index)):
			if definition.objectives[i].id != trigger.objective_id:
				continue
			var applied := false
			if trigger.action == "release_door":
				applied = (_doors[trigger.id] as ModularDoor).set_locked(false)
			elif trigger.action == "start_timer" and timer_state == TimerState.IDLE:
				timer_id = trigger.id
				timer_state = TimerState.RUNNING
				_deadline_msec = Time.get_ticks_msec() + int(trigger.duration_seconds * 1000.0)
				_publish_timer()
				_show_timer()
				applied = true
			if applied:
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
	_timer_revision += 1
	sync_countdown.rpc_id(peer, _timer_revision, str(timer_id), timer_state, remaining_seconds())
