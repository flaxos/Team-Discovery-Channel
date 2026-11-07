class_name LobbyUI
extends Control
## SGC Mission Briefing Terminal & Netcode Lobby UI.
## Handles Host/Join actions, operative class selection, and squad roster updates.

@onready var player_name_edit: LineEdit = %PlayerNameEdit
@onready var class_option_button: OptionButton = %ClassOptionButton
@onready var class_desc_label: Label = %ClassDescLabel
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var ip_address_edit: LineEdit = %IpAddressEdit
@onready var start_game_button: Button = %StartGameButton
@onready var status_label: Label = %StatusLabel
@onready var roster_list: ItemList = %RosterList


func _ready() -> void:
	_setup_class_options()
	_connect_network_signals()
	_update_ui_state()

	# Button handlers
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	class_option_button.item_selected.connect(_on_class_selected)
	player_name_edit.text_changed.connect(_on_name_changed)


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
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net == null:
		return

	net.server_started.connect(func() -> void:
		status_label.text = "SGC Command Base active on port %d. Waiting for squad..." % SGCNetworkManager.DEFAULT_PORT
		_update_ui_state()
	)
	net.connection_succeeded.connect(func() -> void:
		status_label.text = "Connected to SGC Command Base. Awaiting mission dispatch..."
		_update_ui_state()
	)
	net.connection_failed.connect(func() -> void:
		status_label.text = "Connection failed. Check target IP and firewall."
		_update_ui_state()
	)
	net.server_disconnected.connect(func() -> void:
		status_label.text = "Disconnected from command base."
		_update_ui_state()
	)
	net.player_list_updated.connect(_refresh_roster)


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
