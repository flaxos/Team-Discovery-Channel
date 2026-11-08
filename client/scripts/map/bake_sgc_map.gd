extends SceneTree


## Rebuild navigation from the authored resource. --reset-layout restores factory topology.
func _init() -> void:
	call_deferred("bake")


func bake() -> void:
	var definition := SGCMapDefinition.create_default()
	if (
		ResourceLoader.exists("res://resources/maps/sgc.tres")
		and "--reset-layout" not in OS.get_cmdline_user_args()
	):
		definition = load("res://resources/maps/sgc.tres").duplicate(true) as SGCMapDefinition
	var room := load("res://scenes/main/GateRoom.tscn").instantiate() as GateRoom
	var map := room.get_node("SGCMap") as SGCMap
	map.definition = definition
	root.add_child(room)
	await map.navigation_ready
	assert(ResourceSaver.save(map.definition, "res://resources/maps/sgc.tres") == OK)
	assert(
		(
			ResourceSaver.save(
				map.nav_region.navigation_mesh, "res://resources/maps/sgc_navigation.res"
			)
			== OK
		)
	)
	print(
		"Saved SGC definition, ",
		map.definition.asset_slots.size(),
		" art slots and ",
		map.nav_region.navigation_mesh.get_polygon_count(),
		" navigation polygons"
	)
	await preload("res://tests/support/finish.gd").success(self)
