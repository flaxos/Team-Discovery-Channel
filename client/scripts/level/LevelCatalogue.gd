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


static func all_modules() -> PackedStringArray:
	return MODULES + VERTICAL_MODULES
