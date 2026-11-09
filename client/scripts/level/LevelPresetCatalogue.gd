@tool
class_name LevelPresetCatalogue
extends RefCounted
const PRESETS: PackedStringArray = [
	"jaffa_barracks",
	"security_checkpoint",
	"armoury",
	"detention",
	"generator",
	"cargo",
	"engineering",
	"security_control",
	"ring_transport",
	"stargate_dhd",
	"sarcophagus",
	"laboratory_medical",
	"command",
	"cargo_hangar",
	"ceremonial",
	"observation_communications"
]


static func preset(id: String) -> LevelRoomPreset:
	return load("res://resources/room_presets/" + id + ".tres") as LevelRoomPreset
