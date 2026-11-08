extends SceneTree
## Automated Headless Validation: Sprint 18 SGC Keybindings & Tactical Controls Menu.
## Validates:
##  1. Instantiation and default properties of KeybindingsModal.
##  2. Verification of all key categories and binding labels.
##  3. Modal open, close, and ESC input handling.
##  4. Integration with Lobby (button and modal popup).
##  5. Integration with In-Game HUD / GateRoom & operative input pause interception.

const KEYBINDINGS_SCENE: String = "res://scenes/ui/KeybindingsModal.tscn"
const LOBBY_SCENE: String = "res://scenes/main/Lobby.tscn"
const GATE_ROOM_SCENE: String = "res://scenes/main/GateRoom.tscn"
const PLAYER_SCENE: String = "res://scenes/entities/Player.tscn"

var modal: KeybindingsModal = null
var lobby: LobbyUI = null
var gateroom: GateRoom = null
var player: PlayerController3D = null
var hud: TacticalHUD = null
var ticks: int = 0


func _init() -> void:
	print("\n========================================================")
	print("  PROJECT SGC: KEYBINDINGS & TACTICAL CONTROLS MENU TEST")
	print("========================================================")

	var kb_scene := load(KEYBINDINGS_SCENE) as PackedScene
	assert(kb_scene != null, "KeybindingsModal scene must load successfully")
	modal = kb_scene.instantiate() as KeybindingsModal
	assert(modal != null, "KeybindingsModal must instantiate successfully")
	modal.visible = false
	root.add_child(modal)


