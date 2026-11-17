extends SceneTree
## Controlled native-compound HUD evidence using production aiming, input and transfers.
const Fixture = preload("res://tests/support/mission_events_fixture.gd")
var output: String
var donor: PlayerController3D
var receiver: PlayerController3D


func _init() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in range(10):
		await physics_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)


func aim() -> void:
	donor.camera.global_position = donor.global_position + Vector3(0, 3.5, 5)
	donor.camera.look_at(receiver.global_position + Vector3.UP)
	donor.camera.current = true
	donor._process_aim()


func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/ammunition-sharing-review")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 1000)
	var net := root.get_node("NetworkManager") as SGCNetworkManager
	var main := load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	assert(net.host_game(0) == OK)
	assert(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room: ModularMission
	for i in range(1800):
		await physics_frame
		room = main.current_gate_room as ModularMission
		if room != null and room.is_started:
			break
	assert(room != null and room.is_started)
	Fixture.stand_down(room)
	donor = room.players_container.get_node("1") as PlayerController3D
	donor.set_physics_process(false)
	donor.health_component.current_health = donor.health_component.max_health
	donor.global_position = Vector3(-0.6, 0.05, -0.8)
	room._spawn_player(77, SGCNetworkManager.CLASS_CARTER_TECH, donor.global_position + Vector3(1.2, 0, 0))
	receiver = room.players_container.get_node("77") as PlayerController3D
	receiver.set_physics_process(false)
	receiver.player_callsign = "CARTER"
	receiver.nameplate.set_callsign("CARTER", "TECH SPECIALIST & ARCHAEOLOGIST")
	donor.switch_slot(2)
	receiver.current_weapon.reserve_ammo = 110
	aim()
	await shot("1-default")
	assert(donor.ammo_share_prompt().contains("[B] GIVE 30"))
	var bindings := root.get_node("KeybindingManager")
	var remapped: Array[InputEvent] = [bindings.key_event(KEY_J)]
	bindings.set_events("share_ammo", remapped)
	await shot("2-remapped")
	assert(donor.ammo_share_prompt().contains("[J] GIVE 30"))
	var press: InputEventKey = bindings.key_event(KEY_J)
	press.pressed = true
	donor._unhandled_input(press)
	assert(donor.current_weapon.reserve_ammo == 30 and receiver.current_weapon.reserve_ammo == 140)
	await shot("3-given")
	donor._next_ammo_share_ms = 0
	donor._unhandled_input(press)
	assert(donor.current_weapon.reserve_ammo == 20 and receiver.current_weapon.reserve_ammo == 150)
	await shot("4-full")
	donor.switch_slot(1)
	await shot("5-incompatible")
	bindings.reset_defaults(false)
	net.disconnect_game()
	for i in range(5):
		await process_frame
	print("PASS ammunition sharing HUD captures")
	await preload("res://tests/support/finish.gd").success(self)
