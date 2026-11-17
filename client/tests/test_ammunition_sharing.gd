extends "res://tests/test_mission_countdown_multiplayer.gd"
## Real operatives/weapons in the native compound: reserve conservation and action guards.


func give(donor: PlayerController3D, receiver: PlayerController3D) -> void:
	donor._next_ammo_share_ms = 0
	donor._ammo_share_sequence += 1
	donor.server_request_ammo_share(donor._ammo_share_sequence, donor.ammo_share_incarnation, str(receiver.name), receiver.ammo_share_incarnation, donor.current_weapon.weapon_id, receiver.current_weapon.weapon_id)


func blocked(donor: PlayerController3D, receiver: PlayerController3D) -> void:
	var before := [donor.current_weapon.reserve_ammo, receiver.current_weapon.reserve_ammo]
	give(donor, receiver)
	require(before == [donor.current_weapon.reserve_ammo, receiver.current_weapon.reserve_ammo], "Rejected transfer must leave both reserves intact")


func run() -> void:
	output_dir = ProjectSettings.globalize_path("res://../build/test-results/ammunition-unit")
	DirAccess.make_dir_recursive_absolute(output_dir)
	net = root.get_node("NetworkManager") as SGCNetworkManager
	main = load("res://scenes/main/Main.tscn").instantiate() as MainGameCoordinator
	root.add_child(main)
	require(net.host_game(0) == OK)
	require(net.set_mission(SGCNetworkManager.MISSION_GOAULD_INFILTRATION))
	net.request_start_game()
	var room := await mission()
	var donor := room.players_container.get_node("1") as PlayerController3D
	# A private open test pad above the compound avoids authored geometry assumptions.
	donor.global_position = Vector3(0, 50, 0)
	room._spawn_player(77, SGCNetworkManager.CLASS_CARTER_TECH, donor.global_position + Vector3(0, 0, -2))
	var receiver := room.players_container.get_node("77") as PlayerController3D
	receiver.set_physics_process(false)
	donor.switch_slot(2)
	receiver.switch_slot(1)
	var dw := donor.current_weapon
	var rw := receiver.current_weapon
	rw.reserve_ammo = 110
	var total := dw.reserve_ammo + rw.reserve_ammo
	var magazines := [dw.current_ammo, rw.current_ammo]
	await physics_frame
	require(donor.ammo_share_offer(receiver).amount == 30, "M9 can feed a compatible MP5 magazine")
	var atomic: Array[bool] = []
	dw.ammo_changed.connect(func(_mag: int, _reserve: int) -> void: atomic.append(dw.reserve_ammo + rw.reserve_ammo == total))
	give(donor, receiver)
	require(dw.reserve_ammo == 30 and rw.reserve_ammo == 140 and atomic == [true])
	# Repeated press is rate limited, and replay is rejected even after cooldown.
	donor.request_ammo_share(receiver)
	require(rw.reserve_ammo == 140)
	donor._next_ammo_share_ms = 0
	donor.server_request_ammo_share(donor._last_ammo_share_sequence, donor.ammo_share_incarnation, "77", receiver.ammo_share_incarnation, "m9", "mp5")
	require(rw.reserve_ammo == 140)
	give(donor, receiver)
	require(dw.reserve_ammo == 20 and rw.reserve_ammo == 150, "Capacity clamps the last transfer")
	require([dw.current_ammo, rw.current_ammo] == magazines)
	blocked(donor, receiver)
	rw.reserve_ammo = 160
	blocked(donor, receiver)
	rw.reserve_ammo = 100
	dw.reserve_ammo = 3
	give(donor, receiver)
	require(dw.reserve_ammo == 0 and rw.reserve_ammo == 103, "Last donor rounds are conserved")
	blocked(donor, receiver)
	dw.reserve_ammo = 60
	for actor: PlayerController3D in [donor, receiver]:
		for state_name: String in ["is_downed", "is_dead", "is_stunned", "frozen"]:
			actor.health_component.set(state_name, true)
			blocked(donor, receiver)
			actor.health_component.set(state_name, false)
		actor.current_weapon.is_reloading = true
		blocked(donor, receiver)
		actor.current_weapon.is_reloading = false
	receiver.global_position.z -= 2
	blocked(donor, receiver)
	receiver.global_position.z += 2
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	room.add_child(wall)
	wall.global_position = donor.global_position + Vector3(0, 1, -1)
	await physics_frame
	await physics_frame
	blocked(donor, receiver)
	wall.collision_layer = 128
	await physics_frame
	await physics_frame
	blocked(donor, receiver)
	wall.free()
	await physics_frame
	donor.switch_slot(1)
	blocked(donor, receiver)
	receiver._equip_weapon_by_id("staff_weapon")
	blocked(donor, receiver)
	receiver._equip_weapon_by_id("mp5")
	donor.switch_slot(2)
	var before := [dw.reserve_ammo, rw.reserve_ammo]
	donor._ammo_share_sequence += 1
	donor.server_request_ammo_share(donor._ammo_share_sequence, "retired", "77", receiver.ammo_share_incarnation, "m9", "mp5")
	donor.server_request_ammo_share(donor._ammo_share_sequence, donor.ammo_share_incarnation, "77", "retired", "m9", "mp5")
	donor._ammo_share_sequence += 1
	donor.server_request_ammo_share(donor._ammo_share_sequence, donor.ammo_share_incarnation, "../77", receiver.ammo_share_incarnation, "m9", "mp5")
	donor._ammo_share_sequence += 1
	donor.server_request_ammo_share(donor._ammo_share_sequence, donor.ammo_share_incarnation, "77", receiver.ammo_share_incarnation, "mp5", "mp5")
	require(before == [dw.reserve_ammo, rw.reserve_ammo])
	require(not donor._combat_peer_allowed(77))
	# Camera target selection and actual default/remapped input use the normal controller.
	donor.camera.global_position = donor.global_position + Vector3(0, 1.4, 1)
	donor.camera.look_at(receiver.global_position + Vector3.UP)
	require(donor.aimed_ammo_recipient() == receiver)
	require(donor.ammo_share_prompt().contains("[B] GIVE 30"))
	var bindings := root.get_node("KeybindingManager")
	var remapped: Array[InputEvent] = [bindings.key_event(KEY_J)]
	bindings.set_events("share_ammo", remapped)
	require(donor.ammo_share_prompt().contains("[J]"))
	donor._next_ammo_share_ms = 0
	var press := InputEventKey.new()
	press.physical_keycode = KEY_J
	press.pressed = true
	var sequence := donor._ammo_share_sequence
	# Physics is paused before the transfer ack, but key events still dispatch.
	net._paused_actors[123] = {"actor": donor}
	donor._unhandled_input(press)
	require(donor._ammo_share_sequence == sequence and donor.ammo_share_prompt().is_empty(), "Paused owner cannot queue post-ack ammunition intent")
	net._paused_actors.erase(123)
	net._player_pauses[donor.get_instance_id()] = {"owner": 1}
	blocked(donor, receiver)
	net._player_pauses.erase(donor.get_instance_id())
	donor._unhandled_input(press)
	require(dw.reserve_ammo == 30 and rw.reserve_ammo == 133, "The production input path gives ammunition: %d/%d seq=%d/%d" % [dw.reserve_ammo, rw.reserve_ammo, donor._ammo_share_sequence, donor._last_ammo_share_sequence])
	bindings.reset_defaults(false)
	# Existing inventory capture carries finite reserves without refilling during travel.
	var session := MissionSession.new()
	var captured := session.capture_state(donor)
	require(captured.weapons.m9.reserve_ammo == 30, "Capture preserves spent reserve")
	room._spawn_player(88, donor.class_id, donor.global_position + Vector3(6, 0, 0))
	var carried := room.players_container.get_node("88") as PlayerController3D
	carried.set_physics_process(false)
	session.apply_state(carried, captured)
	require(carried.current_weapon.weapon_id == "m9" and carried.current_weapon.reserve_ammo == 30, "A destination operative of the same class receives the carried reserve")
	carried.queue_free()
	room.session = session
	session._traveling[donor.peer_id] = true
	blocked(donor, receiver)
	session._traveling.clear()
	session.result = 0
	blocked(donor, receiver)
	room.session = null
	session.free()
	blocked(donor, donor)
	# Both other finite calibres use their authored capacities, rather than a universal 300.
	for id: String in ["p90", "m249"]:
		donor._equip_weapon_by_id(id)
		receiver._equip_weapon_by_id(id)
		donor.current_weapon.reserve_ammo = 70
		receiver.current_weapon.reserve_ammo = receiver.current_weapon.reserve_capacity - 7
		give(donor, receiver)
		require(donor.current_weapon.reserve_ammo == 63 and receiver.current_weapon.reserve_ammo == receiver.current_weapon.reserve_capacity, "Finite calibre transfer: " + id)
	net.restart_pending = true
	blocked(donor, receiver)
	net.restart_pending = false
	room.mission_result = 0
	blocked(donor, receiver)
	require(donor.ammo_share_prompt().is_empty())
	net.disconnect_game()
	await frames(5)
	print("PASS ammunition sharing conservation, compatibility, capacity, health, reload, reach, wall, replay, input, capture and result guards")
	await preload("res://tests/support/finish.gd").success(self)
