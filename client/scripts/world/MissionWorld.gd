class_name MissionWorld
extends RefCounted
## Finds the world an actor belongs to. A world is one self-contained place (the SGC, an
## offworld site) and two can be loaded side by side: docs/plans/gate-travel-split-worlds.md.
## An actor looks for its surroundings through these functions, never by searching the whole
## game: `get_tree().root.find_child("Players", ...)` returns whichever world loaded first.
##
## The functions do not name this class: a script that names its own class from a static
## function is never freed.
const GROUP := &"mission_world"


## The nearest ancestor of `node` (or `node` itself) that is a world. Outside any world it
## is the top of the game, so a bare scene in a test behaves as it always did.
static func of(node: Node) -> Node:
	var at := node
	while at != null:
		if at.is_in_group(GROUP):
			return at
		at = at.get_parent()
	return node.get_tree().root if node != null and node.is_inside_tree() else null


## A node by name in the actor's own world. A world answers to "GateRoom" itself.
static func find(node: Node, wanted: String) -> Node:
	var world := of(node)
	if world == null:
		return null
	if wanted == "GateRoom" and world.is_in_group(GROUP):
		return world
	return world.find_child(wanted, true, false)


## The members of a group that an actor can meet: those in its own world and those in no
## world. With one world loaded that is every member, as before.
static func in_group(node: Node, group: StringName) -> Array[Node]:
	var found: Array[Node] = []
	if node == null or not node.is_inside_tree():
		return found
	var members := node.get_tree().get_nodes_in_group(group)
	var mine := of(node)
	if node.get_tree().get_nodes_in_group(GROUP).size() < 2 or not mine.is_in_group(GROUP):
		found.assign(members)
		return found
	for member in members:
		var theirs := of(member)
		if theirs == mine or not theirs.is_in_group(GROUP):
			found.append(member)
	return found


## A point in the game's space as a `position` under `parent`. A world can stand far from
## the origin, so a node spawned into one must not be given a game position as its own.
static func local(parent: Node, point: Vector3) -> Vector3:
	var space := parent as Node3D
	return space.to_local(point) if space != null and space.is_inside_tree() else point


static func first_in_group(node: Node, group: StringName) -> Node:
	var members := in_group(node, group)
	return null if members.is_empty() else members[0]


## Whether this peer draws and hears the actor's world. Sound that has no position asks.
static func presented(node: Node) -> bool:
	var world := of(node)
	return world == null or not world.is_in_group(GROUP) or bool(world.get(&"is_presented"))
