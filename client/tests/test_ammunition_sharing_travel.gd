extends "res://tests/test_mission_countdown_multiplayer.gd"
## Real two-world gate handoff carries spent/shared reserves and retires request incarnations.


func run() -> void:
	output_dir = ProjectSettings.globalize_path("res://../build/test-results/ammunition-travel")
	DirAccess.make_dir_recursive_absolute(output_dir)
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	require(net.host_game(0) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_TRAVEL_INFILTRATION))
	net.request_start_game()
	await worlds()
	var home := main.current_gate_room as GateRoom
	var site := main.current_site as ModularMission
	var donor := home.players_container.get_node("1") as PlayerController3D
	donor.global_position = Vector3(0, 50, 0)
	donor.switch_slot(2)
	home._spawn_player(77, SGCNetworkManager.CLASS_CARTER_TECH, Vector3(0, 50, -2))
	var receiver := home.players_container.get_node("77") as PlayerController3D
	receiver.set_physics_process(false)
	receiver.current_weapon.reserve_ammo = 0
	await physics_frame
	donor.request_ammo_share(receiver)
	require(donor.current_weapon.reserve_ammo == 30 and receiver.current_weapon.reserve_ammo == 30, "Give before actual gate travel")
	receiver.server_request_ammo_share(1, receiver.ammo_share_incarnation, "1", donor.ammo_share_incarnation, "mp5", "m9")
	require(donor.current_weapon.reserve_ammo == 45 and receiver.current_weapon.reserve_ammo == 15, "Receive before actual gate travel")
	var old_incarnation := donor.ammo_share_incarnation
	await travel(1)
	donor = site.players_container.get_node("1") as PlayerController3D
	donor.set_physics_process(false)
	require(donor.current_weapon.weapon_id == "m9" and donor.current_weapon.reserve_ammo == 45, "Gate handoff carries the donor's spent reserve")
	require(donor.ammo_share_incarnation != old_incarnation)
	require(donor.ammo_share_offer(receiver).amount == 0, "Split-world operatives cannot exchange ammunition")
	donor.server_request_ammo_share(999, donor.ammo_share_incarnation, "77", receiver.ammo_share_incarnation, "m9", "mp5")
	require(donor.current_weapon.reserve_ammo == 45 and receiver.current_weapon.reserve_ammo == 15)
	site._spawn_player(88, SGCNetworkManager.CLASS_CARTER_TECH, Vector3(2000, 50, -2))
	receiver = site.players_container.get_node("88") as PlayerController3D
	receiver.set_physics_process(false)
	receiver.current_weapon.reserve_ammo = 100
	donor.global_position = Vector3(2000, 50, 0)
	receiver.global_position = Vector3(2000, 50, -2)
	await physics_frame
	donor.server_request_ammo_share(1000, old_incarnation, "88", receiver.ammo_share_incarnation, "m9", "mp5")
	require(donor.current_weapon.reserve_ammo == 45 and receiver.current_weapon.reserve_ammo == 100, "Retired gate-travel requests cannot spend destination ammunition")
	# The prior nonexistent-target intent was consumed, so continue this donor's sequence.
	donor._ammo_share_sequence = 999
	donor.request_ammo_share(receiver)
	require(donor.current_weapon.reserve_ammo == 15 and receiver.current_weapon.reserve_ammo == 130, "Sharing resumes in the same destination world with conserved rounds")
	net.disconnect_game()
	await frames(5)
	print("PASS ammunition sharing real gate travel, carried reserves, split-world rejection and retired incarnation")
	await preload("res://tests/support/finish.gd").success(self)
