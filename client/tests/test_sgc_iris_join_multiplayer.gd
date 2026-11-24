extends "res://tests/test_four_player_join_multiplayer.gd"
## The replacement client's first snapshot must show a secured inbound iris.

func port() -> int:
	return 19972 if is_dedicated else 19971


func client_script() -> String:
	return "res://tests/test_sgc_iris_join_multiplayer.gd"


func replacement_slot() -> int:
	return 5 if is_dedicated else 4


func travel(id: int) -> void:
	await super.travel(id)
	var loading := "loading_%d_1" % replacement_slot()
	if not exists(loading) or exists("load_%d_1" % replacement_slot()):
		return
	var home := main.current_gate_room as GateRoom
	var gate := home.stargate_mesh
	gate.close_wormhole()
	require(gate.reserve_connection(true))
	for i in range(1, 8):
		gate.lock_chevron(i)
	var deadline := Time.get_ticks_msec() + 15000
	while gate.current_state != StargateRing.GateState.ACTIVE and Time.get_ticks_msec() < deadline:
		await frames(1)
	require(gate.current_state == StargateRing.GateState.ACTIVE)
	var servo := home.get_node("IrisServoHousing") as IrisServoHousing
	var actor := home.players_container.get_node(str(ids[1])) as PlayerController3D
	servo.start_repair(actor)
	for i in range(3):
		servo.update_repair(2.6)
	await frames(2)
	require(iris_matches(true), "Host presents secured iris before replacement loads")


func iris_matches(secured: bool) -> bool:
	var home := main.current_gate_room as GateRoom
	var gate := home.stargate_mesh
	var iris := gate.get_node("SGCGateTrim/IrisFace") as MeshInstance3D
	var servo := home.get_node("IrisServoHousing") as IrisServoHousing
	if not secured:
		return not iris.visible and not servo.is_repaired
	return iris.visible and servo.is_repaired and servo.completed_stages == 3 \
		and servo.prompt_label.text.begins_with("IRIS SECURED") \
		and gate.direction == StargateRing.GateDirection.INBOUND and gate.event_horizon_mesh.visible


func snapshot(label: String, active_slots: Array[int], expected_count: int = 4) -> void:
	await super.snapshot(label, active_slots, expected_count)
	if label in ["rejoined", "second_retry"]:
		require(iris_matches(label == "rejoined"), "Host iris matches the current checkpoint")
		for index in active_slots:
			require(await marked("iris_%s_%d" % [label, index]))
		print("SGC_IRIS_JOIN: %s confirmed by host and %d peers" % [label, active_slots.size()])


func see_snapshot(label: String) -> void:
	await super.see_snapshot(label)
	if label not in ["rejoined", "second_retry"]:
		return
	var secured := label == "rejoined"
	var deadline := Time.get_ticks_msec() + 15000
	while not iris_matches(secured) and Time.get_ticks_msec() < deadline:
		await frames(1)
	if not iris_matches(secured):
		require(false, "Iris or repair readout missing at " + label)
		return
	mark("iris_%s_%d" % [label, slot])
