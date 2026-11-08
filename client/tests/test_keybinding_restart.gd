extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var manager: Node = root.get_node("KeybindingManager")
	if "--write" in OS.get_cmdline_user_args():
		manager.reset_defaults(false)
		var event: InputEventKey = manager.key_event(KEY_P)
		event.ctrl_pressed = true
		assert(manager.rebind("interact", event), "Writer must save physical key and modifier")
		assert(manager.rebind("squad_ping", manager.mouse_event(MOUSE_BUTTON_XBUTTON2)), "Writer must save mouse binding")
		print("PASS fresh-process writer")
	else:
		var events: Array[InputEvent] = InputMap.action_get_events("interact")
		assert(events.size() == 1 and events[0] is InputEventKey, "Fresh boot must load custom event")
		assert(events[0].physical_keycode == KEY_P and events[0].ctrl_pressed, "Fresh process must retain key and modifier")
		assert(InputMap.action_get_events("squad_ping")[0].button_index == MOUSE_BUTTON_XBUTTON2, "Fresh process must retain mouse binding")
		manager.reset_defaults()
		print("PASS fresh-process reader and default reset")
	quit(0)
