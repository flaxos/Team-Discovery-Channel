@tool
class_name LevelCatalogue
extends RefCounted
const MODULES: PackedStringArray = [
	"Room01Straight",
	"Room02Corner",
	"Room03TJunction",
	"Room04Chamber",
	"Room05XJunction",
	"Room06WideStraight",
	"Room07WideCorner",
	"Room08WideJunction",
	"Room09WidthAdapter",
	"Room10LongChamber",
	"Room11LargeChamber",
	"Room13SpecialHall"
]

# Keep the original planar inventory available to existing planar contract tests.
const VERTICAL_MODULES: PackedStringArray = [
	"Room14Ramp4m", "Room15TransportChamber", "Room16HangarShell"
]

const GRID_SIZE: float = 8.0


static func module_definitions() -> Array[LevelModuleDefinition]:
	var result: Array[LevelModuleDefinition] = []
	var files := DirAccess.get_files_at("res://resources/level_modules/")
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var value := load("res://resources/level_modules/" + file)
			if value is LevelModuleDefinition:
				result.append(value)
	return result


static func all_modules() -> PackedStringArray:
	var result := PackedStringArray()
	for module in module_definitions():
		result.append(module.resource_path.get_file().get_basename())
	return result


static func module_by_id(id: StringName) -> LevelModuleDefinition:
	for module in module_definitions():
		if module.id == id:
			return module
	return null


static func catalogue(detail: bool = false, query: String = "", kind: String = "all") -> Dictionary:
	return LevelCapabilityCatalogue.generate(detail, query, kind)
