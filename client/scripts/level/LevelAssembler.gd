@tool
class_name LevelAssembler
extends RefCounted


static func snap(
	layout: LevelLayout,
	moving_id: StringName,
	moving_socket: StringName,
	target_id: StringName,
	target_socket: StringName
) -> PackedStringArray:
	var moving := layout.instance(moving_id)
	var target := layout.instance(target_id)
	if moving == null or target == null or moving == target:
		return PackedStringArray(["Snap requires distinct existing instance IDs"])
	if moving.module == null or target.module == null:
		return PackedStringArray(["Snap requires module definitions"])
	var a := moving.module.socket(moving_socket)
	var b := target.module.socket(target_socket)
	if a == null or b == null:
		return PackedStringArray(
			[
				(
					"Unknown socket: %s/%s -> %s/%s"
					% [moving_id, moving_socket, target_id, target_socket]
				)
			]
		)
	if a.family != b.family or absf(a.width - b.width) > 0.001 or absf(a.height - b.height) > 0.001:
		return PackedStringArray(
			[
				(
					"Incompatible sockets: %s/%s -> %s/%s"
					% [moving_id, moving_socket, target_id, target_socket]
				)
			]
		)
	if not layout.decks.has(str(target.deck)) or moving.deck != target.deck:
		return PackedStringArray(["Socket decks must match"])
	var target_world := target.placement(float(layout.decks[str(target.deck)])) * b.local_transform
	var wanted := (
		target_world
		* Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		* a.local_transform.affine_inverse()
	)
	var angle := roundi(wanted.basis.get_euler().y / (PI / 2))
	var old_position := moving.position
	var old_turn := moving.quarter_turn
	moving.position = Vector2(wanted.origin.x, wanted.origin.z)
	moving.quarter_turn = posmod(angle, 4)
	var edge := LevelModuleConnection.new()
	edge.from_instance = target_id
	edge.from_socket = target_socket
	edge.to_instance = moving_id
	edge.to_socket = moving_socket
	layout.connections.append(edge)
	var errors := LevelLayoutValidator.validate(layout, false)
	if not errors.is_empty():
		layout.connections.pop_back()
		moving.position = old_position
		moving.quarter_turn = old_turn
	return errors


static func assemble(layout: LevelLayout, parent: Node3D) -> void:
	for item in layout.instances:
		var node := item.module.scene.instantiate() as LevelModule
		node.name = str(item.id)
		node.instance_id = item.id
		node.definition = item.module
		node.deck = item.deck
		node.available_sockets = item.available_sockets.duplicate()
		node.transform = item.placement(float(layout.decks[str(item.deck)]))
		parent.add_child(node)
		node.owner = parent.owner if parent.owner != null else parent
	for c in layout.connections:
		(parent.get_node(str(c.from_instance)) as LevelModule).set_portal(c.from_socket, true)
		(parent.get_node(str(c.to_instance)) as LevelModule).set_portal(c.to_socket, true)

	add_doors(layout, parent)


static func connect_touching(layout: LevelLayout) -> PackedStringArray:
	var errors := LevelLayoutValidator.validate(layout, false)
	if not errors.is_empty():
		return errors
	var used: Dictionary = {}
	for edge in layout.connections:
		if edge.state == "open":
			edge.state = "door"
		used[str(edge.from_instance) + "/" + str(edge.from_socket)] = true
		used[str(edge.to_instance) + "/" + str(edge.to_socket)] = true
	for i in range(layout.instances.size()):
		var a := layout.instances[i]
		for j in range(i + 1, layout.instances.size()):
			var b := layout.instances[j]
			if a.deck != b.deck:
				continue
			for sa in a.module.sockets:
				for sb in b.module.sockets:
					var ka := str(a.id) + "/" + str(sa.id)
					var kb := str(b.id) + "/" + str(sb.id)
					if used.has(ka) or used.has(kb) or not a.allows(sa.id) or not b.allows(sb.id):
						continue
					if (
						sa.family != sb.family
						or absf(sa.width - sb.width) > 0.001
						or absf(sa.height - sb.height) > 0.001
					):
						continue
					var ta := a.placement(float(layout.decks[str(a.deck)])) * sa.local_transform
					var tb := b.placement(float(layout.decks[str(b.deck)])) * sb.local_transform
					if (
						ta.origin.distance_to(tb.origin) > 0.001
						or ta.basis.z.dot(tb.basis.z) > -0.999
					):
						continue
					var edge := LevelModuleConnection.new()
					edge.from_instance = a.id
					edge.from_socket = sa.id
					edge.to_instance = b.id
					edge.to_socket = sb.id
					edge.state = "door"
					layout.connections.append(edge)
					used[ka] = true
					used[kb] = true
	return PackedStringArray()


static func add_doors(layout: LevelLayout, parent: Node3D) -> void:
	for index in range(layout.connections.size()):
		var edge := layout.connections[index]
		if edge.state != "door":
			continue
		var name := "Door_%03d" % index
		if parent.has_node(name):
			continue
		var item := layout.instance(edge.from_instance)
		var socket := item.module.socket(edge.from_socket)
		var door := load("res://scenes/level/ModularDoor.tscn").instantiate() as Node3D
		door.name = name
		door.transform = (
			item.placement(float(layout.decks[str(item.deck)])) * socket.local_transform
		)
		door.set("width", socket.width)
		door.set("height", socket.height)
		parent.add_child(door)
		door.owner = parent.owner if parent.owner != null else parent
