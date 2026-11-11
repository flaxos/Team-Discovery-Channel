extends SceneTree
## Graph planning, topology checks, composite clusters and tactical catalogue metadata.
const BRIEFS := {
	"res://resources/levels/ai2_goauld_security_compound.tres": "ai2_goauld_security_compound",
	"res://resources/levels/ai2_asgard_research_facility.tres": "ai2_asgard_research_facility",
	"res://resources/levels/ai2_tauri_alpha_site.tres": "ai2_tauri_alpha_site",
	"res://resources/levels/ai2_goauld_compound_two_deck.tres": "ai2_goauld_compound_two_deck"
}


func _init() -> void:
	call_deferred("run")


func room(id: String, kind: String, extra: Dictionary = {}) -> Dictionary:
	return {"id": id, "kind": kind}.merged(extra)


func link(a: String, b: String, extra: Dictionary = {}) -> Dictionary:
	return {"a": a, "b": b}.merged(extra)


func check(layout: LevelLayout, requirement: Dictionary) -> Dictionary:
	return LevelTopology.evaluate(layout, [requirement]).results[0]


func run() -> void:
	# --- Catalogue: tactical metadata separates authored intent from derived facts.
	assert(LevelCapabilityCatalogue.validate_sources().is_empty())
	var full := LevelCatalogue.catalogue()
	var by_id := {}
	for record: Dictionary in full.capabilities:
		by_id[record.kind + ":" + record.id] = record
	var corridor: Dictionary = by_id["module:room01"].tactical
	assert("patrol_route" in corridor.authored.gameplay_roles and corridor.authored.sightlines != "")
	assert(corridor.derived.openings == 2 and corridor.derived.narrowest_opening_m == 3.0)
	assert(corridor.derived.cover_props == 0 and "cover" in corridor.derived.markers)
	assert(corridor.inferred.chokepoint_potential == "high")
	assert(by_id["module:room14"].tactical.derived.deck_rise_m == 4.0)
	assert(by_id["module:room11"].tactical.derived.reserved_area_m2 == 256.0)
	var cargo: Dictionary = by_id["preset:cargo"].tactical.derived
	assert(cargo.cover_attachments == ["cover_01"] and "cargo_interaction" in cargo.objective_locations)
	assert(by_id["preset:command"].tactical.derived.cover_attachments.is_empty(), "No invented cover")
	assert("play-tested" in full.tactical_basis)
	var summary := LevelCapabilityCatalogue.summarise(full)
	assert(JSON.stringify(summary).length() < JSON.stringify(full).length() / 2)
	assert(summary.capabilities.size() == full.capabilities.size())
	for id: String in [
		"barracks_wing", "checkpoint_cluster", "cargo_wing", "command_section",
		"generator_section", "ring_access_wing"
	]:
		var composite: Dictionary = by_id["composite:" + id]
		assert(composite.rooms >= 3 and not composite.openings.is_empty() and not composite.presets.is_empty())
		assert(composite.layout.begins_with("res://resources/levels/composites/"))
	assert(LevelCapabilityCatalogue.verify(LevelCatalogue.catalogue(true)).is_empty())

	# --- Planner: a loop with side rooms, from roles and links only.
	var request := {
		"version": 1,
		"rooms": [
			room("entry", "corridor"), room("hub", "junction"), room("west", "corridor"),
			room("far_w", "corridor"), room("vault", "generator"), room("far_e", "corridor"),
			room("post", "security_checkpoint"), room("east", "corridor"), room("cells", "detention")
		],
		"links": [
			link("entry", "hub"), link("hub", "west"), link("west", "far_w"), link("far_w", "vault"),
			link("vault", "far_e"),
			link("far_e", "post", {"type": "security_door", "security_id": "gate", "locked": true}),
			link("post", "east"), link("east", "hub"), link("post", "cells")
		],
		"entry": "entry",
		"destination": "vault"
	}
	var planned := LevelPlanner.plan(request)
	assert(planned.ok, str(planned.get("errors", [])))
	var layout: LevelLayout = planned.layout
	assert(layout.instances.size() == 9 and layout.connections.size() == 9)
	assert(LevelLayoutValidator.validate(layout).is_empty(), "Planned layout is structurally valid")
	assert(layout.instance(&"vault").room_preset.id == &"generator")
	assert(layout.instance(&"hub").module.sockets.size() == 3, "Fewest spare openings")
	var again := LevelPlanner.plan(request)
	assert(JSON.stringify(again.placed) == JSON.stringify(planned.placed), "Deterministic")
	var gate: LevelModuleConnection
	for edge in layout.connections:
		if edge.security_id == &"gate":
			gate = edge
	assert(gate != null and gate.state == "security_door" and gate.initially_locked)
	# Native resource round trip; no other map representation is written.
	assert(LevelAuthoring.save(layout, "user://test_planned_loop.tres", true).is_empty())
	var reloaded := ResourceLoader.load("user://test_planned_loop.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as LevelLayout
	assert(reloaded != null and reloaded.instances.size() == 9)
	assert(LevelLayoutValidator.validate(reloaded).is_empty())

	# --- Topology: gameplay checks are reported separately from structural validity.
	assert(check(layout, {"check": "distinct_routes", "from": "hub", "to": "vault", "min": 2}).ok)
	var open_only := check(layout, {"check": "distinct_routes", "from": "hub", "to": "vault", "unlocked_only": true})
	assert(not open_only.ok and open_only.found == 1, "The locked gate removes one route")
	assert(check(layout, {"check": "alternate_route", "from": "entry", "to": "destination", "around": "post"}).ok)
	assert(check(layout, {"check": "reachable", "from": "entry", "to": "vault", "unlocked_only": true}).ok)
	assert(not check(layout, {"check": "reachable", "from": "east", "to": "far_e", "unlocked_only": true}).route.is_empty())
	assert(check(layout, {"check": "dead_ends", "allowed": ["entry", "cells"]}).ok)
	var undeclared := check(layout, {"check": "dead_ends", "allowed": ["entry"]})
	assert(not undeclared.ok and undeclared.undeclared == ["cells"])
	assert(check(layout, {"check": "only_via", "room": "cells", "via": "post"}).ok)
	assert(not check(layout, {"check": "only_via", "room": "vault", "via": "post"}).ok)
	assert(check(layout, {"check": "min_branches", "min": 2}).ok)
	assert(check(layout, {"check": "roles", "required": {"generator": 1}}).ok)
	assert(not check(layout, {"check": "roles", "required": {"command": 1}}).ok)
	assert(check(layout, {"check": "route", "through": ["entry", "cells", "vault"]}).ok)
	assert(not check(layout, {"check": "nonsense"}).ok and not check(layout, {"check": "reachable", "from": "nowhere", "to": "vault"}).ok)
	var facts := LevelTopology.summary(layout)
	assert(facts.loops == 1 and facts.separate_areas == 1 and "hub" in facts.chokepoint_rooms)
	var line := LevelPlanner.plan(
		{"rooms": [room("a", "corridor"), room("b", "corridor"), room("c", "cargo")], "links": [link("a", "b"), link("b", "c")]}
	)
	assert(line.ok and LevelLayoutValidator.validate(line.layout).is_empty(), "A linear map is still a valid build")
	assert(not check(line.layout, {"check": "distinct_routes", "from": "a", "to": "c"}).ok)

	# --- Explicit failures: nothing is invented to make a request fit.
	var triangle := LevelPlanner.plan(
		{"rooms": [room("a", "corridor"), room("b", "corridor"), room("c", "corridor")], "links": [link("a", "b"), link("b", "c"), link("c", "a")]}
	)
	assert(not triangle.ok and triangle.errors[0].code == "plan_unplaceable")
	assert(triangle.errors[0].diagnosis.blocked_room == "c" and "loop" in triangle.errors[0].remedy.to_lower())
	var widths := LevelPlanner.plan(
		{"rooms": [room("a", "corridor"), room("b", "wide_corridor")], "links": [link("a", "b")]}
	)
	assert(not widths.ok and "adapter" in widths.errors[0].remedy)
	var adapted := LevelPlanner.plan(
		{"rooms": [room("a", "corridor"), room("x", "adapter"), room("b", "wide_corridor")], "links": [link("a", "x"), link("x", "b")]}
	)
	assert(adapted.ok and adapted.layout.instance(&"x").module.id == &"room09")
	var decks := {"deck0": 0.0, "upper": 4.0}
	var no_ramp := LevelPlanner.plan(
		{"decks": decks, "rooms": [room("a", "corridor"), room("b", "corridor", {"deck": "upper"})], "links": [link("a", "b")]}
	)
	assert(not no_ramp.ok and "ramp" in no_ramp.errors[0].remedy)
	var ramped := LevelPlanner.plan(
		{"decks": decks, "rooms": [room("a", "corridor"), room("r", "ramp"), room("b", "command", {"deck": "upper"})], "links": [link("a", "r"), link("r", "b")], "destination": "b"}
	)
	assert(ramped.ok and LevelLayoutValidator.validate(ramped.layout).is_empty())
	assert(ramped.layout.instance(&"r").socket_deck(&"upper") == &"upper")
	for bad: Dictionary in [
		{"rooms": [room("a", "ballroom")], "links": []},
		{"rooms": [room("a", "corridor"), room("b", "corridor")], "links": []},
		{"rooms": [room("a", "ring_transport"), room("b", "corridor"), room("c", "corridor"), room("d", "corridor")], "links": [link("a", "b"), link("a", "c"), link("a", "d")]},
		{"rooms": [room("a", "corridor")], "links": [], "surprise": true}
	]:
		var refused := LevelPlanner.plan(bad)
		assert(not refused.ok and refused.errors[0].remedy != "", str(bad))

	# --- Clusters: composites expand into ordinary rooms without naming sockets.
	var site := LevelPlanner.plan(
		{
			"decks": decks,
			"rooms": [room("entry", "corridor"), room("hub", "junction"), room("ramp", "ramp"), room("top", "junction", {"deck": "upper"})],
			"links": [link("entry", "hub"), link("hub", "ramp"), link("ramp", "top")],
			"clusters": [
				{"composite_id": "checkpoint_cluster", "prefix": "gate", "attach_to": "hub", "opening": "approach"},
				{"composite_id": "command_section", "prefix": "cmd", "attach_to": "top"}
			],
			"destination": "cmd_command"
		}
	)
	assert(site.ok, str(site.get("errors", [])))
	layout = site.layout
	assert(LevelLayoutValidator.validate(layout).is_empty())
	assert(layout.instance(&"cmd_command").deck == &"upper" and layout.instance(&"gate_checkpoint").deck == &"deck0")
	assert(layout.instance(&"cmd_command").theme_id == &"" and layout.instance(&"cmd_command").theme == null, "Theme is inherited")
	assert(layout.destination_instance == &"cmd_command")
	var ids := {}
	for edge in layout.connections:
		ids[edge.security_id] = true
	assert(ids.has(&"gate_gate") and ids.has(&"cmd_command"), "Security IDs keep their prefix")
	assert(check(layout, {"check": "only_via", "room": "cmd_command", "via": "cmd_antechamber"}).ok)
	var edit := LevelAuthoring.transact(
		layout,
		{"operations": [
			{"op": "place", "id": "store", "module_id": "room04", "preset_id": "cargo", "attach": {"target": "gate_control"}},
			{"op": "composite", "composite_id": "ring_access_wing", "prefix": "rings", "attach": {"target": "gate_beyond"}}
		]}
	)
	assert(edit.ok, str(edit.get("errors", [])))
	assert(edit.layout.instance(&"rings_rings") != null and LevelLayoutValidator.validate(edit.layout).is_empty())
	var full_room := LevelAuthoring.transact(
		layout, {"operations": [{"op": "composite", "composite_id": "cargo_wing", "prefix": "x", "attach": {"target": "ramp"}}]}
	)
	assert(not full_room.ok and full_room.errors[0].code == "composite_does_not_fit")
	var legacy := LevelAuthoring.transact(
		null,
		{"create": {}, "operations": [{"op": "composite", "composite_id": "gallery_24", "prefix": "g", "at": [0, 0], "turn": 1}]}
	)
	assert(legacy.ok and legacy.layout.instances.size() == 3, "Coordinate placement still works")

	# --- The four demonstration maps: full bake, and their documented requirements.
	for path: String in BRIEFS:
		var saved := load(path) as LevelLayout
		var plan: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../docs/maps/briefs/%s.requirements.json" % BRIEFS[path]))
		)
		var result := LevelTopology.evaluate(saved, plan.requirements)
		assert(result.ok, path + " " + str(result))
		var level := LevelAssembly.new()
		level.layout = saved
		root.add_child(level)
		while not level.ready_for_navigation and level.last_errors.is_empty():
			await process_frame
		assert(level.last_errors.is_empty(), path + " " + str(level.last_errors))
		level.queue_free()
		await process_frame
		await process_frame
	print("PASS graph planner, topology checks, composite clusters, tactical catalogue and four demonstration maps")
	await preload("res://tests/support/finish.gd").success(self)
