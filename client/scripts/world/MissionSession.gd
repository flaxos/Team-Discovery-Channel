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


signal player_traveled(peer_id: int, from_world: Node, to_world: Node)


## Gathers an operative's carried state before removing them from a world.
func capture_state(player: PlayerController3D) -> Dictionary:
	var state: Dictionary = {
		"peer_id": player.peer_id,
		"class_id": player.class_id,
		"player_callsign": player.player_callsign,
		"active_slot": player.active_slot,
		"primary_weapon_id": player.primary_weapon_id,
		"secondary_weapon_id": player.secondary_weapon_id,
		"turret_cooldown": player.turret_cooldown,
		"claymore_charges": player.claymore_charges,
		"c4_charges_remaining": player.c4_charges_remaining,
		"is_carrying_patch_rom": player.is_carrying_patch_rom,
		"weapons": {}
	}
	var health: HealthComponent = player.health_component
	if health != null:
		state["health"] = health.current_health
		state["max_health"] = health.max_health
		state["is_downed"] = health.is_downed
		state["is_dead"] = health.is_dead
		state["is_stunned"] = health.is_stunned
		state["stun_timer"] = health.stun_timer
		state["bleedout_timer"] = health.bleedout_timer
	if player.current_weapon != null:
		state["weapons"][player.current_weapon.weapon_id] = {
			"current_ammo": player.current_weapon.current_ammo,
			"reserve_ammo": player.current_weapon.reserve_ammo,
			"current_heat": player.current_weapon.current_heat,
			"is_overheated": player.current_weapon.is_overheated,
			"is_reloading": player.current_weapon.is_reloading
		}
	for wid: String in player._weapon_inventory:
		var w: WeaponBase = player._weapon_inventory[wid] as WeaponBase
		if is_instance_valid(w) and not state["weapons"].has(wid):
			state["weapons"][wid] = {
				"current_ammo": w.current_ammo,
				"reserve_ammo": w.reserve_ammo,
				"current_heat": w.current_heat,
				"is_overheated": w.is_overheated,
				"is_reloading": w.is_reloading
			}
	return state


## Applies captured state to a newly spawned operative in the destination world.
func apply_state(player: PlayerController3D, state: Dictionary) -> void:
	if state.has("class_id") and player.class_id != state["class_id"]:
		player.class_id = state["class_id"]
	if state.has("player_callsign"):
		player.player_callsign = state["player_callsign"]
	var health: HealthComponent = player.health_component
	if health != null:
		if state.has("max_health"):
			health.max_health = state["max_health"]
		if state.has("health"):
			health.current_health = state["health"]
		if state.get("is_downed", false):
			health.is_downed = true
			health.bleedout_timer = state.get("bleedout_timer", 30.0)
		if state.get("is_stunned", false):
			health.is_stunned = true
			health.stun_timer = state.get("stun_timer", 0.0)
		health.health_changed.emit(health.current_health, health.max_health)
		health._publish_state()
	if state.has("weapons"):
		for wid: String in state["weapons"]:
			var w_data: Dictionary = state["weapons"][wid]
			if not player._weapon_inventory.has(wid):
				player._equip_weapon_by_id(wid)
			var w: WeaponBase = player._weapon_inventory.get(wid) as WeaponBase
			if is_instance_valid(w):
				w.current_ammo = w_data.get("current_ammo", w.current_ammo)
				w.reserve_ammo = w_data.get("reserve_ammo", w.reserve_ammo)
				w.current_heat = w_data.get("current_heat", w.current_heat)
				w.is_overheated = w_data.get("is_overheated", false)
				w.is_reloading = false
	if state.has("active_slot"):
		player._equip_slot_local(state["active_slot"])
	if player.current_weapon != null:
		player.weapon_ammo_changed.emit(player.current_weapon.current_ammo, player.current_weapon.reserve_ammo)
	player._broadcast_weapon_state()
	player.turret_cooldown = state.get("turret_cooldown", 0.0)
	player.claymore_charges = state.get("claymore_charges", player.claymore_charges)
	player.c4_charges_remaining = state.get("c4_charges_remaining", player.c4_charges_remaining)
	player.is_carrying_patch_rom = state.get("is_carrying_patch_rom", false)


## Moves one operative from its current world to the destination world.
func travel_player(player: PlayerController3D, from_world: Node = null) -> void:
	if not multiplayer.is_server() or player == null or worlds.size() < 2:
		return
	var peer_id: int = player.peer_id
	if from_world == null:
		from_world = world_of(peer_id)
	var to_world: Node = worlds[1] if from_world == home() else home()
	if to_world == from_world:
		return
	var state: Dictionary = capture_state(player)

	# Despawn from from_world
	var players_container: Node3D = from_world.get("players_container") as Node3D
	if players_container != null and players_container.has_node(str(peer_id)):
		players_container.remove_child(player)
		player.queue_free()

	# Record new world placement
	place(peer_id, to_world)

	# Spawn in to_world at its spawn point
	var spawns_container: Node3D = to_world.get("spawns_container") as Node3D
	var spawn_points: Array[Node] = spawns_container.get_children() if spawns_container != null else []
	var spawn_pos: Vector3 = (spawn_points[0] as Node3D).global_position if not spawn_points.is_empty() else to_world.global_position
	to_world.call(&"_spawn_player", peer_id, state.get("class_id", SGCNetworkManager.CLASS_SG3_HEAVY), spawn_pos)

	var target_players: Node3D = to_world.get("players_container") as Node3D
	if target_players != null:
		var new_player := target_players.get_node_or_null(str(peer_id)) as PlayerController3D
		if new_player != null:
			apply_state(new_player, state)

	# Synchronize presentation switch to the travelling client
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer_id):
		sync_presentation_change.rpc_id(peer_id, worlds.find(to_world))
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id == local_id:
		present(to_world)

	squad_changed()
	player_traveled.emit(peer_id, from_world, to_world)


@rpc("authority", "call_local", "reliable")
func sync_presentation_change(world_index: int) -> void:
	if world_index >= 0 and world_index < worlds.size():
		present(worlds[world_index])


func abort_mission() -> void:
	if not multiplayer.is_server():
		return
	finish(false)
