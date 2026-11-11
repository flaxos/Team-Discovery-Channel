class_name LevelAuthoring
extends RefCounted
const Model = preload("res://addons/modular_editor/model.gd")
const FIELDS: Dictionary = {
	"place":
	[
		"op",
		"id",
		"module_id",
		"deck",
		"at",
		"turn",
		"preset_id",
		"attach",
		"socket_decks",
		"auto_connect"
	],
	"move": ["op", "id", "at", "turn", "auto_connect"],
	"connect":
	["op", "from", "from_socket", "to", "to_socket", "type", "security_id", "initially_locked"],
	"connection":
	["op", "from", "from_socket", "to", "to_socket", "type", "security_id", "initially_locked"],
	"snap": ["op", "moving_instance", "moving_socket", "target_instance", "target_socket", "type"],
	"connect_touching": ["op"],
	"configure": ["op", "id", "preset_id"],
	"attachment": ["op", "id", "attachment_id", "at", "yaw", "disabled", "reset"],
	"theme": ["op", "scope", "id", "zone_id", "theme_id", "instances", "inherit"],
	"deck": ["op", "id", "elevation", "elevations"],
	"bind_socket": ["op", "id", "socket", "deck"],
	"endpoint": ["op", "kind", "id", "marker"],
	"composite": ["op", "composite_id", "prefix", "at", "turn", "deck_map", "attach"],
	"disconnect": ["op", "from", "from_socket", "to", "to_socket"],
	"remove": ["op", "id", "remove_links"],
	"transport":
	["op", "id", "endpoint_id", "target_id", "kind", "anchor", "node_path", "target_instance"]
}


static func issue(
	code: String,
	reason: String,
	ids: Array = [],
	sockets: Array = [],
	remedy: String = "Inspect catalogue --detail and correct the referenced resource or operation."
) -> Dictionary:
	return {
		"code": code, "reason": reason, "instance_ids": ids, "socket_ids": sockets, "remedy": remedy
	}


static func messages(errors: PackedStringArray, layout: LevelLayout = null) -> Array:
	var result: Array = []
	for message: String in errors:
		var ids: Array = []
		var sockets: Array = []
		if layout != null:
			for item in layout.instances:
				if item == null:
					continue
				var id := str(item.id)
				var padded := " " + message + " "
				if (
					padded.contains(" " + id + "/")
					or padded.contains(" " + id + " ")
					or padded.contains(": " + id + "/")
				):
					ids.append(id)
				if item.module == null:
					continue
				for socket in item.module.sockets:
					if message.contains(id + "/" + str(socket.id)):
						sockets.append({"instance_id": id, "socket_id": str(socket.id)})
		var remedy := "Correct the listed IDs/clearances, then run validate again."
		if "socket" in message.to_lower() or "connection" in message.to_lower():
			remedy = "Use named sockets with matching families/dimensions; use snap or a width adapter, and preserve existing links."
		if "Disconnected" in message:
			remedy = "Add explicit socket connections to each region; connect_touching links only coincident compatible doorways."
		if "theme" in message.to_lower():
			remedy = "Run catalogue --kind theme to discover supported IDs and neutral fallbacks."
		if "deck" in message.to_lower():
			remedy = "Create the matching deck elevation and bind the endpoint; the ramp has a fixed authored rise."
		if "attachment" in message.to_lower() or "preset" in message.to_lower():
			remedy = "Choose a compatible preset and restore its required components, clear bounds and reachable approaches."
		result.append(
			issue(
				message.get_slice(":", 0).to_lower().replace(" ", "_"),
				message,
				ids,
				sockets,
				remedy
			)
		)
	return result


