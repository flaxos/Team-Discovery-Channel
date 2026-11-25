extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var scene := preload("res://scenes/main/Lobby.tscn")
	var player_scene := preload("res://scenes/entities/Player.tscn")
	var saved_class := SGCNetworkManager.CLASS_TEALC_JAFFA
	net.selected_class_id = saved_class
	var lobby := scene.instantiate() as LobbyUI
	root.add_child(lobby)
	var picker := lobby.class_option_button
	assert(picker.get_selected_metadata() == saved_class)
	assert(lobby.class_desc_label.text.contains("Ma'Tok Staff Weapon"), "The initial card describes the retained class")
	assert(picker.item_count == SGCNetworkManager.CLASS_PROFILES.size())

	for index in range(picker.item_count):
		picker.select(index)
		picker.item_selected.emit(index)
		var player := player_scene.instantiate() as PlayerController3D
		player.class_id = net.selected_class_id
		assert(player.class_id == picker.get_selected_metadata())
		root.add_child(player)
		player.set_physics_process(false)
		var details := lobby.class_desc_label.text
		assert(details.contains("Primary  " + player.current_weapon.display_name))
		player.switch_slot(2)
		assert(details.contains("Sidearm  " + player.current_weapon.display_name))
		assert(details.contains("%.0f HP  ·  %.1f m/s base speed" % [player.health_component.max_health, player.base_speed]))
		assert(details.contains("%d claymores, %d smoke grenades, %d deployable shield" % [
			player.claymore_charges, player.smoke_grenades_count, player.deployable_shields_count,
		]))
		player.free()

	var last_class := net.selected_class_id
	lobby.free()
	lobby = scene.instantiate() as LobbyUI
	root.add_child(lobby)
	assert(lobby.class_option_button.get_selected_metadata() == last_class)
	lobby.free()
	print("PASS four lobby loadout cards match starting operatives and restore the selection")
	await preload("res://tests/support/finish.gd").success(self)
