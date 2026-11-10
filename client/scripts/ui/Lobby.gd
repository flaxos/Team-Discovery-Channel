class_name LobbyUI
extends Control
## SGC Mission Briefing Terminal & Netcode Lobby UI.
## Handles Host/Join actions, operative class selection, and squad roster updates.

@onready var mission_option_button: OptionButton = %MissionOptionButton
@onready var mission_description_label: Label = %MissionDescriptionLabel

@onready var player_name_edit: LineEdit = %PlayerNameEdit
@onready var class_option_button: OptionButton = %ClassOptionButton
@onready var class_desc_label: Label = %ClassDescLabel
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var ip_address_edit: LineEdit = %IpAddressEdit
@onready var start_game_button: Button = %StartGameButton
@onready var status_label: Label = %StatusLabel
@onready var roster_list: ItemList = %RosterList
@onready var difficulty_option_button: OptionButton = %DifficultyOptionButton
@onready var difficulty_description_label: Label = %DifficultyDescriptionLabel
@onready var keybindings_button: Button = %KeybindingsButton if has_node("%KeybindingsButton") else null
@onready var keybindings_modal: KeybindingsModal = $KeybindingsModal if has_node("KeybindingsModal") else null


var _network_manager: SGCNetworkManager = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_class_options()
	_setup_difficulty_options()
	_setup_mission_options()
	_connect_network_signals()
	_update_ui_state()

	# Button handlers
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	class_option_button.item_selected.connect(_on_class_selected)
	mission_option_button.item_selected.connect(_on_mission_selected)
	difficulty_option_button.item_selected.connect(_on_difficulty_selected)
	player_name_edit.text_changed.connect(_on_name_changed)
	if keybindings_button != null:
		keybindings_button.pressed.connect(_on_keybindings_pressed)
	if keybindings_modal != null:
		keybindings_modal.visible = false


func _setup_class_options() -> void:
	class_option_button.clear()
	var classes := [
		SGCNetworkManager.CLASS_SG3_HEAVY,
		SGCNetworkManager.CLASS_CARTER_TECH,
		SGCNetworkManager.CLASS_ONEILL_RECON,
		SGCNetworkManager.CLASS_TEALC_JAFFA
	]

	for i in range(classes.size()):
		var c_id: String = classes[i]
		var info: Dictionary = SGCNetworkManager.CLASS_PROFILES[c_id]
		class_option_button.add_item(info["name"], i)
		class_option_button.set_item_metadata(i, c_id)

	class_option_button.selected = 0
	_update_class_description(classes[0])


func _setup_difficulty_options() -> void:
	difficulty_option_button.clear()
	for tier: int in range(SGCNetworkManager.DIFFICULTY_NAMES.size()):
		difficulty_option_button.add_item(SGCNetworkManager.DIFFICULTY_NAMES[tier], tier)
	_sync_difficulty_selection()


func _sync_difficulty_selection() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var tier: int = net.mission_difficulty if net != null else SGCNetworkManager.DIFFICULTY_EASY
	difficulty_option_button.select(tier)
	difficulty_option_button.get_parent().visible = net == null or net.selected_mission_id != SGCNetworkManager.MISSION_SGC_UAT
	difficulty_description_label.text = SGCNetworkManager.DIFFICULTY_DESCRIPTIONS[tier]
	if net != null and net.is_in_active_session() and not net.is_server:
		difficulty_description_label.text += "\nMission mode is selected by the host."


func _on_difficulty_selected(index: int) -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.set_mission_difficulty(difficulty_option_button.get_item_id(index))
	_sync_difficulty_selection()


func _on_mission_settings_changed(_tier: int) -> void:
	_sync_difficulty_selection()
	_update_ui_state()


func _update_class_description(c_id: String) -> void:
	var info: Dictionary = SGCNetworkManager.CLASS_PROFILES.get(c_id, {})
	var primary_name: String = info.get("primary", "").to_upper()
	var secondary_name: String = info.get("secondary", "").to_upper()
	var hp: float = info.get("health", 100.0)
	var spd: float = info.get("speed", 6.0)

	class_desc_label.text = "%s\nPrimary: %s | Sidearm: %s\nArmor HP: %.0f | Speed: %.1f m/s" % [
		info.get("desc", ""),
		primary_name,
		secondary_name,
		hp,
		spd
	]


func _connect_network_signals() -> void:
	_network_manager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if _network_manager == null:
		return
	_network_manager.mission_selection_changed.connect(_on_mission_selection_changed)
	_network_manager.mission_settings_changed.connect(_on_mission_settings_changed)
	_network_manager.server_started.connect(_on_server_started)
	_network_manager.connection_succeeded.connect(_on_connection_succeeded)
	_network_manager.connection_failed.connect(_on_connection_failed)
	_network_manager.server_disconnected.connect(_on_server_disconnected)
	_network_manager.player_list_updated.connect(_refresh_roster)


