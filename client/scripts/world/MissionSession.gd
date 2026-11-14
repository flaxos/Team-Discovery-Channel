class_name MissionSession
extends Node
## One mission played across more than one world (docs/plans/gate-travel-split-worlds.md).
## It records which world each peer's operative is in, applies the rule for losing the
## mission, and decides which world this peer presents. A single-world mission has no
## session and behaves exactly as it did.
##
## Worlds are untyped here so that this script and GateRoom do not name each other.
signal presented_changed(world: Node)

## Home first. A world's operatives start at home unless placed elsewhere.
var worlds: Array[Node] = []
## Host only: peer id -> the world its operative belongs in.
var placement: Dictionary = {}
var result: int = -1
var presented: Node = null
const SHADOW_SETTLE_S := 1.5
var _settling := false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id: int) -> void: placement.erase(id))


func add_world(world: Node) -> void:
	worlds.append(world)
	world.set(&"session", self)


func home() -> Node:
	return null if worlds.is_empty() else worlds[0]


func world_of(peer_id: int) -> Node:
	var world: Variant = placement.get(peer_id)
	return world as Node if is_instance_valid(world) else home()


func place(peer_id: int, world: Node) -> void:
	placement[peer_id] = world


## Draw and hear `world` on this peer and hide the others. Every world keeps simulating.
func present(world: Node) -> void:
	presented = world
	for item in worlds:
		item.call(&"set_presented", item == world)
	presented_changed.emit(world)
	_settle_shadows()


## Loading two worlds can leave the engine's shadow atlas in an allocation it never leaves,
## in which every shadowed light is redrawn every frame (measured in the SGC: 3,938 objects
## drawn a frame instead of 472). Rebuilding the atlas once the view has settled clears it.
func _settle_shadows() -> void:
	if DisplayServer.get_name() == "headless" or _settling:
		return
	_settling = true
	await get_tree().create_timer(SHADOW_SETTLE_S).timeout
	_settling = false
	var viewport := get_viewport()
	if viewport == null:
		return
	var size := viewport.positional_shadow_atlas_size
	if size > 0:
		viewport.positional_shadow_atlas_size = size / 2
		viewport.positional_shadow_atlas_size = size


## Decision D-017: the mission is lost when every operative, in every world, is down.
## A world with no operatives in it does not count either way.
func squad_changed() -> void:
	if result >= 0 or not multiplayer.is_server():
		return
	var operatives := 0
	var standing := 0
	for world in worlds:
		var state: Vector2i = world.call(&"squad_state")
		operatives += state.x
		standing += state.y
	if operatives > 0 and standing == 0:
		finish(false)


## One result for the whole mission, shown in every world.
func finish(victory: bool) -> void:
	if result >= 0:
		return
	result = 1 if victory else 0
	for world in worlds:
		world.call(&"_finish_mission", victory)
