@tool
class_name LevelModuleInstance
extends Resource
@export var id: StringName
@export var module: LevelModuleDefinition
@export var deck: StringName = &"deck0"
@export var transport_endpoints: Array[LevelTransportEndpoint] = []
@export var socket_decks: Dictionary = {}
@export var position := Vector2.ZERO
@export_range(0, 3) var quarter_turn: int = 0
@export var available_sockets: PackedStringArray = []
@export var tags: PackedStringArray = []
@export var style: StringName = &"neutral"
@export var room_preset: LevelRoomPreset
@export var attachment_overrides: Array[LevelRoomOverride] = []
@export var theme: LevelVisualTheme
@export var role: StringName = &""


func placement(elevation: float) -> Transform3D:
	return Transform3D(
		Basis(Vector3.UP, quarter_turn * PI / 2), Vector3(position.x, elevation, position.y)
	)


func allows(socket_id: StringName) -> bool:
	return available_sockets.is_empty() or str(socket_id) in available_sockets


func socket_deck(socket_id: StringName) -> StringName:
	if socket_decks.has(str(socket_id)):
		return StringName(socket_decks[str(socket_id)])
	var socket := module.socket(socket_id) if module != null else null
	return deck if socket != null and absf(socket.local_transform.origin.y) < 0.001 else &""


func bind_matching_decks(decks: Dictionary) -> void:
	for socket in module.sockets:
		if socket_deck(socket.id) != &"":
			continue
		var elevation := float(decks.get(str(deck), 0.0)) + socket.local_transform.origin.y
		var matches: Array[String] = []
		for key: String in decks:
			if absf(float(decks[key]) - elevation) < 0.001:
				matches.append(key)
		if matches.size() == 1:
			socket_decks[str(socket.id)] = matches[0]
