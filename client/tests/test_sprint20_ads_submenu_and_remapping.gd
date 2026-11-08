extends SceneTree
var world: Node3D
var player: PlayerController3D
var hud: TacticalHUD
var manager: Node

func _init() -> void:
	call_deferred("run_tests")

func press(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func run_tests() -> void:
	manager = root.get_node("KeybindingManager")
	manager.reset_defaults(false)
	assert(not InputMap.action_has_event("gadget", press(KEY_Q)), "Q cannot also deploy gadgets")
	assert(manager.rebind("reload", press(KEY_K)), "Keyboard remap must save")
	assert(press(KEY_K).is_action_pressed("reload"), "New reload binding must activate")
	assert(not press(KEY_R).is_action_pressed("reload"), "Old reload binding must deactivate")
	assert(FileAccess.file_exists("user://keybindings.cfg"), "Config must exist")
	manager.reset_defaults(false)
	assert(manager.load_bindings_from_config(), "Saved bindings must reload")
	assert(press(KEY_K).is_action_pressed("reload"), "Reload must survive loading")

	# All requested mouse inputs can drive a discrete action, including wheel pulses.
	for button: int in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		manager.reset_defaults(false)
		var event: InputEventMouseButton = manager.mouse_event(button)
		event.pressed = true
		assert(manager.rebind("reload", event, "swap"), "Mouse binding must be supported")
		assert(event.is_action_pressed("reload"), "Mouse event must activate remapped action")
	assert(not manager.validate_event("aim", manager.mouse_event(MOUSE_BUTTON_WHEEL_UP)).is_empty(), "Wheel cannot sustain a hold")
	manager.reset_defaults(false)
	assert(not manager.rebind("reload", press(KEY_E), "replace"), "Replace cannot strand interact")
	assert(press(KEY_E).is_action_pressed("interact"), "Rejected conflict must leave bindings intact")
	var overlap: InputEventKey = press(KEY_W)
	overlap.ctrl_pressed = true
	assert(manager.conflicts_for("reload", overlap).has("move_up"), "Modifier chords must warn about plain-key overlaps")
	assert(manager.rebind("reload", press(KEY_E), "swap"), "Swap must resolve conflict")
	assert(press(KEY_R).is_action_pressed("interact"), "Swap must retain both actions")
	assert(manager.rebind("reload", press(KEY_UP), "replace"), "Replace may remove an alternate")
	assert(press(KEY_W).is_action_pressed("move_up"), "Remaining alternate must survive")
	var modified: InputEventKey = press(KEY_B)
	modified.ctrl_pressed = true
	modified.shift_pressed = true
	assert(manager.rebind("reload", modified), "Modifiers must be supported")
	assert(manager.load_bindings_from_config(), "Modifier config must load")
	var decoded: InputEventKey = InputMap.action_get_events("reload")[0] as InputEventKey
	assert(decoded.physical_keycode == KEY_B and decoded.ctrl_pressed and decoded.shift_pressed, "Physical code and modifiers must persist")
	assert(not manager.save_bindings_to_config("user://missing/folder/bindings.cfg"), "Write failures must be reported")

	var corrupt := ConfigFile.new()
	corrupt.set_value("Meta", "version", 1)
	corrupt.set_value("Keybindings", "fire", [{"type": "mouse", "button": -8}])
	corrupt.set_value("Keybindings", "aim", ["invalid"])
	corrupt.save("user://invalid-test.cfg")
	assert(manager.load_bindings_from_config("user://invalid-test.cfg"), "Malformed entries must recover safely")
	assert(InputMap.action_get_events("fire")[0].button_index == MOUSE_BUTTON_LEFT, "Invalid fire entry restores default")
	corrupt.set_value("Meta", "version", 999)
	corrupt.save("user://invalid-test.cfg")
	assert(not manager.load_bindings_from_config("user://invalid-test.cfg"), "Unsupported file version must recover to defaults")
	print("PASS persistence, typed validation, modifiers, conflict handling, reset and mouse inputs")

	world = load("res://scenes/main/GateRoom.tscn").instantiate() as Node3D
	root.add_child(world)
	player = load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	player.name = "Sprint20Player"
	world.get_node("Players").add_child(player)
	player.set_physics_process(false)
	hud = world.get_node("TacticalHUD") as TacticalHUD
	player.global_position = Vector3(0, 0.1, 4)
	await process_frame
	var modal: KeybindingsModal = hud.keybindings_modal
	modal.open_modal(false)
	await process_frame
	await process_frame
	assert(root.get_visible_rect().encloses(modal.terminal_panel.get_global_rect()), "Controls terminal must fit the viewport")
	assert(modal.binding_buttons.size() == manager.ACTIONS.size(), "Every implemented action needs an interactive row")
	modal.binding_buttons.reload.pressed.emit()
	await process_frame
	var repeated: InputEventKey = press(KEY_K)
	repeated.echo = true
	modal._input(repeated)
	assert(modal.awaiting_action == "reload", "Repeats cannot bind")
	modal._input(press(KEY_K))
	assert(modal.awaiting_action.is_empty() and press(KEY_K).is_action_pressed("reload"), "UI capture must update InputMap")
	modal.begin_capture("fire")
	await process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	modal._input(esc)
	assert(modal.awaiting_action.is_empty() and modal.visible, "ESC cancels capture before closing modal")
	modal.begin_capture("reload")
	await process_frame
	modal._input(press(KEY_E))
	assert(modal.pending_event != null and modal.conflict_buttons.visible, "Conflicts need explicit choice")
	modal.resolve_conflict("cancel")
	assert(press(KEY_K).is_action_pressed("reload"), "Cancel preserves previous input")
	modal.begin_capture("aim")
	modal.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(modal.awaiting_action.is_empty(), "Focus loss cancels capture")
	modal.close_modal(false)
	manager.reset_defaults(false)

	# A remapped interact press must open the lift once, not dispatch it immediately.
	var lift: SGCElevator = world.get_node("SGCElevator") as SGCElevator
	player.global_position = lift.call_pedestal_28.global_position + Vector3(0, 0.1, 0)
	assert(manager.rebind("interact", press(KEY_P)), "Interact must remap")
	player.set_physics_process(true)
	Input.parse_input_event(press(KEY_P))
	Input.flush_buffered_events()
	await physics_frame
	await process_frame
	player.set_physics_process(false)
	assert(lift.is_doors_open and not lift.is_moving, "One remapped press must open doors without double dispatch")
	manager.release_all()
	manager.reset_defaults(false)
	player.global_position = Vector3(0, 0.1, 4)
	# Test routing through controller + HUD while ADS is physically held.
	Input.action_press("aim")
	player.is_aiming_down_sights = true
	player.ads_blend = 1.0
	for direction: Vector2 in [Vector2(0, -100), Vector2(100, 0), Vector2(0, 100), Vector2(-100, 100), Vector2(-100, 0), Vector2.ZERO]:
		player._unhandled_input(press(KEY_Q))
		player.command_press_time_ms = Time.get_ticks_msec() - 250
		player._physics_process(1.0 / 60.0)
		assert(player.is_command_wheel_open, "Held Q must open wheel while ADS is held")
		var locked: Vector3 = player.locked_target_world_pos
		var yaw: float = player.rotation.y
		var pitch: float = player.ads_pitch_rad
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_visible_rect().size * 0.5
		motion.relative = direction
		player._unhandled_input(motion)
		var expected: int = -1 if direction == Vector2.ZERO else hud.radial_wheel._angle_to_slice(rad_to_deg(atan2(-direction.y, direction.x)))
		assert(hud.get_radial_selected_command() == expected, "Relative motion must select every slice / cancel")
		assert(player.rotation.y == yaw and player.ads_pitch_rad == pitch, "Wheel must freeze camera look")
		var release: InputEventKey = press(KEY_Q)
		release.pressed = false
		player._unhandled_input(release)
		assert(not player.is_command_wheel_open and player.is_aiming_down_sights and Input.is_action_pressed("aim"), "Release confirms without losing ADS")
		var waypoint_count: int = root.find_children("CommandWaypointFX*", "", true, false).size()
		player._unhandled_input(release)
		assert(root.find_children("CommandWaypointFX*", "", true, false).size() == waypoint_count, "Duplicate release must not dispatch another order")
		assert(player.locked_target_world_pos == locked, "Order target must remain locked")
		player._unhandled_input(motion)
		if direction.x != 0:
			assert(player.rotation.y != yaw, "Look must resume after closing wheel")
	player.open_squad_command_wheel()
	var remote := load("res://scenes/entities/Player.tscn").instantiate() as PlayerController3D
	remote.name = "2"
	world.get_node("Players").add_child(remote)
	remote.free()
	assert(player.is_command_wheel_open and hud.is_radial_wheel_open(), "Remote actor teardown must not close the local wheel")
	player.close_squad_command_wheel()
	assert(manager.rebind("squad_command", press(KEY_V)), "Squad command must be remappable")
	player._unhandled_input(press(KEY_Q))
	assert(not player.is_holding_command_input, "Old Q binding must no longer act")
	player._unhandled_input(press(KEY_V))
	assert(player.is_holding_command_input, "Remapped command must act")
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not player.is_holding_command_input and not player.is_command_wheel_open, "Focus loss must cancel pending holds")
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(manager.rebind("weapon_secondary", press(KEY_J)), "Weapon slot remap must save")
	player._unhandled_input(press(KEY_J))
	assert(player.active_slot == 2, "Remapped weapon key must switch gameplay slot")
	var label := Label.new()
	label.text = "[E] INTERACT"
	world.add_child(label)
	await process_frame
	await process_frame
	assert(manager.rebind("interact", press(KEY_P)), "Prompt action must rebind")
	assert("P" in label.text and not "[E]" in label.text, "Existing scene prompts must refresh")
	assert(manager.format_prompt("[3] CLAYMORE") == "[" + manager.binding_text("plant_claymore") + "] CLAYMORE", "Dynamic prompts use active bindings")
	manager.reset_defaults()
	world.queue_free()
	await process_frame
	print("PASS interactive capture, ADS radial routing, look restoration and remapped gameplay")
	quit(0)
