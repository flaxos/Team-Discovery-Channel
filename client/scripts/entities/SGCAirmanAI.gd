class_name SGCAirmanAI
extends CharacterBody3D
## SGC Airman AI Base Defender Fireteam.
## Spawns in Armory / Staging corridors on Sublevel 28, scrambles to the Gate Room upon Red Alert,
## returns fire with MP5 bursts, mounts unmanned .50 Cal turrets, holds tactical corners & sandbag lines,
## peeks to lay down suppressive hallway fire, and coordinates player-led leapfrog bounding overwatch.

signal airman_downed(airman: SGCAirmanAI)
signal airman_revived(airman: SGCAirmanAI)
signal airman_died(airman: SGCAirmanAI)
signal turret_mounted(turret: DeployableTurret)
signal turret_dismounted(turret: DeployableTurret)
signal order_acknowledged(airman: SGCAirmanAI, order_type: String)
signal corner_held(airman: SGCAirmanAI, anchor_pos: Vector3)
signal leapfrog_started(airman: SGCAirmanAI, target_pos: Vector3)
signal leapfrog_completed(airman: SGCAirmanAI, anchor_pos: Vector3)
signal hallway_suppressed(airman: SGCAirmanAI, hallway_dir: Vector3)

enum State {
	STAGING,
	SCRAMBLE,
	COMBAT,
	MAN_TURRET,
	REVIVE_PLAYER,
	MOVE_TO_TURRET,
	ORDER_MOVE,
	ORDER_REGROUP,
	DOWNED,
	DEAD,
	HOLD_CORNER,
	LEAPFROG_ADVANCE,
	COVER_FIRE
}

@export var airman_callsign: String = "AIRMAN DAVIS"
@export var move_speed: float = 5.2
@export var weapon_damage: float = 22.0
@export var fire_rate_rpm: float = 600.0
@export var combat_range: float = 22.0
@export var tactical_reach_turret_dist: float = 8.0
@export var peeking_burst_duration: float = 1.2
@export var peeking_cooldown_duration: float = 0.8

var current_state: State = State.STAGING
var fire_cooldown: float = 0.0
var revive_channel_time: float = 0.0
const REVIVE_DURATION_S: float = 2.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var is_in_cover: bool = false
var is_crouching: bool = false
var is_peeking: bool = false
var peek_timer: float = 0.0
var is_suppressing: bool = false
var suppress_timer: float = 0.0
var current_aim_target: Vector3 = Vector3.ZERO

var current_anchor_position: Vector3 = Vector3.ZERO
var current_anchor_facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var current_anchor_type: String = "corner"

var target_advance_position: Vector3 = Vector3.ZERO
var target_advance_facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var is_leapfrogging_advancing: bool = false
var is_providing_cover_fire: bool = false
var is_hallway_secured: bool = false

var current_scramble_waypoint_index: int = 0
const SCRAMBLE_WAYPOINTS: Array[Vector3] = [
	Vector3(35.0, 0.1, 36.0),   # Armory doorway
	Vector3(26.0, 0.1, 36.0),   # Round Hallway rotunda
	Vector3(24.0, 0.1, 18.0),   # Elevator Lobby
	Vector3(22.5, 0.1, 8.0),    # East Corridor entrance
	Vector3(18.0, 0.1, 4.0),    # BlastDoorsEast portal
	Vector3(5.0, 0.1, 4.0)      # Gate Room defense line
]

