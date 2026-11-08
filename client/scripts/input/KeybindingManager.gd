extends Node
## Canonical gameplay actions. Only typed data is loaded from the user config.
signal bindings_changed
const CONFIG_PATH: String = "user://keybindings.cfg"
const COMBAT: String = "COMBAT & WEAPON CONTROLS"
const MOVEMENT: String = "MOVEMENT & STANCE CONTROLS"
const SQUAD: String = "SQUAD TACTICS & CAMERA CONTROLS"
const ACTIONS: Dictionary = {
	"aim": {"label": "Aim down sights (hold)", "category": COMBAT, "mouse": [MOUSE_BUTTON_RIGHT], "hold": true},
	"fire": {"label": "Fire weapon (hold)", "category": COMBAT, "mouse": [MOUSE_BUTTON_LEFT], "hold": true},
	"reload": {"label": "Reload weapon", "category": COMBAT, "keys": [KEY_R]},
	"weapon_primary": {"label": "Primary weapon", "category": COMBAT, "keys": [KEY_1]},
	"weapon_secondary": {"label": "Secondary weapon", "category": COMBAT, "keys": [KEY_2]},
	"deploy_shield": {"label": "Deploy ballistic shield", "category": COMBAT, "keys": [KEY_4]},
	"throw_smoke": {"label": "Throw smoke grenade", "category": COMBAT, "keys": [KEY_5]},
	"c4_mode": {"label": "Cycle C4 timer mode", "category": COMBAT, "keys": [KEY_T]},
	"gadget": {"label": "Class gadget / drag nearby body", "category": COMBAT, "keys": [KEY_G]},
	"plant_claymore": {"label": "Plant claymore", "category": COMBAT, "keys": [KEY_3]},
	"move_up": {"label": "Move forward (hold)", "category": MOVEMENT, "keys": [KEY_W, KEY_UP], "hold": true},
	"move_down": {"label": "Move backward (hold)", "category": MOVEMENT, "keys": [KEY_S, KEY_DOWN], "hold": true},
	"move_left": {"label": "Move left (hold)", "category": MOVEMENT, "keys": [KEY_A, KEY_LEFT], "hold": true},
	"move_right": {"label": "Move right (hold)", "category": MOVEMENT, "keys": [KEY_D, KEY_RIGHT], "hold": true},
	"crouch": {"label": "Toggle crouch", "category": MOVEMENT, "keys": [KEY_C, KEY_CTRL]},
	"sprint": {"label": "Sprint (hold)", "category": MOVEMENT, "keys": [KEY_SHIFT], "hold": true},
	"drag_body": {"label": "Toggle body dragging", "category": MOVEMENT, "keys": [KEY_H]},
	"interact": {"label": "Interact / revive / repair (hold)", "category": MOVEMENT, "keys": [KEY_E], "hold": true},
	"squad_command": {"label": "Squad wheel (hold) / context ping (tap)", "category": SQUAD, "keys": [KEY_Q], "mouse": [MOUSE_BUTTON_XBUTTON1], "hold": true},
	"squad_ping": {"label": "Quick squad context ping", "category": SQUAD, "mouse": [MOUSE_BUTTON_MIDDLE]},
	"zoom_in": {"label": "Zoom in", "category": SQUAD, "mouse": [MOUSE_BUTTON_WHEEL_UP]},
	"zoom_out": {"label": "Zoom out", "category": SQUAD, "mouse": [MOUSE_BUTTON_WHEEL_DOWN]},
	"toggle_pause": {"label": "Field manual / pause (ESC always available)", "category": SQUAD, "keys": [KEY_F1]},
}
var last_error: String = ""

func _ready() -> void:
	reset_defaults(false)
	load_bindings_from_config()
	get_tree().node_added.connect(_on_node_added)
	bindings_changed.connect(_refresh_prompts)