func _exit_tree() -> void:
	if not is_instance_valid(_network_manager):
		return
	var connections: Array[Dictionary] = [
		{"signal": _network_manager.mission_selection_changed, "callback": _on_mission_selection_changed},
		{"signal": _network_manager.mission_settings_changed, "callback": _on_mission_settings_changed},
		{"signal": _network_manager.server_started, "callback": _on_server_started},
		{"signal": _network_manager.connection_succeeded, "callback": _on_connection_succeeded},
		{"signal": _network_manager.connection_failed, "callback": _on_connection_failed},
		{"signal": _network_manager.server_disconnected, "callback": _on_server_disconnected},
		{"signal": _network_manager.player_list_updated, "callback": _refresh_roster}
	]
	for connection: Dictionary in connections:
		var source: Signal = connection.signal
		var callback: Callable = connection.callback
		if source.is_connected(callback):
			source.disconnect(callback)
	_network_manager = null


func _on_server_started() -> void:
	status_label.text = "SGC Command Base active on port %d. Waiting for squad..." % _network_manager.server_port
	_update_ui_state()


func _on_connection_succeeded() -> void:
	status_label.text = "Connected to SGC Command Base. Awaiting mission dispatch..."
	_update_ui_state()


func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Check target IP and firewall."
	_update_ui_state()


func _on_server_disconnected() -> void:
	status_label.text = "Disconnected from command base."
	_update_ui_state()


func _on_host_pressed() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net == null:
		return
	net.player_name = player_name_edit.text.strip_edges()
	if net.player_name.is_empty():
		net.player_name = "O'Neill"
	net.host_game()
	_refresh_roster()


func _on_join_pressed() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net == null:
		return
	var ip := ip_address_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	net.player_name = player_name_edit.text.strip_edges()
	if net.player_name.is_empty():
		net.player_name = "Scotty"
	status_label.text = "Establishing sub-space link to %s..." % ip
	net.join_game(ip)


func _on_class_selected(index: int) -> void:
	var c_id: String = class_option_button.get_item_metadata(index) as String
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.selected_class_id = c_id
	_update_class_description(c_id)


func _on_name_changed(new_name: String) -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null:
		net.player_name = new_name


func _on_start_game_pressed() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and net.is_server:
		net.request_start_game()


func open_keybindings() -> void:
	if keybindings_modal != null:
		keybindings_modal.open_modal()


func _on_keybindings_pressed() -> void:
	open_keybindings()


func _refresh_roster() -> void:
	roster_list.clear()
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net == null:
		return

	for peer_id: int in net.peers:
		var p_info: Dictionary = net.peers[peer_id]
		var c_name: String = SGCNetworkManager.CLASS_PROFILES.get(p_info.get("class_id", ""), {}).get("name", "Operative")
		var entry := "Operative %s [ID %d] - %s" % [p_info.get("name", "Soldier"), peer_id, c_name]
		if peer_id == 1:
			entry += " (Host / Commander)"
		roster_list.add_item(entry)

	_update_ui_state()


func _update_ui_state() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var is_connected: bool = (net != null and net.is_in_active_session())
	var is_server: bool = (net != null and net.is_server)

	host_button.disabled = is_connected
	join_button.disabled = is_connected
	start_game_button.visible = is_server
	start_game_button.disabled = not is_server
	mission_option_button.disabled = (is_connected and not is_server) or (net != null and net.mission_started)
	difficulty_option_button.disabled = (is_connected and not is_server) or (net != null and (net.mission_started or net.selected_mission_id != SGCNetworkManager.MISSION_SGC_DEFENSE))
	_sync_mission_selection()
	_sync_difficulty_selection()


func _setup_mission_options() -> void:
	mission_option_button.clear()
	for mission_id: String in SGCNetworkManager.MISSIONS:
		mission_option_button.add_item(SGCNetworkManager.MISSIONS[mission_id]["name"])
		mission_option_button.set_item_metadata(mission_option_button.item_count - 1, mission_id)
	_sync_mission_selection()

func _sync_mission_selection() -> void:
	var net := get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var mission_id := net.selected_mission_id if net != null else SGCNetworkManager.MISSION_SGC_DEFENSE
	for i in range(mission_option_button.item_count):
		if mission_option_button.get_item_metadata(i) == mission_id: mission_option_button.select(i)
	mission_description_label.text = SGCNetworkManager.MISSIONS[mission_id]["description"]
	start_game_button.text = {SGCNetworkManager.MISSION_SGC_UAT: "LAUNCH UAT BASE", SGCNetworkManager.MISSION_MODULAR_EXTRACTION: "LAUNCH EXTRACTION UAT"}.get(mission_id, "LAUNCH SGC DEFENSE")

func _on_mission_selected(index: int) -> void:
	if _network_manager != null: _network_manager.set_mission(str(mission_option_button.get_item_metadata(index)))
	_update_ui_state()

func _on_mission_selection_changed(_mission_id: String) -> void:
	_update_ui_state()