const TACTICAL_ANCHORS: Array[Dictionary] = [
	# Gate Room Arena & Sandbags
	{"pos": Vector3(-5.0, 0.1, 5.8), "dir": Vector3(0.0, 0.0, -1.0), "sector": "GATE_ROOM", "type": "sandbag"},
	{"pos": Vector3(2.5, 0.1, 5.8), "dir": Vector3(0.0, 0.0, -1.0), "sector": "GATE_ROOM", "type": "sandbag"},
	{"pos": Vector3(0.0, 0.1, 1.8), "dir": Vector3(0.0, 0.0, -1.0), "sector": "GATE_ROOM", "type": "sandbag"},
	{"pos": Vector3(3.8, 0.1, 7.8), "dir": Vector3(0.0, 0.0, 1.0), "sector": "GATE_ROOM", "type": "doorway_jamb"},
	{"pos": Vector3(6.2, 0.1, 7.8), "dir": Vector3(0.0, 0.0, 1.0), "sector": "GATE_ROOM", "type": "doorway_jamb"},
	{"pos": Vector3(18.0, 0.1, 4.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "GATE_ROOM", "type": "doorway_jamb"},
	{"pos": Vector3(-18.0, 0.1, 4.0), "dir": Vector3(-1.0, 0.0, 0.0), "sector": "GATE_ROOM", "type": "doorway_jamb"},
	# Control Room
	{"pos": Vector3(5.0, 0.1, 8.5), "dir": Vector3(0.0, 0.0, -1.0), "sector": "CONTROL_ROOM", "type": "corner"},
	{"pos": Vector3(5.0, 0.1, 14.0), "dir": Vector3(0.0, 0.0, 1.0), "sector": "CONTROL_ROOM", "type": "corner"},
	{"pos": Vector3(12.0, 0.1, 15.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "CONTROL_ROOM", "type": "doorway_jamb"},
	{"pos": Vector3(0.0, 0.1, 21.0), "dir": Vector3(0.0, 0.0, 1.0), "sector": "CONTROL_ROOM", "type": "doorway_jamb"},
	# Fallback Hallway
	{"pos": Vector3(0.0, 0.1, 23.0), "dir": Vector3(0.0, 0.0, -1.0), "sector": "FALLBACK_HALLWAY", "type": "doorway_jamb"},
	{"pos": Vector3(2.5, 0.1, 28.0), "dir": Vector3(0.0, 0.0, 1.0), "sector": "FALLBACK_HALLWAY", "type": "corner"},
	{"pos": Vector3(-1.5, 0.1, 35.8), "dir": Vector3(0.0, 0.0, -1.0), "sector": "FALLBACK_HALLWAY", "type": "sandbag"},
	{"pos": Vector3(2.5, 0.1, 35.5), "dir": Vector3(1.0, 0.0, 0.0), "sector": "FALLBACK_HALLWAY", "type": "corner"},
	# Connector Tunnel
	{"pos": Vector3(5.0, 0.1, 36.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "CONNECTOR_TUNNEL", "type": "doorway_jamb"},
	{"pos": Vector3(11.5, 0.1, 36.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "CONNECTOR_TUNNEL", "type": "corner"},
	{"pos": Vector3(17.5, 0.1, 36.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "CONNECTOR_TUNNEL", "type": "doorway_jamb"},
	# Round Hallway
	{"pos": Vector3(20.0, 0.1, 36.0), "dir": Vector3(-1.0, 0.0, 0.0), "sector": "ROUND_HALLWAY", "type": "corner"},
	{"pos": Vector3(26.0, 0.1, 36.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "ROUND_HALLWAY", "type": "corner"},
	{"pos": Vector3(24.0, 0.1, 22.0), "dir": Vector3(0.0, 0.0, -1.0), "sector": "ROUND_HALLWAY", "type": "doorway_jamb"},
	{"pos": Vector3(34.0, 0.1, 36.0), "dir": Vector3(1.0, 0.0, 0.0), "sector": "ROUND_HALLWAY", "type": "doorway_jamb"},
	# East Corridor
	{"pos": Vector3(18.5, 0.1, 4.0), "dir": Vector3(-1.0, 0.0, 0.0), "sector": "EAST_CORRIDOR", "type": "doorway_jamb"},
	{"pos": Vector3(22.5, 0.1, 6.0), "dir": Vector3(0.0, 0.0, 1.0), "sector": "EAST_CORRIDOR", "type": "corner"},
	{"pos": Vector3(22.5, 0.1, 9.6), "dir": Vector3(0.0, 0.0, 1.0), "sector": "EAST_CORRIDOR", "type": "doorway_jamb"},
	# Elevator Lobby
	{"pos": Vector3(22.5, 0.1, 10.5), "dir": Vector3(0.0, 0.0, -1.0), "sector": "ELEVATOR_LOBBY", "type": "corner"},
	{"pos": Vector3(24.0, 0.1, 18.0), "dir": Vector3(0.0, 0.0, 1.0), "sector": "ELEVATOR_LOBBY", "type": "corner"},
	# Armory
	{"pos": Vector3(36.0, 0.1, 36.0), "dir": Vector3(-1.0, 0.0, 0.0), "sector": "ARMORY", "type": "doorway_jamb"},
	{"pos": Vector3(42.0, 0.1, 34.0), "dir": Vector3(-1.0, 0.0, 0.0), "sector": "ARMORY", "type": "corner"}
]

var mounted_turret: DeployableTurret = null
var current_target_jaffa: JaffaAI = null
var target_player_to_revive: CharacterBody3D = null
var target_turret_to_mount: DeployableTurret = null
var ordered_position: Vector3 = Vector3.ZERO
var order_leader: CharacterBody3D = null
var current_sector: String = "GATE_ROOM"

@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var body_mesh: Node3D = $Visuals/BodyMesh if has_node("Visuals/BodyMesh") else null
@onready var nameplate: Label3D = $Nameplate if has_node("Nameplate") else null


func _enter_tree() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and has_node("MultiplayerSynchronizer"):
		net.configure_mission_sync($MultiplayerSynchronizer)


func _ready() -> void:
	add_to_group("allies")
	add_to_group("airmen")

	if health_component != null:
		health_component.max_health = 100.0
		health_component.current_health = 100.0
		health_component.can_be_downed = true
		health_component.downed.connect(_on_downed)
		health_component.revived.connect(_on_revived)
		health_component.died.connect(_on_died)

	if nameplate != null:
		nameplate.text = airman_callsign

	current_sector = _get_current_sector()


func scramble_to_gate_room() -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	current_scramble_waypoint_index = 0
	current_state = State.SCRAMBLE
	print("SGCAirmanAI [%s]: Scrambling to Gate Room! Engaging hostiles!" % airman_callsign)


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if suppress_timer > 0.0:
		suppress_timer -= delta
		if suppress_timer <= 0.0:
			is_suppressing = false

	current_sector = _get_current_sector()

	# Universal priority 1: Check if any downed operative needs emergency revive
	if current_state != State.DOWNED and current_state != State.DEAD and current_state != State.REVIVE_PLAYER:
		var downed_player: PlayerController3D = _find_nearest_downed_player()
		if downed_player != null:
			target_player_to_revive = downed_player
			if mounted_turret != null:
				dismount_turret()
			current_state = State.REVIVE_PLAYER
			revive_channel_time = 0.0
			is_leapfrogging_advancing = false
			is_providing_cover_fire = false
			print("SGCAirmanAI [%s]: Squadmate down! Providing covering fire and moving to revive!" % airman_callsign)

	# Universal priority 2: Check for uncrewed .50 Cal turret within tactical reach (~8.0m)
	if mounted_turret == null and current_state != State.DOWNED and current_state != State.DEAD and current_state != State.REVIVE_PLAYER and current_state != State.ORDER_MOVE and current_state != State.ORDER_REGROUP:
		var available_turret: DeployableTurret = _find_available_turret()
		if available_turret != null:
			var d_tur: float = global_position.distance_to(available_turret.global_position)
			if d_tur <= tactical_reach_turret_dist:
				if d_tur <= 2.0:
					mount_turret(available_turret)
				elif current_state != State.MOVE_TO_TURRET:
					target_turret_to_mount = available_turret
					current_state = State.MOVE_TO_TURRET

	match current_state:
		State.STAGING:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		State.SCRAMBLE:
			_process_scramble(delta)
		State.COMBAT:
			_process_combat(delta)
		State.MAN_TURRET:
			_process_turret(delta)
		State.REVIVE_PLAYER:
			_process_revive(delta)
		State.MOVE_TO_TURRET:
			_process_move_to_turret(delta)
		State.ORDER_MOVE:
			_process_order_move(delta)
		State.ORDER_REGROUP:
			_process_order_regroup(delta)
		State.DOWNED:
			_process_downed_crawl(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		State.HOLD_CORNER:
			_process_hold_corner(delta)
		State.LEAPFROG_ADVANCE:
			_process_leapfrog_advance(delta)
		State.COVER_FIRE:
			_process_cover_fire(delta)

	move_and_slide()


func _process_scramble(delta: float) -> void:
	if current_scramble_waypoint_index >= SCRAMBLE_WAYPOINTS.size():
		current_state = State.COMBAT
		return

	var wp: Vector3 = SCRAMBLE_WAYPOINTS[current_scramble_waypoint_index]
	var to_wp: Vector3 = (wp - global_position)
	to_wp.y = 0.0

	if to_wp.length() < 1.5:
		current_scramble_waypoint_index += 1
		if current_scramble_waypoint_index >= SCRAMBLE_WAYPOINTS.size():
			current_state = State.COMBAT
			return
		wp = SCRAMBLE_WAYPOINTS[current_scramble_waypoint_index]
		to_wp = (wp - global_position)
		to_wp.y = 0.0

	var dir: Vector3 = to_wp.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	rotation.y = atan2(-dir.x, -dir.z)


func _is_target_obscured_by_smoke(target_pos: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var seg_start: Vector3 = global_position + Vector3(0.0, 1.3, 0.0)
	var seg_end: Vector3 = target_pos + Vector3(0.0, 1.0, 0.0)
	var seg_dir: Vector3 = (seg_end - seg_start)
	var seg_len_sq: float = seg_dir.length_squared()
	if seg_len_sq < 0.001:
		return false

	var smoke_nodes: Array[Node] = get_tree().get_nodes_in_group("smoke_cloud")
	for node: Node in smoke_nodes:
		var cloud: Area3D = node as Area3D
		if cloud != null and is_instance_valid(cloud):
			var cloud_pos: Vector3 = cloud.global_position
			var t: float = clampf((cloud_pos - seg_start).dot(seg_dir) / seg_len_sq, 0.0, 1.0)
			var closest_pt: Vector3 = seg_start + seg_dir * t
			if closest_pt.distance_to(cloud_pos) <= 4.5:
				return true
	return false


func _has_line_of_sight(target: Node3D) -> bool:
	if target == null or not is_inside_tree() or not target.is_inside_tree():
		return false
	if _is_target_obscured_by_smoke(target.global_position):
		return false

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return false

	var from: Vector3 = global_position + Vector3(0.0, 1.4, 0.0)
	if mounted_turret != null and is_instance_valid(mounted_turret):
		from = mounted_turret.global_position + Vector3(0.0, 1.0, 0.0)

	var exclude_list: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude_list.append((target as CollisionObject3D).get_rid())

	# Test both head and torso for clear unoccluded LOS
	var test_points: Array[Vector3] = [
		target.global_position + Vector3(0.0, 1.5, 0.0),  # Head
		target.global_position + Vector3(0.0, 1.0, 0.0)   # Torso
	]
	var health: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and health.is_downed:
		test_points.append(target.global_position + Vector3(0.0, 0.35, 0.0))

	for to: Vector3 in test_points:
		if _cast_los_ray(space, from, to, exclude_list.duplicate()):
			return true

	return false


func _cast_los_ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude_list: Array[RID]) -> bool:
	for iter: int in range(3):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1  # Blocked only by World walls/doors
		query.exclude = exclude_list
		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			return true
		var col: Node = result.get("collider") as Node
		if col != null and (col.name.contains("Glass") or col.name.contains("Overlook")):
			if result.has("rid"):
				exclude_list.append(result["rid"] as RID)
			continue
		return false
	return false


func _get_hallway_destination(target_pos: Vector3) -> Vector3:
	# 1. Target in East Wing (Armory / Elevator Lobby / Round Hallway / Lab / East Corridor)
	if target_pos.x >= 16.0:
		if global_position.x < 17.0 and global_position.z <= 8.0:
			return Vector3(18.0, 0.1, 4.0)   # Head to East Blast Door
		elif global_position.x >= 17.0 and global_position.z < 9.6:
			return Vector3(22.5, 0.1, 8.0)   # Head through East Corridor
		elif global_position.z >= 8.0 and global_position.z < 24.0:
			if target_pos.x >= 35.0 or target_pos.z >= 24.0:
				return Vector3(24.0, 0.1, 22.0) # Head into Round Hallway
			else:
				return target_pos
		elif global_position.z >= 24.0 and global_position.x < 35.0:
			if target_pos.x >= 35.0:
				return Vector3(35.0, 0.1, 36.0) # Head into Armory
			elif target_pos.z >= 45.0:
				return Vector3(26.0, 0.1, 46.0) # Head into Lab
			else:
				return target_pos
		elif global_position.x >= 35.0:
			return target_pos

	# 2. Target in Fallback Hallway (South of Control Room)
	elif target_pos.z >= 20.0 and absf(target_pos.x) <= 6.0:
		if global_position.z <= 8.0:
			return Vector3(5.0, 0.75, 8.5)   # Enter Control Room North ramp
		elif global_position.z > 8.0 and global_position.z < 14.0:
			return Vector3(5.0, 0.75, 14.0)  # Aisle past dialing consoles
		elif global_position.z >= 14.0 and global_position.z < 22.0:
			return Vector3(0.0, 0.75, 22.0)  # Head to Central Blast Door
		elif global_position.z >= 22.0 and global_position.z < 28.0:
			return Vector3(2.5, 0.1, 28.0)   # Fallback Hallway
		else:
			return target_pos

	# 3. Target in Control Room
	elif absf(target_pos.x) <= 7.5 and target_pos.z >= 7.8 and target_pos.z <= 22.0:
		if global_position.z <= 8.0:
			return Vector3(5.0, 0.75, 8.5)   # North ramp into Control Room
		elif global_position.z > 8.0 and global_position.z < 14.0:
			return Vector3(5.0, 0.75, 14.0)  # Aisle past dialing consoles
		else:
			return target_pos

	# 4. Target in Gate Room Arena
	elif target_pos.z <= 8.0 and target_pos.x < 17.0:
		if global_position.x >= 35.0:
			return Vector3(35.0, 0.1, 36.0)   # Exit Armory
		elif global_position.z >= 24.0 and global_position.x >= 17.0:
			return Vector3(24.0, 0.1, 22.0)   # Round Hallway to Elevator Lobby
		elif global_position.z >= 9.6 and global_position.x >= 17.0:
			return Vector3(22.5, 0.1, 8.0)    # Elevator Lobby to East Corridor
		elif global_position.x >= 17.0 and global_position.z < 9.6:
			return Vector3(18.0, 0.1, 4.0)    # East Corridor into Gate Room
		elif global_position.z >= 22.0 and absf(global_position.x) <= 6.0:
			return Vector3(0.0, 0.75, 22.0)   # Exit Fallback Hallway
		elif global_position.z > 8.0 and global_position.z < 22.0 and absf(global_position.x) <= 7.5:
			if global_position.z > 14.0:
				return Vector3(5.0, 0.75, 14.0)
			else:
				return Vector3(5.0, 0.75, 8.5) # Down ramp into Gate Room

	return target_pos


func _process_combat(delta: float) -> void:
	# Check if an anchor point is available nearby to hold
	var best_anchor: Dictionary = find_best_tactical_anchor()
	if not best_anchor.is_empty():
		var anchor_pos: Vector3 = best_anchor["pos"] as Vector3
		var d_anchor: float = global_position.distance_to(anchor_pos)
		if d_anchor <= 14.0:
			if d_anchor <= 0.8:
				hold_corner(anchor_pos, best_anchor["dir"] as Vector3, str(best_anchor.get("type", "corner")))
				return
			else:
				var move_dest: Vector3 = _get_hallway_destination(anchor_pos)
				var to_dest: Vector3 = (move_dest - global_position)
				to_dest.y = 0.0
				var dir: Vector3 = to_dest.normalized()
				velocity.x = dir.x * (move_speed * 0.8)
				velocity.z = dir.z * (move_speed * 0.8)
				rotation.y = atan2(-dir.x, -dir.z)
				return

	# Acquire target Jaffa (filtered by line of sight)
	_find_nearest_jaffa()
	if current_target_jaffa == null or not _has_line_of_sight(current_target_jaffa):
		# Hold tactical line without aiming or shooting into walls
		if velocity.length_squared() > 0.05:
			rotation.y = atan2(-velocity.x, -velocity.z)
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		return

	var dist: float = global_position.distance_to(current_target_jaffa.global_position)
	var aim_dir: Vector3 = (current_target_jaffa.global_position - global_position)
	aim_dir.y = 0.0
	if _has_line_of_sight(current_target_jaffa):
		if aim_dir.length_squared() > 0.01:
			rotation.y = atan2(-aim_dir.x, -aim_dir.z)
	elif velocity.length_squared() > 0.05:
		rotation.y = atan2(-velocity.x, -velocity.z)

	if dist > 8.0:
		# Advance toward sandbag line
		velocity.x = aim_dir.normalized().x * (move_speed * 0.7)
		velocity.z = aim_dir.normalized().z * (move_speed * 0.7)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	# Fire MP5 bursts at Jaffa
	if fire_cooldown <= 0.0 and dist <= combat_range and _has_line_of_sight(current_target_jaffa):
		fire_cooldown = 60.0 / fire_rate_rpm
		_fire_mp5(aim_dir.normalized())


func _fire_mp5(dir: Vector3) -> void:
	var origin: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * combat_range)
	query.collision_mask = 1 | 4  # World and Jaffa
	query.exclude = [get_rid()]

	var result: Dictionary = space.intersect_ray(query)
	var hit_pos: Vector3 = origin + dir * combat_range
	if not result.is_empty():
		hit_pos = result["position"] as Vector3
		var col: Node = result["collider"] as Node
		if col != null:
			var health: HealthComponent = col.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(weapon_damage, self, "bullet")

	rpc("play_mp5_fx", origin, hit_pos)


@rpc("call_local", "unreliable")
func play_mp5_fx(from: Vector3, to: Vector3) -> void:
	var tracer: MeshInstance3D = MeshInstance3D.new()
	var imm: ImmediateMesh = ImmediateMesh.new()
	tracer.mesh = imm

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.4, 0.9)
	tracer.material_override = mat
	get_tree().root.add_child(tracer)

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(from)
	imm.surface_add_vertex(to)
	imm.surface_end()

	var tween: Tween = tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(tracer.queue_free)


func _process_turret(delta: float) -> void:
	if mounted_turret == null or not is_instance_valid(mounted_turret):
		current_state = State.COMBAT
		return

	# If a player approaches within 2.2m of turret, politely dismount so player can use it
	var players_container: Node = get_tree().root.find_child("Players", true, false)
	if players_container != null:
		for child: Node in players_container.get_children():
			var p: PlayerController3D = child as PlayerController3D
			if p != null and not p.health_component.is_dead:
				var dist_to_turret: float = mounted_turret.global_position.distance_to(p.global_position)
				var dist_to_airman: float = global_position.distance_to(p.global_position)
				if dist_to_turret <= 2.2 or dist_to_airman <= 2.2:
					print("SGCAirmanAI [%s]: Yielding .50 Cal to operative %s!" % [airman_callsign, p.name])
					dismount_turret()
					return

	# Acquire target down the ramp or corridor
	_find_nearest_jaffa()
	if current_target_jaffa != null and _has_line_of_sight(current_target_jaffa):
		var target_pos: Vector3 = current_target_jaffa.global_position + Vector3(0.0, 1.0, 0.0)
		var aim_dir: Vector3 = (target_pos - mounted_turret.global_position).normalized()
		current_aim_target = target_pos
		if mounted_turret.turret_head != null:
			mounted_turret.turret_head.look_at(target_pos, Vector3.UP)
		var fired: bool = mounted_turret.try_manual_fire(aim_dir)
		if fired:
			hallway_suppressed.emit(self, aim_dir)
	elif is_suppressing and suppress_timer > 0.0:
		var sup_dir: Vector3 = -mounted_turret.global_transform.basis.z
		current_aim_target = mounted_turret.global_position + sup_dir * 20.0
		if mounted_turret.turret_head != null:
			mounted_turret.turret_head.look_at(mounted_turret.global_position + sup_dir * 10.0, Vector3.UP)
		var fired: bool = mounted_turret.try_manual_fire(sup_dir)
		if fired:
			hallway_suppressed.emit(self, sup_dir)


func mount_turret(turret: DeployableTurret) -> void:
	if turret == null or turret.mounted_player != null:
		return
	mounted_turret = turret
	if turret.has_method("mount_airman"):
		turret.mount_airman(self)
	else:
		turret.mount(self)
	current_state = State.MAN_TURRET
	global_position = turret.global_position + turret.global_transform.basis.z * 0.75
	is_in_cover = true
	is_crouching = false
	is_peeking = true
	turret_mounted.emit(turret)
	print("SGCAirmanAI [%s]: Manning .50 Cal Browning emplacement!" % airman_callsign)


func dismount_turret() -> void:
	if mounted_turret != null:
		var t: DeployableTurret = mounted_turret
		mounted_turret.dismount()
		mounted_turret = null
		current_state = State.COMBAT
		is_in_cover = false
		is_peeking = false
		turret_dismounted.emit(t)


func _process_revive(delta: float) -> void:
	if target_player_to_revive == null or not is_instance_valid(target_player_to_revive):
		target_player_to_revive = null
		current_state = State.COMBAT
		return

	var target_health: HealthComponent = target_player_to_revive.get_node_or_null("HealthComponent") as HealthComponent
	if target_health == null or not target_health.is_downed:
		target_player_to_revive = null
		current_state = State.COMBAT
		return

	var dist: float = global_position.distance_to(target_player_to_revive.global_position)
	if dist > 1.8:
		# Sprint to downed squadmate via hallway pathfinding
		var move_dest: Vector3 = _get_hallway_destination(target_player_to_revive.global_position)
		var to_dest: Vector3 = (move_dest - global_position)
		to_dest.y = 0.0
		var dir: Vector3 = to_dest.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		# In range: channel revive
		velocity = Vector3.ZERO
		revive_channel_time += delta
		if revive_channel_time >= REVIVE_DURATION_S:
			target_health.revive(self)
			print("SGCAirmanAI [%s]: Operative %s successfully REVIVED!" % [airman_callsign, target_player_to_revive.name])
			target_player_to_revive = null
			current_state = State.COMBAT


func order_move_to(pos: Vector3) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	if mounted_turret != null:
		dismount_turret()
	ordered_position = pos
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	current_state = State.ORDER_MOVE
	order_acknowledged.emit(self, "MOVE")
	print("SGCAirmanAI [%s]: Moving to position %s! Taking cover!" % [airman_callsign, str(pos)])


func order_mount_turret(turret: DeployableTurret) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED or turret == null:
		return
	if mounted_turret != null and mounted_turret != turret:
		dismount_turret()
	target_turret_to_mount = turret
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	var d: float = global_position.distance_to(turret.global_position)
	if d <= 2.2:
		mount_turret(turret)
	else:
		current_state = State.MOVE_TO_TURRET
	order_acknowledged.emit(self, "TURRET")
	print("SGCAirmanAI [%s]: Acknowledged, manning .50 Cal Browning!" % airman_callsign)


func order_revive(target: CharacterBody3D) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED or target == null:
		return
	if mounted_turret != null:
		dismount_turret()
	target_player_to_revive = target
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	current_state = State.REVIVE_PLAYER
	revive_channel_time = 0.0
	order_acknowledged.emit(self, "REVIVE")
	print("SGCAirmanAI [%s]: Squadmate down! Moving to revive!" % airman_callsign)


func order_regroup(leader: CharacterBody3D) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	if mounted_turret != null:
		dismount_turret()
	order_leader = leader
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	current_state = State.ORDER_REGROUP
	order_acknowledged.emit(self, "REGROUP")
	print("SGCAirmanAI [%s]: Regrouping on your six!" % airman_callsign)


func _process_move_to_turret(delta: float) -> void:
	if target_turret_to_mount == null or not is_instance_valid(target_turret_to_mount):
		current_state = State.COMBAT
		return
	if target_turret_to_mount.mounted_player != null and target_turret_to_mount.mounted_player != self:
		current_state = State.COMBAT
		return

	var dist: float = global_position.distance_to(target_turret_to_mount.global_position)
	if dist > 2.0:
		var move_dest: Vector3 = _get_hallway_destination(target_turret_to_mount.global_position)
		var to_dest: Vector3 = (move_dest - global_position)
		to_dest.y = 0.0
		var dir: Vector3 = to_dest.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		mount_turret(target_turret_to_mount)


func _process_order_move(delta: float) -> void:
	var dist: float = global_position.distance_to(ordered_position)
	var move_dest: Vector3 = _get_hallway_destination(ordered_position)
	var to_dest: Vector3 = (move_dest - global_position)
	to_dest.y = 0.0

	if dist > 1.2:
		var dir: Vector3 = to_dest.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
		if body_mesh != null:
			body_mesh.scale.y = 1.0
			body_mesh.position.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		if body_mesh != null:
			body_mesh.scale.y = 0.65
			body_mesh.position.y = 0.15

	# While moving or holding, return fire at any Jaffa in range only with clear line of sight
	_find_nearest_jaffa()
	if current_target_jaffa != null and _has_line_of_sight(current_target_jaffa):
		var jaffa_dist: float = global_position.distance_to(current_target_jaffa.global_position)
		if jaffa_dist <= combat_range and fire_cooldown <= 0.0:
			var aim_dir: Vector3 = (current_target_jaffa.global_position - global_position)
			aim_dir.y = 0.0
			if aim_dir.length_squared() > 0.01 and dist <= 1.2:
				rotation.y = atan2(-aim_dir.x, -aim_dir.z)
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_mp5(aim_dir.normalized())
	elif velocity.length_squared() > 0.05:
		rotation.y = atan2(-velocity.x, -velocity.z)


func _process_order_regroup(delta: float) -> void:
	if order_leader == null or not is_instance_valid(order_leader):
		current_state = State.COMBAT
		return

	var dist: float = global_position.distance_to(order_leader.global_position)
	var move_dest: Vector3 = _get_hallway_destination(order_leader.global_position)
	var to_dest: Vector3 = (move_dest - global_position)
	to_dest.y = 0.0

	if dist > 2.5:
		var dir: Vector3 = to_dest.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
		if body_mesh != null:
			body_mesh.scale.y = 1.0
			body_mesh.position.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		rotation.y = lerp_angle(rotation.y, order_leader.rotation.y, 8.0 * delta)

	# Cover fire only when clear line of sight is confirmed
	_find_nearest_jaffa()
	if current_target_jaffa != null and _has_line_of_sight(current_target_jaffa) and fire_cooldown <= 0.0:
		var jaffa_dist: float = global_position.distance_to(current_target_jaffa.global_position)
		if jaffa_dist <= combat_range:
			var aim_dir: Vector3 = (current_target_jaffa.global_position - global_position)
			aim_dir.y = 0.0
			if dist <= 2.5 and aim_dir.length_squared() > 0.01:
				rotation.y = atan2(-aim_dir.x, -aim_dir.z)
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_mp5(aim_dir.normalized())


func _process_downed_crawl(delta: float) -> void:
	if body_mesh != null:
		body_mesh.scale.y = 0.45
		body_mesh.position.y = 0.2

	# Slow crawl toward nearest cover / sandbags
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)


func _process_hold_corner(delta: float) -> void:
	# Keep anchor position clamped
	var to_anchor: Vector3 = (current_anchor_position - global_position)
	to_anchor.y = 0.0
	if to_anchor.length() > 0.6:
		var dir: Vector3 = to_anchor.normalized()
		velocity.x = dir.x * (move_speed * 0.6)
		velocity.z = dir.z * (move_speed * 0.6)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	# Check player-led progression: Human pointman must advance into forward room first!
	_check_player_led_progression()
	if current_state != State.HOLD_CORNER:
		return

	# Scan for Jaffa
	_find_nearest_jaffa()
	if current_target_jaffa != null and _has_line_of_sight(current_target_jaffa):
		var dist: float = global_position.distance_to(current_target_jaffa.global_position)
		var aim_dir: Vector3 = (current_target_jaffa.global_position - global_position)
		aim_dir.y = 0.0
		aim_dir = aim_dir.normalized()
		current_aim_target = current_target_jaffa.global_position

		peek_timer += delta
		if peek_timer < peeking_burst_duration:
			# PEEKING STANCE: Elevated, firing suppressive bursts down hallway
			is_peeking = true
			is_crouching = false
			if body_mesh != null:
				body_mesh.scale.y = 1.0
				body_mesh.position.y = 0.0
			rotation.y = atan2(-aim_dir.x, -aim_dir.z)
			if fire_cooldown <= 0.0 and dist <= combat_range:
				fire_cooldown = 60.0 / fire_rate_rpm
				_fire_mp5(aim_dir)
				hallway_suppressed.emit(self, aim_dir)
		elif peek_timer < peeking_burst_duration + peeking_cooldown_duration:
			# DUCKED BEHIND CORNER / BARRICADE: Protected crouch
			is_peeking = false
			is_crouching = true
			if body_mesh != null:
				body_mesh.scale.y = 0.65
				body_mesh.position.y = 0.15
			rotation.y = atan2(-current_anchor_facing.x, -current_anchor_facing.z)
		else:
			peek_timer = 0.0
	elif is_suppressing and suppress_timer > 0.0:
		# Active hallway suppressive fire order
		is_peeking = true
		is_crouching = false
		if body_mesh != null:
			body_mesh.scale.y = 1.0
			body_mesh.position.y = 0.0
		rotation.y = atan2(-current_anchor_facing.x, -current_anchor_facing.z)
		if fire_cooldown <= 0.0:
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_mp5(current_anchor_facing)
			hallway_suppressed.emit(self, current_anchor_facing)
	else:
		# Resting crouched behind corner, holding hallway angle
		peek_timer = 0.0
		is_peeking = false
		is_crouching = true
		if body_mesh != null:
			body_mesh.scale.y = 0.65
			body_mesh.position.y = 0.15
		rotation.y = atan2(-current_anchor_facing.x, -current_anchor_facing.z)


func _process_leapfrog_advance(delta: float) -> void:
	var move_dest: Vector3 = _get_hallway_destination(target_advance_position)
	var to_dest: Vector3 = (move_dest - global_position)
	to_dest.y = 0.0
	var dist_to_target: float = global_position.distance_to(target_advance_position)

	if dist_to_target > 1.0:
		var dir: Vector3 = to_dest.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
		if body_mesh != null:
			body_mesh.scale.y = 1.0
			body_mesh.position.y = 0.0
	else:
		# Reached forward anchor position!
		velocity.x = 0.0
		velocity.z = 0.0
		current_anchor_position = target_advance_position
		current_anchor_facing = target_advance_facing
		is_leapfrogging_advancing = false
		is_in_cover = true
		is_crouching = true
		is_peeking = false
		if body_mesh != null:
			body_mesh.scale.y = 0.65
			body_mesh.position.y = 0.15
		current_state = State.HOLD_CORNER
		leapfrog_completed.emit(self, current_anchor_position)
		print("SGCAirmanAI [%s]: Set! In position holding forward corner! Covering fireteam!" % airman_callsign)
		_notify_partner_to_advance()
		return

	# Return fire if hostiles engage during sprint
	_find_nearest_jaffa()
	if current_target_jaffa != null and _has_line_of_sight(current_target_jaffa) and fire_cooldown <= 0.0:
		var aim_dir: Vector3 = (current_target_jaffa.global_position - global_position).normalized()
		fire_cooldown = 60.0 / fire_rate_rpm
		_fire_mp5(aim_dir)


func _process_cover_fire(delta: float) -> void:
	# Maintain cover anchor and lay down continuous covering/suppressive fire down hallway
	var to_anchor: Vector3 = (current_anchor_position - global_position)
	to_anchor.y = 0.0
	if to_anchor.length() > 0.6:
		var dir: Vector3 = to_anchor.normalized()
		velocity.x = dir.x * (move_speed * 0.6)
		velocity.z = dir.z * (move_speed * 0.6)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	# Elevated peeking stance to suppress hallway
	is_peeking = true
	is_crouching = false
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.0

	_find_nearest_jaffa()
	if current_target_jaffa != null and _has_line_of_sight(current_target_jaffa):
		var aim_dir: Vector3 = (current_target_jaffa.global_position - global_position).normalized()
		aim_dir.y = 0.0
		rotation.y = atan2(-aim_dir.x, -aim_dir.z)
		if fire_cooldown <= 0.0:
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_mp5(aim_dir)
			hallway_suppressed.emit(self, aim_dir)
	else:
		# Train weapon down the hallway facing direction
		rotation.y = atan2(-current_anchor_facing.x, -current_anchor_facing.z)
		if fire_cooldown <= 0.0 and randf() < 0.15:
			fire_cooldown = (60.0 / fire_rate_rpm) * 1.5
			_fire_mp5(current_anchor_facing)
			hallway_suppressed.emit(self, current_anchor_facing)

	# Check if partner has arrived at forward position
	var partner: SGCAirmanAI = _find_fireteam_partner()
	if partner != null and not partner.is_leapfrogging_advancing and partner.current_state == State.HOLD_CORNER:
		# Partner is set! Now we leapfrog forward to the forward sector!
		var forward_sec: String = _get_sector_for_pos(partner.global_position)
		_initiate_leapfrog_advance(forward_sec)


func hold_corner(anchor_pos: Vector3, facing_dir: Vector3 = Vector3(0.0, 0.0, -1.0), anchor_type: String = "corner") -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	if mounted_turret != null:
		dismount_turret()
	current_anchor_position = anchor_pos
	current_anchor_facing = facing_dir
	current_anchor_type = anchor_type
	is_in_cover = true
	is_crouching = true
	is_peeking = false
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	current_state = State.HOLD_CORNER
	global_position = anchor_pos
	if body_mesh != null:
		body_mesh.scale.y = 0.65
		body_mesh.position.y = 0.15
	corner_held.emit(self, anchor_pos)
	print("SGCAirmanAI [%s]: Holding corner at %s! Watching hallway %s!" % [airman_callsign, str(anchor_pos), str(facing_dir)])


func advance_to_next_cover(target_pos: Vector3, facing_dir: Vector3 = Vector3(0.0, 0.0, -1.0)) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	if mounted_turret != null:
		dismount_turret()
	target_advance_position = target_pos
	target_advance_facing = facing_dir
	current_state = State.LEAPFROG_ADVANCE
	is_leapfrogging_advancing = true
	is_in_cover = false
	is_crouching = false
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.0
	leapfrog_started.emit(self, target_pos)
	print("SGCAirmanAI [%s]: Advancing to next cover at %s!" % [airman_callsign, str(target_pos)])


func suppress_hallway(hallway_dir: Vector3, duration: float = 2.0) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	is_suppressing = true
	suppress_timer = duration
	is_peeking = true
	is_crouching = false
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.0
	rotation.y = atan2(-hallway_dir.x, -hallway_dir.z)
	hallway_suppressed.emit(self, hallway_dir)
	if fire_cooldown <= 0.0:
		fire_cooldown = 60.0 / fire_rate_rpm
		if mounted_turret != null:
			mounted_turret.try_manual_fire(hallway_dir)
		else:
			_fire_mp5(hallway_dir)


func on_player_secured_hallway(secured_sector: String = "") -> void:
	_on_player_secured_hallway(secured_sector)


func _on_player_secured_hallway(secured_sector: String = "") -> void:
	if current_state == State.DEAD or current_state == State.DOWNED or current_state == State.REVIVE_PLAYER:
		return
	var sec: String = secured_sector
	if sec.is_empty():
		sec = _get_current_sector()
	is_hallway_secured = true
	print("SGCAirmanAI [%s]: Hallway in sector %s SECURED! Preparing tactical leapfrog advance!" % [airman_callsign, sec])

	var pointman: PlayerController3D = _get_human_pointman()
	var target_sec: String = sec
	if pointman != null:
		target_sec = _get_sector_for_pos(pointman.global_position)

	_coordinate_squad_leapfrog(target_sec)


func _check_player_led_progression() -> void:
	if current_state != State.HOLD_CORNER and current_state != State.COMBAT:
		return
	if mounted_turret != null:
		return

	var pointman: PlayerController3D = _get_human_pointman()
	if pointman == null:
		return

	var player_sec: String = _get_sector_for_pos(pointman.global_position)
	var airman_sec: String = _get_current_sector()

	# Airmen do NOT recklessly charge forward into uncleared rooms alone.
	# The human player must lead and advance into forward sector.
	if player_sec != airman_sec and player_sec != "UNKNOWN" and not player_sec.is_empty():
		var hostiles_in_sec: int = _count_hostiles_in_sector(airman_sec)
		if hostiles_in_sec == 0:
			_coordinate_squad_leapfrog(player_sec)


func _coordinate_squad_leapfrog(target_sec: String) -> void:
	var airmen: Array[SGCAirmanAI] = _get_allied_airmen()
	for a: SGCAirmanAI in airmen:
		if a != self and a.is_leapfrogging_advancing:
			# Partner is already advancing forward; provide covering fire!
			current_state = State.COVER_FIRE
			is_providing_cover_fire = true
			is_peeking = true
			if body_mesh != null:
				body_mesh.scale.y = 1.0
				body_mesh.position.y = 0.0
			print("SGCAirmanAI [%s]: Covering partner's leapfrog advance!" % airman_callsign)
			return

	_initiate_leapfrog_advance(target_sec)


func _initiate_leapfrog_advance(target_sec: String) -> void:
	var anchor: Dictionary = _find_best_forward_anchor(target_sec)
	if anchor.is_empty():
		return

	target_advance_position = anchor["pos"] as Vector3
	target_advance_facing = anchor["dir"] as Vector3
	current_state = State.LEAPFROG_ADVANCE
	is_leapfrogging_advancing = true
	is_in_cover = false
	is_crouching = false
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.0

	var partner: SGCAirmanAI = _find_fireteam_partner()
	if partner != null and partner.current_state != State.DEAD and partner.current_state != State.DOWNED:
		if not (partner.current_state == State.HOLD_CORNER and _get_sector_for_pos(partner.global_position) == target_sec):
			partner.current_state = State.COVER_FIRE
		partner.is_providing_cover_fire = true
		partner.is_peeking = true
		if partner.body_mesh != null:
			partner.body_mesh.scale.y = 1.0
			partner.body_mesh.position.y = 0.0

	leapfrog_started.emit(self, target_advance_position)
	print("SGCAirmanAI [%s]: Bounding forward to %s (%s)! Cover me!" % [
		airman_callsign, str(target_advance_position), str(anchor.get("type", "corner"))
	])


func _notify_partner_to_advance() -> void:
	var partner: SGCAirmanAI = _find_fireteam_partner()
	if partner != null:
		print("SGCAirmanAI [%s]: Set in position! Fireteam partner %s cleared to leapfrog!" % [airman_callsign, partner.airman_callsign])


func advance_leapfrog(forward_sector: String) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED or current_state == State.REVIVE_PLAYER:
		return
	if mounted_turret != null:
		dismount_turret()
	_initiate_leapfrog_advance(forward_sector)


func _find_best_forward_anchor(target_sec: String) -> Dictionary:
	var best_anchor: Dictionary = {}
	var min_dist: float = 999999.0

	for anchor: Dictionary in TACTICAL_ANCHORS:
		var a_sec: String = str(anchor.get("sector", ""))
		if a_sec == target_sec or target_sec.is_empty():
			var pos: Vector3 = anchor["pos"] as Vector3
			if pos.distance_to(global_position) <= 1.5:
				continue
			if not _is_anchor_occupied(pos):
				var d: float = global_position.distance_to(pos)
				if d < min_dist:
					min_dist = d
					best_anchor = anchor

	# Fallback if sector fully occupied
	if best_anchor.is_empty():
		for anchor: Dictionary in TACTICAL_ANCHORS:
			var pos: Vector3 = anchor["pos"] as Vector3
			if pos.distance_to(global_position) <= 1.5:
				continue
			if not _is_anchor_occupied(pos):
				var d: float = global_position.distance_to(pos)
				if d < min_dist:
					min_dist = d
					best_anchor = anchor

	return best_anchor


func _is_anchor_occupied(anchor_pos: Vector3) -> bool:
	var allies: Array[SGCAirmanAI] = _get_allied_airmen()
	for a: SGCAirmanAI in allies:
		if a != self and a.health_component != null and not a.health_component.is_dead and not a.health_component.is_downed:
			if a.global_position.distance_to(anchor_pos) <= 1.5:
				return true
			if a.is_leapfrogging_advancing and a.target_advance_position.distance_to(anchor_pos) <= 1.5:
				return true
	return false


func find_best_tactical_anchor(preferred_sector: String = "") -> Dictionary:
	var sec: String = preferred_sector
	if sec.is_empty():
		sec = _get_current_sector()

	var best_anchor: Dictionary = {}
	var min_dist: float = 999999.0

	# 1. Dynamic cover checks (DeployableShield / barricades in 'cover' group)
	var cover_nodes: Array[Node] = get_tree().get_nodes_in_group("cover")
	for node: Node in cover_nodes:
		if node is Node3D and is_instance_valid(node):
			var n3d: Node3D = node as Node3D
			var cover_pos: Vector3 = n3d.global_position + n3d.global_transform.basis.z * 0.7
			cover_pos.y = global_position.y
			if not _is_anchor_occupied(cover_pos):
				var d: float = global_position.distance_to(cover_pos)
				if d < min_dist and d <= 12.0:
					min_dist = d
					best_anchor = {
						"pos": cover_pos,
						"dir": -n3d.global_transform.basis.z,
						"sector": sec,
						"type": "deployable_shield"
					}

	# 2. Static pre-mapped anchors
	for anchor: Dictionary in TACTICAL_ANCHORS:
		var a_sec: String = str(anchor.get("sector", ""))
		if a_sec == sec or sec.is_empty():
			var pos: Vector3 = anchor["pos"] as Vector3
			if not _is_anchor_occupied(pos):
				var d: float = global_position.distance_to(pos)
				if d < min_dist:
					min_dist = d
					best_anchor = anchor

	return best_anchor


func _find_fireteam_partner() -> SGCAirmanAI:
	var allies: Array[SGCAirmanAI] = _get_allied_airmen()
	for a: SGCAirmanAI in allies:
		if a != self and a.health_component != null and not a.health_component.is_dead and not a.health_component.is_downed:
			return a
	return null


func _get_allied_airmen() -> Array[SGCAirmanAI]:
	var result: Array[SGCAirmanAI] = []
	var allies_node: Node = get_tree().root.find_child("Allies", true, false)
	if allies_node != null:
		for child: Node in allies_node.get_children():
			var a: SGCAirmanAI = child as SGCAirmanAI
			if a != null and is_instance_valid(a):
				result.append(a)
	else:
		var airmen_nodes: Array[Node] = get_tree().get_nodes_in_group("airmen")
		for node: Node in airmen_nodes:
			var a: SGCAirmanAI = node as SGCAirmanAI
			if a != null and is_instance_valid(a):
				result.append(a)
	return result


func _get_human_pointman() -> PlayerController3D:
	var players_container: Node = get_tree().root.find_child("Players", true, false)
	if players_container != null:
		for child: Node in players_container.get_children():
			var p: PlayerController3D = child as PlayerController3D
			if p != null and p.health_component != null and not p.health_component.is_dead and not p.health_component.is_downed:
				return p
	return null


func _count_hostiles_in_sector(sec: String) -> int:
	var count: int = 0
	var enemies_container: Node = get_tree().root.find_child("Enemies", true, false)
	if enemies_container != null:
		for child: Node in enemies_container.get_children():
			var jaffa: JaffaAI = child as JaffaAI
			if jaffa != null and jaffa.health_component != null and not jaffa.health_component.is_dead:
				var j_sec: String = _get_sector_for_pos(jaffa.global_position)
				if j_sec == sec:
					count += 1
	return count


func _get_sector_for_pos(pos: Vector3) -> String:
	var gr: GateRoom = get_tree().root.find_child("GateRoom", true, false) as GateRoom
	if gr != null:
		return gr.get_current_sector(pos)
	if pos.x >= -7.5 and pos.x <= 7.5 and pos.z >= 7.8 and pos.z <= 22.0:
		return "CONTROL_ROOM"
	elif pos.z <= 8.0 and absf(pos.x) <= 18.5:
		return "GATE_ROOM"
	elif pos.z >= 22.0 and absf(pos.x) <= 6.0:
		return "FALLBACK_HALLWAY"
	elif pos.x >= 35.0:
		return "ARMORY"
	return "GATE_ROOM"


func _get_current_sector() -> String:
	return _get_sector_for_pos(global_position)


func _find_nearest_jaffa() -> void:
	var enemies_container: Node = get_tree().root.find_child("Enemies", true, false)
	if enemies_container == null:
		current_target_jaffa = null
		return

	var nearest: JaffaAI = null
	var min_dist: float = combat_range
	for child: Node in enemies_container.get_children():
		var jaffa: JaffaAI = child as JaffaAI
		if jaffa != null and jaffa.health_component != null and not jaffa.health_component.is_dead:
			var d: float = global_position.distance_to(jaffa.global_position)
			if d < min_dist and _has_line_of_sight(jaffa):
				min_dist = d
				nearest = jaffa
	current_target_jaffa = nearest


func _find_nearest_downed_player() -> PlayerController3D:
	var players_container: Node = get_tree().root.find_child("Players", true, false)
	if players_container == null:
		return null

	for child: Node in players_container.get_children():
		var p: PlayerController3D = child as PlayerController3D
		if p != null and p.health_component != null and p.health_component.is_downed:
			return p
	return null


func _find_available_turret() -> DeployableTurret:
	var candidates: Array[DeployableTurret] = []
	var mounted_turret_nodes: Array[Node] = get_tree().get_nodes_in_group("mounted_turret")
	for node: Node in mounted_turret_nodes:
		var t: DeployableTurret = node as DeployableTurret
		if t != null and is_instance_valid(t) and t.mounted_player == null:
			if not candidates.has(t):
				candidates.append(t)

	var turret_nodes: Array[Node] = get_tree().get_nodes_in_group("turret")
	for node: Node in turret_nodes:
		var t: DeployableTurret = node as DeployableTurret
		if t != null and is_instance_valid(t) and t.mounted_player == null:
			if not candidates.has(t):
				candidates.append(t)

	# Named bunker geometry turrets
	var west: DeployableTurret = get_tree().root.find_child("TurretWest", true, false) as DeployableTurret
	if west != null and is_instance_valid(west) and west.mounted_player == null and not candidates.has(west):
		candidates.append(west)
	var east: DeployableTurret = get_tree().root.find_child("TurretEast", true, false) as DeployableTurret
	if east != null and is_instance_valid(east) and east.mounted_player == null and not candidates.has(east):
		candidates.append(east)
	var hallway: DeployableTurret = get_tree().root.find_child("FixedTurretHallway", true, false) as DeployableTurret
	if hallway != null and is_instance_valid(hallway) and hallway.mounted_player == null and not candidates.has(hallway):
		candidates.append(hallway)

	var nearest: DeployableTurret = null
	var min_d: float = 999999.0
	for t: DeployableTurret in candidates:
		var d: float = global_position.distance_to(t.global_position)
		if d < min_d:
			min_d = d
			nearest = t

	return nearest


func _on_downed() -> void:
	current_state = State.DOWNED
	if mounted_turret != null:
		dismount_turret()
	is_in_cover = false
	is_peeking = false
	is_crouching = false
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	airman_downed.emit(self)
	print("SGCAirmanAI [%s]: MAN DOWN! Airman is bleeding out!" % airman_callsign)


func _on_revived() -> void:
	current_state = State.COMBAT
	is_in_cover = false
	is_peeking = false
	is_crouching = false
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.0
	airman_revived.emit(self)
	print("SGCAirmanAI [%s]: Back on my feet! Resuming fire!" % airman_callsign)


func _on_died() -> void:
	current_state = State.DEAD
	if mounted_turret != null:
		dismount_turret()
	is_in_cover = false
	is_peeking = false
	is_crouching = false
	is_leapfrogging_advancing = false
	is_providing_cover_fire = false
	collision_layer = 0
	airman_died.emit(self)
	print("SGCAirmanAI [%s]: KIA." % airman_callsign)
