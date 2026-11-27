class_name MissionEvents
extends Node
## Host-owned, one-shot mission actions: objective security releases and objective/alarm time.
## Doors retain collision, occupied-door protection and their own late-join snapshots.
signal trigger_fired(id: StringName)
signal notice_shown(text: String)
signal countdown_changed(label: String, remaining: float, running: bool)
signal timer_expired(id: StringName)
enum TimerState { IDLE, RUNNING, STOPPED, EXPIRED }

var definition: MissionDefinition
var objectives: MissionObjectives
var alert: MissionAlert
var fired := PackedStringArray()
var active := false
var _level: LevelAssembly
var _doors: Dictionary = {}
var _pending_locks: Dictionary = {}
var _has_room_triggers := false
var _started := false
var _waiting_peers: Dictionary = {}
var timer_state := TimerState.IDLE
var timer_id: StringName
var _deadline_msec := 0
var _stopped_remaining := 0.0
var _timer_revision := 0
var _last_timer_revision := -1
var _next_timer_sync := 0
var timer_duration_scale: float = 1.0


func configure_difficulty(tier: int, modifiers: Array = []) -> void:
	timer_duration_scale = MissionDifficulty.timer_duration_scale(tier, modifiers)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(mission: MissionDefinition, level: LevelAssembly, progress: MissionObjectives, compound_alert: MissionAlert) -> void:
	definition = mission
	_level = level
	objectives = progress
	alert = compound_alert
	_doors.clear()
	_pending_locks.clear()
	_has_room_triggers = false
	for trigger in definition.triggers:
		if trigger.condition == "room_entered":
			_has_room_triggers = true
		if trigger.action not in ["release_door", "lock_door"]:
			continue
		for child in level.get_children():
			var door := child as ModularDoor
			if door != null and door.is_security and door.security_id == trigger.security_id:
				_doors[trigger.id] = door
	objectives.objective_changed.connect(_on_objective_changed)
	alert.level_changed.connect(_on_alert_changed)
	if not definition.triggers.is_empty() and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_snapshot.rpc_id(1)


## Lock after navigation validation, before patrol startup: these are temporary mission
## gates, not permanently inaccessible rooms in the native structural layout.
func start() -> PackedStringArray:
	var errors := PackedStringArray()
	if _started or definition.triggers.is_empty():
		return errors
	for trigger in definition.triggers:
		if trigger.action in ["release_door", "lock_door"] and not _doors.has(trigger.id):
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
		_on_alert_changed(alert.alert_level)
		if _has_room_triggers:
			_check_room_entries()
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
	_pending_locks.clear()
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


func _physics_process(_delta: float) -> void:
	if not active or not multiplayer.is_server() or get_tree().paused:
		return
	_retry_pending_locks()
	if _has_room_triggers:
		_check_room_entries()


func _retry_pending_locks() -> void:
	if _pending_locks.is_empty():
		return
	for trigger: MissionTrigger in _pending_locks.values():
		_apply(trigger)


func _check_room_entries() -> void:
	for trigger in definition.triggers:
		if trigger.condition == "room_entered" and not fired.has(str(trigger.id)) and _standing_in_room(trigger.room):
			_apply(trigger)


func _standing_in_room(room_id: StringName) -> bool:
	if _level == null or _level.layout == null or objectives == null or objectives.players == null:
		return false
	var module := _level.get_node_or_null(str(room_id)) as Node3D
	var item := _level.layout.instance(room_id)
	if module == null or item == null or item.module == null:
		return false
	for player: PlayerController3D in objectives.standing():
		if item.module.occupied.has_point(module.to_local(player.global_position + Vector3.UP * 0.25)):
			return true
	return false


func _on_objective_changed(_index: int) -> void:
	if not active or not multiplayer.is_server():
		return
	for trigger in definition.triggers:
		if trigger.condition != "objective_completed":
			continue
		for i in range(definition.objectives.size()):
			if not objectives.is_objective_completed(i):
				continue
			if definition.objectives[i].id != trigger.objective_id:
				continue
			_apply(trigger)
			break


func _on_alert_changed(value: int) -> void:
	if not active or not multiplayer.is_server():
		return
	if value >= MissionAlert.Level.SEARCHING:
		for trigger in definition.triggers:
			if trigger.condition == "alert_searching":
				_apply(trigger)
	if value == MissionAlert.Level.ALARM and alert.is_raised():
		for trigger in definition.triggers:
			if trigger.condition == "alarm_raised":
				_apply(trigger)


func _apply(trigger: MissionTrigger) -> void:
	if not active or not multiplayer.is_server() or fired.has(str(trigger.id)):
		return
	var applied := false
	if trigger.action == "release_door":
		applied = (_doors[trigger.id] as ModularDoor).set_locked(false)
	elif trigger.action == "lock_door":
		var door := _doors.get(trigger.id) as ModularDoor
		if door != null:
			applied = door.set_locked(true)
			if not applied and not door.locked:
				_pending_locks[trigger.id] = trigger
	elif trigger.action == "start_timer" and timer_state == TimerState.IDLE:
		timer_id = trigger.id
		timer_state = TimerState.RUNNING
		var scaled_seconds: float = trigger.duration_seconds if is_equal_approx(timer_duration_scale, 1.0) else trigger.duration_seconds * timer_duration_scale
		_deadline_msec = Time.get_ticks_msec() + int(scaled_seconds * 1000.0)
		_publish_timer()
		_show_timer()
		applied = true
	elif trigger.action == "enable_objective":
		applied = objectives.enable_objective(trigger.target_objective_id)
	elif trigger.action == "show_notice":
		applied = true
	if applied:
		_pending_locks.erase(trigger.id)
		fired.append(str(trigger.id))
		trigger_fired.emit(trigger.id)
		if not trigger.notice.is_empty():
			notice_shown.emit(trigger.notice)
		SGCNetworkManager.mission_rpc(self, &"sync_fired", [fired, str(trigger.id)])


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
			if id == live_id and not trigger.notice.is_empty():
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
