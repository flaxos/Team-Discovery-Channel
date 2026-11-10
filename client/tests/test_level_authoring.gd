extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var request: Dictionary = {
		"version": 1,
		"create": {"theme_id": "asgard"},
		"operations":
		[
			{
				"op": "place",
				"id": "cargo",
				"module_id": "room04",
				"preset_id": "cargo",
				"at": [0, 0]
			},
			{
				"op": "place",
				"id": "barracks",
				"module_id": "room04",
				"preset_id": "jaffa_barracks",
				"attach": {"socket": "north", "target": "cargo", "target_socket": "south"}
			},
			{"op": "endpoint", "kind": "destination", "id": "barracks"},
			{
				"op": "theme",
				"scope": "zone",
				"zone_id": "stores",
				"theme_id": "goauld",
				"instances": ["cargo"]
			},
			{"op": "theme", "scope": "room", "id": "cargo", "theme_id": "neutral"}
		]
	}
	var result := LevelAuthoring.transact(null, request)
	assert(result.ok, str(result.get("errors")))
	var layout := result.layout as LevelLayout
	assert(layout.instances.size() == 2 and layout.connections.size() == 1)
	assert(LevelThemeResolver.selected(layout, layout.instance(&"cargo")).id == &"neutral")
	assert(LevelThemeResolver.selected(layout, layout.instance(&"barracks")).id == &"asgard")
	var original := layout.instance(&"cargo").room_preset
	var failed := LevelAuthoring.transact(
		layout,
		{
			"operations":
			[
				{"op": "configure", "id": "cargo", "preset_id": "security_control"},
				{"op": "move", "id": "barracks", "at": [80, 80]}
			]
		}
	)
	assert(not failed.ok and failed.errors[0].operation_index == 1)
	assert(layout.instance(&"cargo").room_preset == original and layout.connections.size() == 1)
	assert(
		failed.errors[0].instance_ids.has("barracks") and not failed.errors[0].socket_ids.is_empty()
	)
	layout.connections[0].state = "open"
	result = LevelAuthoring.transact(layout, {"operations": [{"op": "connect_touching"}]})
	assert(result.ok and result.layout.connections[0].state == "open")
	result = LevelAuthoring.transact(
		layout,
		{
			"operations":
			[
				{
					"op": "place",
					"id": "wide",
					"module_id": "room06",
					"attach": {"socket": "north", "target": "barracks", "target_socket": "south"}
				}
			]
		}
	)
	assert(not result.ok and result.errors[0].reason.contains("Incompatible"))
	assert(
		not LevelAuthoring.transact(layout, {"operations": [{"op": "enemy_ai", "id": "cargo"}]}).ok
	)
	assert(
		not (
			LevelAuthoring
			. transact(layout, {"operations": [{"op": "theme", "theme_id": "invented"}]})
			. ok
		)
	)
	assert(not LevelAuthoring.transact(layout, {"version": {}, "operations": []}).ok)
	assert(
		not (
			LevelAuthoring
			. transact(layout, {"operations": [{"op": "move", "id": "cargo", "at": "wrong"}]})
			. ok
		)
	)
	assert(
		not (
			LevelAuthoring
			. transact(
				layout,
				{
					"operations":
					[{"op": "move", "id": "cargo", "at": [0, 0], "auto_connect": "false"}]
				}
			)
			. ok
		)
	)
	var composite := LevelAuthoring.transact(
		null,
		{
			"create": {"theme_id": "tokra"},
			"operations":
			[
				{
					"op": "composite",
					"composite_id": "gallery_24",
					"prefix": "gallery",
					"at": [0, 0],
					"turn": 1
				}
			]
		}
	)
	assert(
		(
			composite.ok
			and composite.layout.instances.size() == 3
			and composite.layout.connections.size() == 2
		),
		str(composite.get("errors"))
	)
	assert(
		(
			composite.layout.default_theme == &"tokra"
			and composite.layout.connections[0].state == "open"
		)
	)
	var vertical := LevelAuthoring.transact(
		null,
		{
			"create": {"decks": {"low": -5.5, "high": -1.5}},
			"operations":
			[
				{"op": "place", "id": "ramp", "module_id": "room14", "deck": "low", "at": [0, 0]},
				{
					"op": "place",
					"id": "lower",
					"module_id": "room01",
					"deck": "low",
					"attach": {"socket": "south", "target": "ramp", "target_socket": "lower"}
				},
				{
					"op": "place",
					"id": "upper",
					"module_id": "room01",
					"deck": "high",
					"attach": {"socket": "north", "target": "ramp", "target_socket": "upper"}
				}
			]
		}
	)
	assert(
		vertical.ok and vertical.layout.instance(&"ramp").socket_deck(&"upper") == &"high",
		str(vertical.get("errors"))
	)
	var rings := LevelAuthoring.transact(
		null,
		{
			"create": {},
			"operations":
			[
				{
					"op": "place",
					"id": "a",
					"module_id": "room15",
					"preset_id": "ring_transport",
					"at": [0, 0]
				},
				{
					"op": "place",
					"id": "b",
					"module_id": "room15",
					"preset_id": "ring_transport",
					"attach": {"socket": "north", "target": "a", "target_socket": "south"}
				},
				{
					"op": "transport",
					"id": "a",
					"endpoint_id": "ring_a",
					"target_id": "ring_b",
					"target_instance": "b"
				}
			]
		}
	)
	assert(rings.ok, str(rings.get("errors")))
	assert(rings.layout.instance(&"b").transport_endpoints[0].target_id == &"ring_a")
	var optional := LevelAuthoring.transact(
		layout,
		{
			"operations":
			[
				{"op": "attachment", "id": "cargo", "attachment_id": "cover_01", "disabled": true},
				{"op": "attachment", "id": "cargo", "attachment_id": "cover_01", "disabled": false}
			]
		}
	)
	assert(optional.ok, str(optional.get("errors")))
	# The actual public Python CLI must preserve bytes on failure and the resource UID on an edit.
	var file := FileAccess.open("user://author_request.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(request))
	file.close()
	var cli := ProjectSettings.globalize_path("res://../tools/level_authoring.py")
	var output: Array = []
	var status := OS.execute(
		"python3",
		PackedStringArray(
			[
				cli,
				"apply",
				"--request",
				ProjectSettings.globalize_path("user://author_request.json"),
				"--output",
				"user://author_transaction.tres"
			]
		),
		output,
		true
	)
	assert(status == 0, str(output))
	var response: Dictionary = JSON.parse_string(str(output[0]))
	assert(response.ok)
	# Simulate an editor-authored UID even when headless ResourceSaver omitted one.
	var uid := ResourceLoader.get_resource_uid("user://author_transaction.tres")
	if uid < 0:
		uid = ResourceUID.create_id()
		var saved := FileAccess.get_file_as_string("user://author_transaction.tres")
		var newline := saved.find("\n")
		var header := (
			saved.left(newline).trim_suffix("]") + ' uid="' + ResourceUID.id_to_text(uid) + '"]'
		)
		file = FileAccess.open("user://author_transaction.tres", FileAccess.WRITE)
		file.store_string(header + saved.substr(newline))
		file.close()
	var digest := FileAccess.get_sha256("user://author_transaction.tres")
	file = FileAccess.open("user://author_request.json", FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"operations": [{"op": "move", "id": "barracks", "at": [80, 80]}]})
	)
	file.close()
	output.clear()
	status = OS.execute(
		"python3",
		PackedStringArray(
			[
				cli,
				"apply",
				"--request",
				ProjectSettings.globalize_path("user://author_request.json"),
				"--layout",
				"user://author_transaction.tres",
				"--output",
				"user://author_transaction.tres",
				"--overwrite"
			]
		),
		output,
		true
	)
	assert(status != 0 and FileAccess.get_sha256("user://author_transaction.tres") == digest)
	response = JSON.parse_string(str(output[0]))
	assert(not response.ok and not response.errors[0].remedy.is_empty())
	file = FileAccess.open("user://author_request.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"operations": [{"op": "theme", "theme_id": "replicator"}]}))
	file.close()
	output.clear()
	status = OS.execute(
		"python3",
		PackedStringArray(
			[
				cli,
				"apply",
				"--request",
				ProjectSettings.globalize_path("user://author_request.json"),
				"--layout",
				"user://author_transaction.tres",
				"--output",
				"user://author_transaction.tres",
				"--overwrite"
			]
		),
		output,
		true
	)
	assert(status == 0, str(output))
	assert(ResourceLoader.get_resource_uid("user://author_transaction.tres") == uid)
	assert(
		FileAccess.get_file_as_string("user://author_transaction.tres").contains(
			ResourceUID.id_to_text(uid)
		)
	)
	assert(not LevelAuthoring.save(layout, "res://resources/maps/sgc.tres", true).is_empty())
	print(
		"PASS shared API/CLI discovery transactions, rollback, IDs/remedies, native layout UID, explicit connections, composite placement, deck sockets, preset overrides and theme scopes"
	)
	await preload("res://tests/support/finish.gd").success(self)
