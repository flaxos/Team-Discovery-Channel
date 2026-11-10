extends SceneTree
var level: LevelAssembly


func _init() -> void:
	call_deferred("run")


func respond(data: Dictionary, code: int = 0) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
		await process_frame
	print("TDC_AUTHOR_RESULT " + JSON.stringify(data))
	OS.delay_msec(50)
	quit(code)


func failed(errors: Array) -> void:
	await respond({"ok": false, "version": 1, "errors": errors}, 1)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--request" or not FileAccess.file_exists(args[1]):
		await failed(
			[LevelAuthoring.issue("invalid_request", "Use --request <temporary JSON file>")]
		)
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(args[1])) != OK or not parser.data is Dictionary:
		await failed([LevelAuthoring.issue("invalid_json", "Request must be a JSON object")])
		return
	var request: Dictionary = parser.data
	var command := str(request.get("command", ""))
	if command == "catalogue":
		var errors := LevelCapabilityCatalogue.validate_sources()
		if not errors.is_empty():
			await failed(LevelAuthoring.messages(errors))
			return
		var data := LevelCatalogue.catalogue(
			bool(request.get("detail", false)),
			str(request.get("search", "")),
			str(request.get("kind", "all"))
		)
		if request.has("verify"):
			if not FileAccess.file_exists(str(request.verify)):
				await failed(
					[LevelAuthoring.issue("missing_snapshot", "Catalogue snapshot not found")]
				)
				return
			var snapshot: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(str(request.verify))
			)
			if not snapshot is Dictionary:
				await failed(
					[
						LevelAuthoring.issue(
							"invalid_snapshot", "Catalogue snapshot must be an object"
						)
					]
				)
				return
			errors = LevelCapabilityCatalogue.verify(snapshot)
			if not errors.is_empty():
				await failed(LevelAuthoring.messages(errors))
				return
		if request.has("output"):
			var file := FileAccess.open(str(request.output), FileAccess.WRITE)
			if file == null:
				await failed(
					[LevelAuthoring.issue("write_failed", "Cannot save generated catalogue")]
				)
				return
			file.store_string(JSON.stringify(data, "  ") + "\n")
		await respond({"ok": true, "version": 1, "catalogue": data})
		return
	var path := str(request.get("layout", ""))
	var source: LevelLayout
	var digest := ""
	if not path.is_empty():
		if not ResourceLoader.exists(path):
			await failed([LevelAuthoring.issue("missing_layout", "Layout does not exist: " + path)])
			return
		digest = FileAccess.get_sha256(path)
		source = load(path) as LevelLayout
		if source == null:
			await failed(
				[
					LevelAuthoring.issue(
						"invalid_layout_resource", "Input must be a LevelLayout .tres resource"
					)
				]
			)
			return
	if command == "apply":
		var transaction: Variant = request.get("transaction")
		if not transaction is Dictionary:
			await failed(
				[LevelAuthoring.issue("invalid_transaction", "apply requires a transaction object")]
			)
			return
		var result := LevelAuthoring.transact(source, transaction)
		if not result.ok:
			await failed(result.errors)
			return
		var output := str(request.get("output", ""))
		if output == path and not path.is_empty() and digest != FileAccess.get_sha256(path):
			await failed(
				[
					LevelAuthoring.issue(
						"layout_changed", "Input changed during the transaction; inspect and retry"
					)
				]
			)
			return
		var errors := LevelAuthoring.save(
			result.layout, output, bool(request.get("overwrite", false))
		)
		if not errors.is_empty():
			await failed(errors)
			return
		await respond(
			{
				"ok": true,
				"version": 1,
				"layout": output,
				"sha256": FileAccess.get_sha256(output),
				"instances": result.layout.instances.size(),
				"connections": result.layout.connections.size(),
				"warnings": result.warnings
			}
		)
		return
	if source == null:
		await failed([LevelAuthoring.issue("missing_layout", "Provide --layout")])
		return
	if command == "inspect":
		var data: Dictionary = {
			"resource": path,
			"sha256": digest,
			"decks": source.decks,
			"default_theme": str(source.default_theme),
			"zones": [],
			"instances": [],
			"connections": []
		}
		for zone in source.theme_zones:
			data.zones.append({"id": str(zone.id), "theme_id": str(zone.theme_id)})
		for item in source.instances:
			var sockets: Array = []
			for socket in item.module.sockets:
				sockets.append(
					{
						"id": str(socket.id),
						"deck": str(item.socket_deck(socket.id)),
						"family": str(socket.family),
						"enabled": item.allows(socket.id)
					}
				)
			data.instances.append(
				{
					"id": str(item.id),
					"module_id": str(item.module.id),
					"at": LevelCapabilityCatalogue.encode(item.position),
					"turn": item.quarter_turn,
					"deck": str(item.deck),
					"socket_decks": item.socket_decks,
					"preset_id": str(item.room_preset.id) if item.room_preset != null else "",
					"theme": LevelThemeResolver.describe(source, item),
					"zone": str(item.theme_zone),
					"sockets": sockets
				}
			)
		for edge in source.connections:
			data.connections.append(
				{
					"from": str(edge.from_instance),
					"from_socket": str(edge.from_socket),
					"to": str(edge.to_instance),
					"to_socket": str(edge.to_socket),
					"type": edge.state,
					"security_id": str(edge.security_id),
					"initially_locked": edge.initially_locked
				}
			)
		await respond({"ok": true, "version": 1, "layout": data})
		return
	if command not in ["validate", "build"]:
		await failed([LevelAuthoring.issue("unknown_command", "Unsupported command: " + command)])
		return
	var errors := LevelLayoutValidator.validate(source)
	if not errors.is_empty():
		await failed(LevelAuthoring.messages(errors, source))
		return
	level = LevelAssembly.new()
	level.layout = source
	root.add_child(level)
	while not level.ready_for_navigation and level.last_errors.is_empty():
		await process_frame
	if not level.last_errors.is_empty():
		await failed(LevelAuthoring.messages(level.last_errors, source))
		return
	if command == "build":
		errors = LevelBuildPipeline.export(
			level, str(request.get("output", "")), str(request.get("nav_output", ""))
		)
		if not errors.is_empty():
			await failed(LevelAuthoring.messages(errors, source))
			return
	var theme_info: Array = []
	for item in source.instances:
		theme_info.append({"id": str(item.id), "theme": LevelThemeResolver.describe(source, item)})
	await respond(
		{
			"ok": true,
			"version": 1,
			"layout": path,
			"validated":
			[
				"schema",
				"sockets",
				"overlap",
				"enclosure",
				"equipment",
				"navigation",
				"required_markers"
			],
			"scene": str(request.get("output", "")),
			"navigation": str(request.get("nav_output", "")),
			"themes": theme_info,
			"warnings": Array(LevelRoomComposer.warnings(source))
		}
	)