func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func mouse_event(button: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event

func default_events(action: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for code: int in ACTIONS[action].get("keys", []):
		events.append(key_event(code))
	for button: int in ACTIONS[action].get("mouse", []):
		events.append(mouse_event(button))
	return events

func set_events(action: String, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	Input.action_release(action)
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)

func reset_defaults(persist: bool = true) -> bool:
	for action: String in ACTIONS:
		set_events(action, default_events(action))
	bindings_changed.emit()
	return save_bindings_to_config() if persist else true

func event_data(event: InputEvent) -> Dictionary:
	var data: Dictionary = {}
	if event is InputEventKey:
		data = {"type": "key", "physical": event.physical_keycode, "keycode": event.keycode}
	elif event is InputEventMouseButton:
		data = {"type": "mouse", "button": event.button_index}
	else:
		return {}
	data.merge({"shift": event.shift_pressed, "ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "meta": event.meta_pressed})
	return data

func decode_event(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	for modifier: String in ["shift", "ctrl", "alt", "meta"]:
		if not data.get(modifier, false) is bool:
			return null
	var event: InputEventWithModifiers
	if data.get("type") == "key":
		var physical: Variant = data.get("physical", 0)
		var logical: Variant = data.get("keycode", 0)
		if not physical is int or not logical is int or physical < 0 or logical < 0 or maxi(physical, logical) > (1 << 25) or maxi(physical, logical) == 0:
			return null
		if physical == KEY_ESCAPE or logical == KEY_ESCAPE:
			return null
		var key := InputEventKey.new()
		key.physical_keycode = physical
		key.keycode = logical if physical == 0 else 0
		event = key
	elif data.get("type") == "mouse":
		var button: Variant = data.get("button", 0)
		if not button is int or button < MOUSE_BUTTON_LEFT or button > MOUSE_BUTTON_XBUTTON2:
			return null
		event = mouse_event(button)
	else:
		return null
	event.shift_pressed = data.get("shift", false)
	event.ctrl_pressed = data.get("ctrl", false)
	event.alt_pressed = data.get("alt", false)
	event.meta_pressed = data.get("meta", false)
	return event

func validate_event(action: String, event: InputEvent) -> String:
	if not ACTIONS.has(action) or decode_event(event_data(event)) == null:
		return "Unsupported input. ESC is reserved for cancel / resume."
	if ACTIONS[action].get("hold", false) and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return "This action requires a held key or button; the wheel sends only pulses."
	return ""

func conflicts_for(action: String, event: InputEvent) -> Array[String]:
	var conflicts: Array[String] = []
	for other: String in ACTIONS:
		if other == action:
			continue
		for binding: InputEvent in InputMap.action_get_events(other):
			if binding.is_match(event, false):
				conflicts.append(other)
				break
	return conflicts

func rebind(action: String, event: InputEvent, resolution: String = "cancel") -> bool:
	last_error = validate_event(action, event)
	if not last_error.is_empty():
		return false
	var clean: InputEvent = decode_event(event_data(event))
	var conflicts: Array[String] = conflicts_for(action, clean)
	var old: Array[InputEvent] = InputMap.action_get_events(action)
	var updates: Dictionary = {action: [clean]}
	if not conflicts.is_empty():
		if resolution not in ["swap", "replace"]:
			last_error = "Input already assigned. Choose Swap, Replace, or Cancel."
			return false
		if resolution == "swap" and conflicts.size() != 1:
			last_error = "Multiple actions conflict; swap requires one."
			return false
		for other: String in conflicts:
			var remaining: Array[InputEvent] = InputMap.action_get_events(other)
			if resolution == "swap":
				remaining = old.duplicate()
				for replacement: InputEvent in remaining:
					if not validate_event(other, replacement).is_empty():
						last_error = "The previous binding cannot be swapped to a hold action."
						return false
			else:
				for i: int in range(remaining.size() - 1, -1, -1):
					if remaining[i].is_match(clean, false):
						remaining.remove_at(i)
				if remaining.is_empty():
					last_error = "Replace would unbind %s. Use Swap or rebind it first." % ACTIONS[other].label
					return false
			updates[other] = remaining
	var previous: Dictionary = {}
	for changed: String in updates:
		previous[changed] = InputMap.action_get_events(changed)
		var events: Array[InputEvent] = []
		events.assign(updates[changed])
		set_events(changed, events)
	if not save_bindings_to_config():
		for changed: String in previous:
			set_events(changed, previous[changed])
		return false
	bindings_changed.emit()
	return true

func save_bindings_to_config(path: String = CONFIG_PATH) -> bool:
	var config := ConfigFile.new()
	config.set_value("Meta", "version", 1)
	for action: String in ACTIONS:
		var events: Array[Dictionary] = []
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event_data(event))
		config.set_value("Keybindings", action, events)
	var error: Error = config.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		last_error = "Could not save bindings (error %d)." % error
		return false
	last_error = ""
	return true

func load_bindings_from_config(path: String = CONFIG_PATH) -> bool:
	var config := ConfigFile.new()
	var error: Error = config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return save_bindings_to_config(path)
	if error != OK or config.get_value("Meta", "version", 0) != 1:
		last_error = "Invalid bindings file; using defaults."
		reset_defaults(false)
		return false
	# Read into a candidate map first; malformed entries recover to defaults.
	var candidate: Dictionary = {}
	for action: String in ACTIONS:
		var events: Array[InputEvent] = []
		var values: Variant = config.get_value("Keybindings", action, [])
		if values is Array:
			for value: Variant in values:
				var event: InputEvent = decode_event(value)
				if event != null and validate_event(action, event).is_empty():
					events.append(event)
		candidate[action] = events if not events.is_empty() else default_events(action)
	# A corrupt/conflicting file must not produce ambiguous gameplay inputs.
	var seen: Array[InputEvent] = []
	for action: String in candidate:
		for event: InputEvent in candidate[action]:
			for prior: InputEvent in seen:
				if prior.is_match(event, false):
					last_error = "Conflicting bindings file; using defaults."
					reset_defaults(false)
					return false
			seen.append(event)
	for action: String in candidate:
		set_events(action, candidate[action])
	bindings_changed.emit()
	return true

func binding_text(action: String) -> String:
	var labels: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		labels.append(event.as_text().replace(" (Physical)", ""))
	return " / ".join(labels)

func release_all() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)

const PROMPT_ACTIONS: Dictionary = {"E": "interact", "G": "gadget", "Q": "squad_command", "4": "deploy_shield", "5": "throw_smoke", "R": "reload", "F1": "toggle_pause", "3": "plant_claymore", "1": "weapon_primary", "2": "weapon_secondary", "H": "drag_body", "T": "c4_mode"}
var prompt_nodes: Dictionary = {}

func format_prompt(text: String) -> String:
	for token: String in PROMPT_ACTIONS:
		text = text.replace("[" + token + "]", "[" + binding_text(PROMPT_ACTIONS[token]) + "]")
	return text

func _prepare_prompt(reference: WeakRef) -> void:
	var node: Node = reference.get_ref() as Node
	if not is_instance_valid(node) or not (node is Label or node is Label3D):
		return
	var original: String = node.text
	var updated: String = format_prompt(original)
	if updated == original:
		# Still register canonical tokens even when the default label matches.
		var found: bool = false
		for token: String in PROMPT_ACTIONS:
			found = found or ("[" + token + "]") in original
		if not found:
			return
	prompt_nodes[node] = {"template": original, "last": updated}
	node.text = updated
	node.tree_exiting.connect(func() -> void: prompt_nodes.erase(node), CONNECT_ONE_SHOT)

func _on_node_added(node: Node) -> void:
	if node is Label or node is Label3D:
		_prepare_prompt.call_deferred(weakref(node))

func _refresh_prompts() -> void:
	for node: Node in prompt_nodes:
		if is_instance_valid(node) and node.text == prompt_nodes[node].last:
			var updated: String = format_prompt(prompt_nodes[node].template)
			node.text = updated
			prompt_nodes[node].last = updated