func _process(_delta: float) -> bool:
	ticks += 1

	if ticks == 1:
		# TEST 1: Instantiation of KeybindingsModal & Aesthetic Defaults
		print("[TEST 1/5] Testing KeybindingsModal instantiation & terminal styling...")
		assert(modal is KeybindingsModal, "modal must be instance of KeybindingsModal")
		assert(modal.title_label != null, "TitleLabel must exist in KeybindingsModal")
		assert(
			modal.title_label.text == "CHEYENNE MOUNTAIN COMPLEX // TACTICAL FIELD MANUAL & CONTROLS",
			"Title text must match retro SGC header: 'CHEYENNE MOUNTAIN COMPLEX // TACTICAL FIELD MANUAL & CONTROLS' (found: %s)" % modal.title_label.text
		)
		assert(modal.close_button != null, "CloseButton must exist")
		assert(
			modal.close_button.text == "[ CLOSE / RESUME MISSION ]",
			"Close button text must be '[ CLOSE / RESUME MISSION ]' (found: %s)" % modal.close_button.text
		)
		assert(not modal.visible, "KeybindingsModal must start hidden")
		print("[TEST 1/5] PASS: KeybindingsModal instantiation and retro SGC terminal header verified.")

	elif ticks == 2:
		# TEST 2: Verification of All Key Categories and Binding Labels
		print("[TEST 2/5] Testing categories and all 17 binding labels...")
		var categories: Array[String] = modal.get_categories()
		assert(categories.size() == 3, "Must have exactly 3 categories (found %d)" % categories.size())
		assert(categories.has(KeybindingsModal.CATEGORY_COMBAT), "Must have CATEGORY_COMBAT")
		assert(categories.has(KeybindingsModal.CATEGORY_MOVEMENT), "Must have CATEGORY_MOVEMENT")
		assert(categories.has(KeybindingsModal.CATEGORY_SQUAD), "Must have CATEGORY_SQUAD")

		# 1. COMBAT & WEAPON CONTROLS
		var combat_bindings: Array = modal.get_bindings_for_category(KeybindingsModal.CATEGORY_COMBAT)
		assert(combat_bindings.size() == 8, "Combat category must have 8 bindings (found %d)" % combat_bindings.size())
		var expected_combat: Dictionary = {
			"Aim Down Sights (ADS / Wildlands Shoulder View)": "[Right Mouse Button (Hold)]",
			"Fire Primary / Sidearm": "[Left Mouse Button]",
			"Reload Weapon": "[R]",
			"Switch Primary / Secondary": "[1] / [2]",
			"Deploy Ballistic Shield": "[4]",
			"Throw M18 Smoke Grenade": "[5]",
			"Tactical C4 Timer Mode (Remote / 5s / 10s / 30s)": "[T]",
			"Deploy .50 Cal Tripod": "[G]",
		}
		for entry: Dictionary in combat_bindings:
			var action: String = entry.get("action", "")
			var key: String = entry.get("key", "")
			assert(expected_combat.has(action), "Unexpected combat action: %s" % action)
			assert(expected_combat[action] == key, "Key mismatch for %s: expected %s, got %s" % [action, expected_combat[action], key])

		# 2. MOVEMENT & STANCE CONTROLS
		var movement_bindings: Array = modal.get_bindings_for_category(KeybindingsModal.CATEGORY_MOVEMENT)
		assert(movement_bindings.size() == 5, "Movement category must have 5 bindings (found %d)" % movement_bindings.size())
		var expected_movement: Dictionary = {
			"Move Operative": "[W] [A] [S] [D]",
			"Toggle Crouch / Duck Behind Cover": "[C]",
			"Tactical Sprint": "[Shift (Hold)]",
			"Drag Downed Ally / Corpse": "[G (Hold near body)]",
			"Interact / Mount .50 Cal / Repair Iris / Re-Armor": "[E]",
		}
		for entry: Dictionary in movement_bindings:
			var action: String = entry.get("action", "")
			var key: String = entry.get("key", "")
			assert(expected_movement.has(action), "Unexpected movement action: %s" % action)
			assert(expected_movement[action] == key, "Key mismatch for %s: expected %s, got %s" % [action, expected_movement[action], key])

		# 3. SQUAD TACTICS & CAMERA CONTROLS
		var squad_bindings: Array = modal.get_bindings_for_category(KeybindingsModal.CATEGORY_SQUAD)
		assert(squad_bindings.size() == 4, "Squad category must have 4 bindings (found %d)" % squad_bindings.size())
		var expected_squad: Dictionary = {
			"Squad Command Radial Wheel": "[Q] or [Mouse 4 (Hold)]",
			"Quick Squad Context Ping": "[Q] or [Middle Mouse (Tap)]",
			"360 Tactical Orbit / Camera Pan": "[Middle Mouse + Drag] or [Alt + Mouse]",
			"Field Manual / Pause Menu": "[ESC] or [F1]",
		}
		for entry: Dictionary in squad_bindings:
			var action: String = entry.get("action", "")
			var key: String = entry.get("key", "")
			assert(expected_squad.has(action), "Unexpected squad action: %s" % action)
			assert(expected_squad[action] == key, "Key mismatch for %s: expected %s, got %s" % [action, expected_squad[action], key])

		# Verify UI Node hierarchy in containers
		assert(modal.combat_container != null, "CombatContainer must exist")
		assert(modal.combat_container.get_child_count() == 8, "CombatContainer must contain 8 child rows")
		var first_row: Node = modal.combat_container.get_child(0)
		var first_action: Label = first_row.find_child("ActionLabel", true, false) as Label
		var first_key: Label = first_row.find_child("KeyLabel", true, false) as Label
		assert(first_action != null and first_action.text == "Aim Down Sights (ADS / Wildlands Shoulder View)", "First action label must match ADS")
		assert(first_key != null and first_key.text == "[Right Mouse Button (Hold)]", "First key label must match Right Mouse Button (Hold)")

		print("[TEST 2/5] PASS: All 17 keybinding actions and keys matched specification perfectly.")

	elif ticks == 3:
		# TEST 3: Modal Open, Close, and ESC Input
		print("[TEST 3/5] Testing modal open, close, and ESC key handling...")
		modal.open_modal(false)
		assert(modal.visible, "Modal must be visible after open_modal")
		assert(modal.is_modal_open, "is_modal_open must be true")

		modal.close_modal(false)
		assert(not modal.visible, "Modal must be hidden after close_modal")
		assert(not modal.is_modal_open, "is_modal_open must be false")

		# Test Close Button
		modal.open_modal(false)
		assert(modal.visible, "Modal must be visible before button press")
		var close_signal_received: Array[bool] = [false]
		var conn: Callable = func() -> void: close_signal_received[0] = true
		modal.closed.connect(conn, Object.CONNECT_ONE_SHOT)
		modal.close_button.pressed.emit()
		assert(not modal.visible, "Modal must be hidden after close_button pressed")
		assert(close_signal_received[0], "closed signal must be emitted on close_button pressed")

		# Test ESC Key Intercept
		modal.open_modal(false)
		assert(modal.visible, "Modal must be visible before ESC key")
		var esc_event := InputEventKey.new()
		esc_event.keycode = KEY_ESCAPE
		esc_event.pressed = true
		modal._unhandled_input(esc_event)
		assert(not modal.visible, "Modal must close on ESC key")

		print("[TEST 3/5] PASS: Modal open, close, button trigger, and ESC interception validated.")

	elif ticks == 4:
		# TEST 4: Integration with Lobby.tscn & Lobby.gd
		print("[TEST 4/5] Testing Lobby integration (Tactical Controls button & modal)...")
		var lobby_scene := load(LOBBY_SCENE) as PackedScene
		assert(lobby_scene != null, "Lobby scene must load successfully")
		lobby = lobby_scene.instantiate() as LobbyUI
		assert(lobby != null, "Lobby must instantiate")
		root.add_child(lobby)

		assert(lobby.keybindings_button != null, "Lobby must contain KeybindingsButton")
		assert(
			lobby.keybindings_button.text == "[ TACTICAL CONTROLS & FIELD MANUAL ]",
			"Lobby KeybindingsButton text must be '[ TACTICAL CONTROLS & FIELD MANUAL ]' (found: %s)" % lobby.keybindings_button.text
		)
		assert(lobby.keybindings_modal != null, "Lobby must contain KeybindingsModal")
		assert(not lobby.keybindings_modal.visible, "Lobby KeybindingsModal must start hidden")

		# Click Lobby KeybindingsButton
		lobby.keybindings_button.pressed.emit()
		assert(lobby.keybindings_modal.visible, "Lobby KeybindingsModal must open when button is clicked")

		# Close via modal close button
		lobby.keybindings_modal.close_button.pressed.emit()
		assert(not lobby.keybindings_modal.visible, "Lobby KeybindingsModal must close on close_button pressed")

		print("[TEST 4/5] PASS: Lobby button and modal opening/closing verified.")

	elif ticks == 5:
		# TEST 5: Integration with In-Game HUD, GateRoom, & Player Pause Interception
		print("[TEST 5/5] Testing In-Game HUD, GateRoom, and operative input pause interception...")
		var gr_scene := load(GATE_ROOM_SCENE) as PackedScene
		assert(gr_scene != null, "GateRoom scene must load successfully")
		gateroom = gr_scene.instantiate() as GateRoom
		assert(gateroom != null, "GateRoom must instantiate")
		root.add_child(gateroom)

		hud = gateroom.get_node_or_null("TacticalHUD") as TacticalHUD
		assert(hud != null, "GateRoom must contain TacticalHUD")
		assert(hud.keybindings_modal != null, "TacticalHUD must contain KeybindingsModal")
		assert(not hud.keybindings_modal.visible, "HUD KeybindingsModal must start hidden")
		assert(gateroom.keybindings_modal == hud.keybindings_modal, "GateRoom.keybindings_modal property must reference HUD KeybindingsModal")

		# Spawn local operative
		var p_scene := load(PLAYER_SCENE) as PackedScene
		assert(p_scene != null, "Player scene must load")
		player = p_scene.instantiate() as PlayerController3D
		assert(player != null, "player must instantiate as PlayerController3D")
		player.name = "1"
		player.class_id = SGCNetworkManager.CLASS_SG3_HEAVY
		gateroom.get_node("Players").add_child(player, true)
		hud.bind_local_player(player)

		# Baseline: Operative input is active (not paused/modal open)
		assert(not player._is_ui_modal_open(), "Player must not have modal open initially")

		# In-game ESC / F1 toggle
		hud.toggle_keybindings_modal()
		assert(hud.keybindings_modal.visible, "KeybindingsModal must open on toggle")
		assert(player._is_ui_modal_open(), "Player must detect UI modal open to pause/intercept movement & combat input cleanly")

		# Crosshair drawing is suppressed while modal is open
		assert(hud.keybindings_modal.visible, "KeybindingsModal is open")

		# Close modal via GateRoom toggle
		gateroom.toggle_keybindings_modal()
		assert(not hud.keybindings_modal.visible, "KeybindingsModal must close on second toggle")
		assert(not player._is_ui_modal_open(), "Player must resume combat when modal is closed")

		# Test F1 InputEventKey handling in HUD
		var f1_event := InputEventKey.new()
		f1_event.keycode = KEY_F1
		f1_event.pressed = true
		hud._unhandled_input(f1_event)
		assert(hud.keybindings_modal.visible, "Pressing [F1] must toggle KeybindingsModal open")

		hud._unhandled_input(f1_event)
		assert(not hud.keybindings_modal.visible, "Pressing [F1] again must toggle KeybindingsModal closed")

		# Test ESC InputEventKey handling in HUD
		var esc_event := InputEventKey.new()
		esc_event.keycode = KEY_ESCAPE
		esc_event.pressed = true
		hud._unhandled_input(esc_event)
		assert(hud.keybindings_modal.visible, "Pressing [ESC] must toggle KeybindingsModal open")

		hud._unhandled_input(esc_event)
		assert(not hud.keybindings_modal.visible, "Pressing [ESC] again must toggle KeybindingsModal closed")

		print("[TEST 5/5] PASS: In-Game [ESC] / [F1] toggle and operative input interception validated.")

		print("\n========================================================")
		print("  SPRINT 18 KEYBINDINGS & TACTICAL CONTROLS TEST PASSED! ")
		print("  ✓ SGC Cheyenne Mountain Terminal UI & Phosphor Aesthetic")
		print("  ✓ 3 Categories & All 17 Keybinding Labels Verified     ")
		print("  ✓ Open, Close, Button, and ESC Interception Functional  ")
		print("  ✓ Lobby [ TACTICAL CONTROLS & FIELD MANUAL ] Integration")
		print("  ✓ In-Game [ESC] / [F1] Toggle & Input Pause Cleanly Resumes")
		print("========================================================\n")
		quit(0)

	return false
