extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	assert(
		LevelCapabilityCatalogue.validate_sources().is_empty(),
		str(LevelCapabilityCatalogue.validate_sources())
	)
	var catalogue := LevelCatalogue.catalogue(true)
	var counts: Dictionary = {}
	var straight: Dictionary = {}
	for entry: Dictionary in catalogue.capabilities:
		counts[entry.kind] = int(counts.get(entry.kind, 0)) + 1
		if entry.kind == "module" and entry.id == "room01":
			straight = entry
	assert(
		counts.module == 15 and counts.preset == 16 and counts.theme == 6 and counts.composite >= 1
	)
	assert(
		(
			straight.occupied
			== LevelCapabilityCatalogue.encode(LevelCatalogue.module_by_id(&"room01").occupied)
		)
	)
	assert(straight.markers.size() >= 2 and straight.visual_slots.size() > 0)
	assert(not LevelCatalogue.catalogue(false, "bridge", "preset").capabilities.is_empty())
	assert(not LevelCatalogue.catalogue(false, "command center", "preset").capabilities.is_empty())
	assert(not LevelCatalogue.catalogue(false, "squad movement", "module").capabilities.is_empty())
	assert(not LevelCatalogue.catalogue(false, "tokra", "theme").capabilities.is_empty())
	assert(LevelCapabilityCatalogue.verify(catalogue).is_empty())
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(catalogue))
	assert(LevelCapabilityCatalogue.verify(roundtrip).is_empty())
	var definition := LevelCatalogue.module_by_id(&"room01")
	var previous := definition.occupied
	definition.occupied = AABB(previous.position, previous.size + Vector3(8, 0, 0))
	assert(
		not LevelCapabilityCatalogue.verify(catalogue).is_empty(),
		"Resource edits must invalidate the generated snapshot"
	)
	definition.occupied = previous
	assert(LevelCapabilityCatalogue.verify(catalogue).is_empty())
	var broken := catalogue.duplicate(true)
	broken.capabilities[0].name = "stale label"
	assert(not LevelCapabilityCatalogue.verify(broken).is_empty())
	print(
		"PASS live catalogue discovery, semantic search, dimensions/markers from actual resources, deterministic roundtrip and stale metadata detection"
	)
	await preload("res://tests/support/finish.gd").success(self)