static func vector_ok(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for number: Variant in value:
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	return true


static func identifier(value: String) -> bool:
	return not value.is_empty() and value not in [".", ".."] and value.validate_node_name() == value


static func edge(layout: LevelLayout, data: Dictionary) -> LevelModuleConnection:
	for value in layout.connections:
		if (
			(
				str(value.from_instance) == str(data.get("from", ""))
				and str(value.from_socket) == str(data.get("from_socket", ""))
				and str(value.to_instance) == str(data.get("to", ""))
				and str(value.to_socket) == str(data.get("to_socket", ""))
			)
			or (
				str(value.to_instance) == str(data.get("from", ""))
				and str(value.to_socket) == str(data.get("from_socket", ""))
				and str(value.from_instance) == str(data.get("to", ""))
				and str(value.from_socket) == str(data.get("to_socket", ""))
			)
		):
			return value
	return null


static func transact(source: LevelLayout, request: Dictionary) -> Dictionary:
	var version: Variant = request.get("version", 1)
	if not (version is int or version is float) or version != 1:
		return {
			"ok": false,
			"errors": [issue("unsupported_version", "Authoring request version must be numeric 1")]
		}
	if source != null:
		var previous := LevelLayoutValidator.validate(source, false)
		if not previous.is_empty():
			return {"ok": false, "errors": messages(previous, source)}
	var layout := Model.copy(source) if source != null else LevelLayout.new()
	for key: Variant in request:
		if not str(key) in ["version", "create", "operations"]:
			return {
				"ok": false,
				"errors": [issue("unsupported_field", "Unknown request field: " + str(key))]
			}
	if request.has("create"):
		if source != null:
			return {
				"ok": false,
				"errors":
				[
					issue(
						"create_requires_new",
						"Create cannot replace an input layout; omit --layout to start a new map."
					)
				]
			}
		if not request.create is Dictionary:
			return {"ok": false, "errors": [issue("invalid_create", "create must be an object")]}
		for key: Variant in request.create:
			if not str(key) in ["decks", "theme_id"]:
				return {
					"ok": false,
					"errors": [issue("unsupported_field", "Unknown create field: " + str(key))]
				}
		if request.create.has("decks"):
			if not request.create.decks is Dictionary:
				return {
					"ok": false,
					"errors": [issue("invalid_decks", "decks must map IDs to numeric elevations")]
				}
			layout.decks = request.create.decks.duplicate()
		layout.default_theme = StringName(str(request.create.get("theme_id", "neutral")))
	elif source == null:
		return {
			"ok": false,
			"errors": [issue("missing_layout", "Provide create or an existing --layout resource.")]
		}
	if not request.get("operations", []) is Array:
		return {"ok": false, "errors": [issue("invalid_operations", "operations must be an array")]}
	for index in range(request.get("operations", []).size()):
		var data: Variant = request.operations[index]
		var errors: Array = []
		if not data is Dictionary:
			errors.append(issue("invalid_operation", "Operation must be an object"))
		else:
			errors = operation(layout, data)
		if errors.is_empty():
			errors = messages(LevelLayoutValidator.validate(layout, false), layout)
		if not errors.is_empty():
			for error: Dictionary in errors:
				error["operation_index"] = index
			return {"ok": false, "errors": errors}
	var final := messages(LevelLayoutValidator.validate(layout, false), layout)
	return {
		"ok": final.is_empty(),
		"errors": final,
		"layout": layout,
		"warnings": Array(LevelRoomComposer.warnings(layout))
	}


static func operation(layout: LevelLayout, data: Dictionary) -> Array:
	var op := str(data.get("op", ""))
	if not FIELDS.has(op):
		return [
			issue(
				"unsupported_operation",
				"Unsupported operation: " + op,
				[],
				[],
				"Use --help and the shared authoring guide; do not invent gameplay operations."
			)
		]
	for key: Variant in data:
		if not str(key) in FIELDS[op]:
			return [issue("unsupported_field", "Unsupported %s field: %s" % [op, key])]
	for key: String in [
		"id",
		"module_id",
		"deck",
		"preset_id",
		"from",
		"from_socket",
		"to",
		"to_socket",
		"type",
		"security_id",
		"moving_instance",
		"moving_socket",
		"target_instance",
		"target_socket",
		"attachment_id",
		"scope",
		"zone_id",
		"theme_id",
		"socket",
		"kind",
		"marker",
		"composite_id",
		"prefix",
		"endpoint_id",
		"target_id",
		"anchor",
		"node_path"
	]:
		if data.has(key) and not data[key] is String:
			return [issue("invalid_field_type", key + " must be a string")]
	for key: String in [
		"auto_connect", "initially_locked", "disabled", "reset", "inherit", "remove_links"
	]:
		if data.has(key) and not data[key] is bool:
			return [issue("invalid_field_type", key + " must be a boolean")]
	var id := StringName(str(data.get("id", "")))
	var item := layout.instance(id)
	if (
		op in ["move", "configure", "attachment", "bind_socket", "remove", "transport"]
		and item == null
	):
		return [issue("unknown_instance", "Unknown instance: " + str(id), [str(id)])]
	if op == "place":
		if not identifier(str(id)) or item != null:
			return [
				issue(
					"invalid_instance_id",
					"Instance ID must be unique and node-safe: " + str(id),
					[str(id)]
				)
			]
		var module := LevelCatalogue.module_by_id(StringName(str(data.get("module_id", ""))))
		if module == null:
			return [
				issue(
					"unknown_module",
					"Unknown structural module: " + str(data.get("module_id", "")),
					[str(id)],
					[],
					"Search catalogue --kind module for a supported module ID."
				)
			]
		item = LevelModuleInstance.new()
		item.id = id
		item.module = module
		item.deck = StringName(str(data.get("deck", "deck0")))
		if data.has("socket_decks"):
			if not data.socket_decks is Dictionary:
				return [issue("invalid_binding", "socket_decks must be an object", [str(id)])]
			for key: Variant in data.socket_decks:
				if not data.socket_decks[key] is String:
					return [issue("invalid_binding", "Socket deck IDs must be strings", [str(id)])]
			item.socket_decks = data.socket_decks.duplicate()
		item.bind_matching_decks(layout.decks)
		if data.has("at"):
			if not vector_ok(data.at, 2):
				return [issue("invalid_position", "at must contain two finite numbers", [str(id)])]
			item.position = Vector2(data.at[0], data.at[1])
		elif not data.has("attach") and not layout.instances.is_empty():
			return [
				issue(
					"missing_position",
					"Provide at or attach when placing another instance",
					[str(id)]
				)
			]
		var turn: Variant = data.get("turn", 0)
		if (
			not (turn is int or turn is float)
			or float(turn) != floorf(float(turn))
			or turn < 0
			or turn > 3
		):
			return [issue("invalid_rotation", "turn must be an integer from 0 to 3", [str(id)])]
		item.quarter_turn = int(turn)
		layout.instances.append(item)
		if layout.entry_instance == &"":
			layout.entry_instance = id
		if layout.destination_instance == &"":
			layout.destination_instance = id
		if data.has("preset_id"):
			var configured := configure(item, str(data.preset_id))
			if not configured.is_empty():
				return configured
		if data.has("attach"):
			if not data.attach is Dictionary:
				return [
					issue(
						"invalid_attach",
						"attach must name socket, target and target_socket",
						[str(id)]
					)
				]
			var attach: Dictionary = data.attach
			for key: Variant in attach:
				if not str(key) in ["socket", "target", "target_socket", "type"]:
					return [
						issue("unsupported_field", "Unknown attach field: " + str(key), [str(id)])
					]
			# Either socket may be omitted: the first free pair that fits is used, in
			# declared socket order, so the result is repeatable.
			var target_id := StringName(str(attach.get("target", "")))
			var mine: Array = [str(attach.socket)] if attach.has("socket") else free_sockets(layout, id)
			var theirs: Array = (
				[str(attach.target_socket)]
				if attach.has("target_socket")
				else free_sockets(layout, target_id)
			)
			var errors := PackedStringArray(
				["No free socket pair fits: %s -> %s" % [id, target_id]]
			)
			for a: String in mine:
				for b: String in theirs:
					if not errors.is_empty():
						var tried := LevelAssembler.snap(layout, id, StringName(a), target_id, StringName(b))
						if tried.is_empty() or (mine.size() == 1 and theirs.size() == 1):
							errors = tried
			if not errors.is_empty():
				return messages(errors, layout)
			var connection := layout.connections[-1]
			connection.state = str(
				attach.get(
					"type",
					LevelAssembler.connection_default(
						item.module, layout.instance(connection.from_instance).module
					)
				)
			)
		if bool(data.get("auto_connect", true)):
			return messages(LevelAssembler.connect_touching(layout), layout)
	elif op == "move":
		if not vector_ok(data.get("at"), 2):
			return [issue("invalid_position", "at must contain two finite numbers", [str(id)])]
		item.position = Vector2(data.at[0], data.at[1])
		if data.has("turn"):
			if (
				not (data.turn is int or data.turn is float)
				or float(data.turn) != floorf(float(data.turn))
			):
				return [issue("invalid_rotation", "turn must be an integer", [str(id)])]
			item.quarter_turn = int(data.turn)
		if bool(data.get("auto_connect", true)):
			return messages(LevelAssembler.connect_touching(layout), layout)
	elif op == "configure":
		return configure(item, str(data.get("preset_id", "")))
	elif op == "snap":
		var errors := LevelAssembler.snap(
			layout,
			StringName(str(data.get("moving_instance", ""))),
			StringName(str(data.get("moving_socket", ""))),
			StringName(str(data.get("target_instance", ""))),
			StringName(str(data.get("target_socket", "")))
		)
		if not errors.is_empty():
			return messages(errors, layout)
		var connection := layout.connections[-1]
		connection.state = str(
			data.get(
				"type",
				LevelAssembler.connection_default(
					layout.instance(connection.from_instance).module,
					layout.instance(connection.to_instance).module
				)
			)
		)
	elif op in ["connect", "connection", "disconnect"]:
		var connection := edge(layout, data)
		if op == "disconnect":
			if connection == null:
				return [issue("unknown_connection", "No connection matches the supplied endpoints")]
			layout.connections.erase(connection)
		else:
			if op == "connection" and connection == null:
				return [issue("unknown_connection", "No connection matches the supplied endpoints")]
			if op == "connect":
				if connection != null:
					return [
						issue(
							"existing_connection",
							"Use connection to explicitly change an existing link; connect never overwrites it."
						)
					]
				connection = LevelModuleConnection.new()
				connection.from_instance = StringName(str(data.get("from", "")))
				connection.from_socket = StringName(str(data.get("from_socket", "")))
				connection.to_instance = StringName(str(data.get("to", "")))
				connection.to_socket = StringName(str(data.get("to_socket", "")))
				var a := layout.instance(connection.from_instance)
				var b := layout.instance(connection.to_instance)
				if a == null or b == null:
					return [
						issue(
							"unknown_instance",
							"Connection endpoints must exist",
							[str(connection.from_instance), str(connection.to_instance)]
						)
					]
				connection.state = LevelAssembler.connection_default(a.module, b.module)
				layout.connections.append(connection)
			if data.has("type"):
				connection.state = str(data.type)
				if connection.state != "security_door":
					connection.initially_locked = false
			if data.has("security_id"):
				connection.security_id = StringName(str(data.security_id))
			if data.has("initially_locked"):
				connection.initially_locked = bool(data.initially_locked)
	elif op == "connect_touching":
		return messages(LevelAssembler.connect_touching(layout), layout)
	elif op == "deck":
		var updates: Variant = data.get("elevations", {str(id): data.get("elevation")})
		if not updates is Dictionary:
			return [issue("invalid_decks", "elevations must be an object")]
		for key: Variant in updates:
			if (
				not (updates[key] is int or updates[key] is float)
				or not is_finite(float(updates[key]))
			):
				return [issue("invalid_elevation", "Deck elevations must be finite numbers")]
			layout.decks[str(key)] = float(updates[key])
		for instance in layout.instances:
			instance.bind_matching_decks(layout.decks)
	elif op == "bind_socket":
		item.socket_decks[str(data.get("socket", ""))] = str(data.get("deck", ""))
	elif op == "endpoint":
		if item == null:
			return [issue("unknown_instance", "Endpoint instance must exist", [str(id)])]
		if str(data.get("kind", "")) == "entry":
			layout.entry_instance = id
			layout.entry_marker = StringName(str(data.get("marker", "entry")))
		elif str(data.get("kind", "")) == "destination":
			layout.destination_instance = id
			layout.destination_marker = StringName(str(data.get("marker", "destination")))
		else:
			return [issue("invalid_endpoint_kind", "kind must be entry or destination")]
	elif op == "attachment":
		var attachment_id := StringName(str(data.get("attachment_id", "")))
		var model := Model.new()
		model.restore(layout)
		var updated: LevelLayout
		if bool(data.get("reset", false)):
			updated = model.attachment_reset(id, attachment_id)
		else:
			var current: LevelRoomAttachment
			var was_disabled := false
			if item.room_preset != null:
				for attachment in item.room_preset.attachments:
					if attachment.id == attachment_id:
						current = attachment.duplicate() as LevelRoomAttachment
			for override in item.attachment_overrides:
				if override.id == attachment_id and current != null:
					current.local_transform = override.local_transform
					was_disabled = override.disabled
			if current == null:
				return [
					issue(
						"unknown_attachment",
						"Unknown enabled attachment: " + str(attachment_id),
						[str(id)]
					)
				]
			var pose := current.local_transform
			if data.has("at"):
				if not vector_ok(data.at, 3):
					return [
						issue(
							"invalid_position",
							"Attachment at must contain three finite numbers",
							[str(id)]
						)
					]
				pose.origin = Vector3(data.at[0], data.at[1], data.at[2])
			if data.has("yaw"):
				if not (data.yaw is float or data.yaw is int) or not is_finite(float(data.yaw)):
					return [issue("invalid_rotation", "yaw must be a finite number", [str(id)])]
				pose.basis = Basis(Vector3.UP, deg_to_rad(float(data.yaw)))
			updated = model.attachment_changed(
				id, attachment_id, pose, bool(data.get("disabled", was_disabled))
			)
		item.attachment_overrides = updated.instance(id).attachment_overrides
	elif op == "theme":
		return assign_theme(layout, data)
	elif op == "composite":
		return place_composite(layout, data)
	elif op == "remove":
		var linked := false
		for connection in layout.connections:
			if connection.from_instance == id or connection.to_instance == id:
				linked = true
		if linked and not bool(data.get("remove_links", false)):
			return [
				issue(
					"connected_instance",
					"Explicit remove_links is required to remove a connected room",
					[str(id)]
				)
			]
		var model := Model.new()
		model.restore(layout)
		var updated := model.removed(id)
		layout.instances = updated.instances
		layout.connections = updated.connections
		layout.entry_instance = updated.entry_instance
		layout.destination_instance = updated.destination_instance
	elif op == "transport":
		var endpoint_id := StringName(str(data.get("endpoint_id", "")))
		var endpoint: LevelTransportEndpoint
		for current in item.transport_endpoints:
			if current.id == endpoint_id:
				endpoint = current
		if endpoint == null:
			endpoint = LevelTransportEndpoint.new()
			endpoint.id = endpoint_id
			item.transport_endpoints.append(endpoint)
		endpoint.kind = str(data.get("kind", "rings"))
		endpoint.target_id = StringName(str(data.get("target_id", "")))
		endpoint.anchor = StringName(str(data.get("anchor", "transport")))
		endpoint.node_path = NodePath(
			str(data.get("node_path", "Attachments/Interactions/transport/Rings"))
		)
		if data.has("target_instance"):
			var target := layout.instance(StringName(str(data.target_instance)))
			if target == null:
				return [
					issue(
						"unknown_instance",
						"Transport target instance must exist",
						[str(data.target_instance)]
					)
				]
			var reciprocal: LevelTransportEndpoint
			for current in target.transport_endpoints:
				if current.id == endpoint.target_id:
					reciprocal = current
			if reciprocal == null:
				reciprocal = LevelTransportEndpoint.new()
				reciprocal.id = endpoint.target_id
				target.transport_endpoints.append(reciprocal)
			reciprocal.target_id = endpoint.id
			reciprocal.kind = endpoint.kind
			reciprocal.anchor = endpoint.anchor
			reciprocal.node_path = endpoint.node_path

	return []


static func free_sockets(layout: LevelLayout, id: StringName) -> Array:
	var result: Array = []
	var item := layout.instance(id)
	if item == null or item.module == null:
		return result
	var taken := {}
	for value in layout.connections:
		if value.from_instance == id:
			taken[value.from_socket] = true
		if value.to_instance == id:
			taken[value.to_socket] = true
	for socket in item.module.sockets:
		if not taken.has(socket.id) and item.allows(socket.id):
			result.append(str(socket.id))
	return result


static func configure(item: LevelModuleInstance, preset_id: String) -> Array:
	var preset := (
		LevelCapabilityCatalogue.preset_by_id(StringName(preset_id)) if preset_id != "" else null
	)
	if preset_id != "" and preset == null:
		return [issue("unknown_preset", "Unknown preset: " + preset_id, [str(item.id)])]
	item.room_preset = preset
	item.role = preset.id if preset != null else &""
	return []


static func assign_theme(layout: LevelLayout, data: Dictionary) -> Array:
	var scope := str(data.get("scope", "map"))
	var id := StringName(str(data.get("theme_id", "")))
	if data.has("theme_id") and not LevelThemeResolver.registry().has(id):
		return [issue("unknown_theme", "Unknown theme: " + str(id))]
	if scope == "map":
		if id == &"":
			return [issue("missing_theme", "theme_id is required")]
		layout.default_theme = id
	elif scope == "room":
		var item := layout.instance(StringName(str(data.get("id", ""))))
		if item == null:
			return [
				issue(
					"unknown_instance", "Room theme instance must exist", [str(data.get("id", ""))]
				)
			]
		if data.has("theme_id") or bool(data.get("inherit", false)):
			item.theme = null
			item.theme_id = &"" if bool(data.get("inherit", false)) else id
			item.style = &"neutral"
		if data.has("zone_id"):
			item.theme_zone = StringName(str(data.zone_id))
	elif scope == "zone":
		var zone_id := StringName(str(data.get("zone_id", "")))
		if zone_id == &"" or id == &"":
			return [issue("missing_zone", "zone_id and theme_id are required")]
		var zone: LevelThemeZone
		for current in layout.theme_zones:
			if current.id == zone_id:
				zone = current
		if zone == null:
			zone = LevelThemeZone.new()
			zone.id = zone_id
			layout.theme_zones.append(zone)
		zone.theme_id = id
		if not data.get("instances", []) is Array:
			return [issue("invalid_zone_members", "instances must be an array")]
		for member: Variant in data.get("instances", []):
			var item := layout.instance(StringName(str(member)))
			if item == null:
				return [issue("unknown_instance", "Zone member must exist", [str(member)])]
			item.theme_zone = zone_id
	else:
		return [issue("unknown_theme_scope", "scope must be map, room or zone")]
	return []


static func place_composite(layout: LevelLayout, data: Dictionary) -> Array:
	var composite := LevelCapabilityCatalogue.composite_by_id(
		StringName(str(data.get("composite_id", "")))
	)
	if composite == null:
		return [issue("unknown_composite", "Unknown composite template")]
	var prefix := str(data.get("prefix", ""))
	var join: Dictionary = {}
	if data.has("attach") and data.attach is Dictionary:
		var named: Dictionary = data.attach
		var opening := str(named.get("opening", str(composite.layout.entry_instance)))
		if not "/" in opening or not named.has("target_socket"):
			# Unnamed sockets: try free pairs on a copy and keep the first that validates.
			var member := composite.layout.instance(StringName(opening.get_slice("/", 0)))
			if member == null:
				return [issue("invalid_attach", "opening must name a room of the composite")]
			var mine: Array = [opening.get_slice("/", 1)] if "/" in opening else free_sockets(composite.layout, member.id)
			var theirs: Array = (
				[str(named.target_socket)]
				if named.has("target_socket")
				else free_sockets(layout, StringName(str(named.get("target", ""))))
			)
			for a: String in mine:
				for b: String in theirs:
					var exact := data.merged(
						{"attach": named.merged({"opening": str(member.id) + "/" + a, "target_socket": b}, true)},
						true
					)
					var trial := Model.copy(layout)
					if (
						place_composite(trial, exact).is_empty()
						and LevelLayoutValidator.validate(trial, false).is_empty()
					):
						return place_composite(layout, exact)
			return [
				issue(
					"composite_does_not_fit",
					"No free socket pair places %s against %s without overlap" % [composite.id, named.get("target", "")],
					[str(named.get("target", ""))],
					[],
					"Attach to a room with a free doorway facing open space, or name another opening."
				)
			]
	if data.has("attach"):
		# Solve the group's position from one named opening, like a single room's attach.
		var solved := composite_pose(layout, composite, data.attach)
		if solved.has("errors"):
			return solved.errors
		join = data.attach
		data = data.merged({"at": solved.at, "turn": solved.turn}, true)
	if not identifier(prefix) or not vector_ok(data.get("at"), 2):
		return [
			issue(
				"invalid_composite_placement",
				"Provide a node-safe prefix and a two-number at position"
			)
		]
	var turn: Variant = data.get("turn", 0)
	if (
		not (turn is float or turn is int)
		or float(turn) != floorf(float(turn))
		or turn < 0
		or turn > 3
	):
		return [issue("invalid_rotation", "turn must be an integer from 0 to 3")]
	var deck_map: Variant = data.get("deck_map", {})
	if not deck_map is Dictionary:
		return [
			issue(
				"invalid_deck_map",
				"deck_map must map template deck IDs to existing layout deck IDs"
			)
		]
	var template := Model.copy(composite.layout)
	var ids := {}
	for zone in template.theme_zones:
		zone.id = StringName(prefix + "_" + str(zone.id))
		layout.theme_zones.append(zone)
	for item in template.instances:
		var old := item.id
		item.id = StringName(prefix + "_" + str(old))
		if layout.instance(item.id) != null:
			return [
				issue(
					"duplicate_instance",
					"Composite prefix collides with an existing instance",
					[str(item.id)]
				)
			]
		ids[old] = item.id
		if item.theme_zone != &"":
			item.theme_zone = StringName(prefix + "_" + str(item.theme_zone))
		for endpoint in item.transport_endpoints:
			endpoint.id = StringName(prefix + "_" + str(endpoint.id))
			if endpoint.target_id != &"":
				endpoint.target_id = StringName(prefix + "_" + str(endpoint.target_id))
		item.deck = StringName(str(deck_map.get(str(item.deck), str(item.deck))))
		for key: Variant in item.socket_decks:
			item.socket_decks[key] = str(
				deck_map.get(str(item.socket_decks[key]), str(item.socket_decks[key]))
			)
		var p := (
			Basis(Vector3.UP, int(turn) * PI / 2) * Vector3(item.position.x, 0, item.position.y)
		)
		item.position = Vector2(data.at[0] + p.x, data.at[1] + p.z)
		item.quarter_turn = (item.quarter_turn + int(turn)) % 4
		layout.instances.append(item)
	for connection in template.connections:
		connection.from_instance = ids[connection.from_instance]
		connection.to_instance = ids[connection.to_instance]
		if connection.security_id != &"":
			connection.security_id = StringName(prefix + "_" + str(connection.security_id))
		layout.connections.append(connection)
	if layout.entry_instance == &"":
		layout.entry_instance = ids[template.entry_instance]
	if layout.destination_instance == &"":
		layout.destination_instance = ids[template.destination_instance]
	if not join.is_empty():
		var opening := str(join.opening).split("/")
		var link: Dictionary = {
			"op": "connect",
			"from": str(join.get("target", "")),
			"from_socket": str(join.get("target_socket", "")),
			"to": prefix + "_" + opening[0],
			"to_socket": opening[1]
		}
		if join.has("type"):
			link["type"] = str(join.type)
		return operation(layout, link)
	return []


## Position and turn that bring a composite's named opening onto a target socket.
static func composite_pose(
	layout: LevelLayout, composite: LevelCompositeDefinition, attach: Variant
) -> Dictionary:
	if not attach is Dictionary or not attach.get("opening") is String:
		return {"errors": [issue("invalid_attach", "attach needs opening, target and target_socket")]}
	for key: Variant in attach:
		if not str(key) in ["opening", "target", "target_socket", "type"]:
			return {"errors": [issue("unsupported_field", "Unknown attach field: " + str(key))]}
	var opening := str(attach.opening).split("/")
	var member := composite.layout.instance(StringName(opening[0])) if opening.size() == 2 else null
	var target := layout.instance(StringName(str(attach.get("target", ""))))
	if member == null or target == null:
		return {
			"errors":
			[
				issue(
					"invalid_attach",
					"opening must be member/socket of the composite and target an existing room",
					[str(attach.get("target", ""))],
					[],
					"List openings with catalogue --kind composite."
				)
			]
		}
	# Solve on a scratch pair with the shared snap, then apply the same rigid motion to all.
	var scratch := LevelLayout.new()
	scratch.decks = layout.decks.duplicate()
	var fixed := target.duplicate() as LevelModuleInstance
	fixed.room_preset = null
	var moving := member.duplicate() as LevelModuleInstance
	moving.room_preset = null
	moving.id = &"__opening"
	moving.deck = fixed.socket_deck(StringName(str(attach.get("target_socket", ""))))
	moving.socket_decks = {}
	moving.bind_matching_decks(scratch.decks)
	scratch.instances = [fixed, moving]
	var errors := LevelAssembler.snap(
		scratch, moving.id, StringName(opening[1]), fixed.id,
		StringName(str(attach.get("target_socket", "")))
	)
	if not errors.is_empty():
		return {"errors": messages(errors, layout)}
	var turn := posmod(moving.quarter_turn - member.quarter_turn, 4)
	var rotated := Basis(Vector3.UP, turn * PI / 2) * Vector3(member.position.x, 0, member.position.y)
	return {"at": [moving.position.x - rotated.x, moving.position.y - rotated.z], "turn": turn}


static func save(layout: LevelLayout, output: String, overwrite: bool = false) -> Array:
	var normalized := output.simplify_path()
	if (
		not normalized.ends_with(".tres")
		or not (
			normalized.begins_with("res://resources/levels/") or normalized.begins_with("user://")
		)
	):
		return [
			issue(
				"protected_output",
				"Layouts must be saved under res://resources/levels/ or user:// as .tres"
			)
		]
	if FileAccess.file_exists(normalized) and not overwrite:
		return [
			issue(
				"output_exists", "Output already exists; use --overwrite explicitly to update it."
			)
		]
	var previous_uid := (
		ResourceLoader.get_resource_uid(normalized) if FileAccess.file_exists(normalized) else -1
	)
	var staging := normalized.get_basename() + ".pending_" + str(Time.get_ticks_usec()) + ".tres"
	if ResourceSaver.save(layout, staging) != OK:
		return [issue("save_failed", "Cannot write staged layout: " + normalized)]
	if previous_uid >= 0:
		var text := FileAccess.get_file_as_string(staging)
		var split := text.find("\n")
		var header := text.left(split)
		var regex := RegEx.new()
		regex.compile('uid="[^"]*"')
		var uid := 'uid="' + ResourceUID.id_to_text(previous_uid) + '"'
		header = (
			regex.sub(header, uid)
			if regex.search(header) != null
			else header.trim_suffix("]") + " " + uid + "]"
		)
		var file := FileAccess.open(staging, FileAccess.WRITE)
		if file == null:
			return [issue("save_failed", "Cannot preserve layout UID")]
		file.store_string(header + text.substr(split))
		file.close()
	var result := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(normalized)
	)
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging))
		return [issue("save_failed", "Cannot atomically replace layout: " + normalized)]
	return []
