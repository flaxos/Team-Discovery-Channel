class_name JaffaAI
extends CharacterBody3D
## Goa'uld Serpent / Horus Guard Enemy AI.
## Advances down the Stargate ramp, takes tactical firing positions,
## discharges liquid Naquadah plasma bolts, and enforces canonical Zat status effects.

signal jaffa_died(killer: Node)
signal jaffa_vaporized()
signal staff_fired(origin: Vector3, direction: Vector3)

enum State {
	IDLE,
	MARCHING_FORMATION,
	PATROL,
	CHASE,
	ATTACK,
	ADVANCE,
	COMBAT,
	MELEE,
	COVER,
	RETREAT,
	STUNNED,
	DOWNED,
	DEAD
}

@export var is_shock_guard: bool = false
@export var move_speed: float = 4.2
@export var march_speed: float = 2.4
@export var combat_run_speed: float = 5.5
@export var combat_range: float = 22.0
@export var melee_range: float = 2.2
@export var plasma_damage: float = 45.0
@export var fire_interval_s: float = 2.8
@export var staff_accuracy_spread_deg: float = 3.5

var current_state: State = State.ADVANCE
var current_target: Node3D = null
var fire_timer: float = 0.0
var melee_cooldown: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Formation March & Tactical Maneuver Variables
var march_target: Vector3 = Vector3.ZERO
var column_x_lane: float = 0.0
var formation_rank: int = 0
var is_front_rank: bool = false
var is_crouching: bool = false
var is_tactical_flanking: bool = false
var tactical_destination: Vector3 = Vector3.ZERO
var flank_route_target: Vector3 = Vector3.ZERO
var tactical_cover_position: Vector3 = Vector3.ZERO
var suppressive_hold_timer: float = 0.0
var _death_notified: bool = false
var navigator: SGCNavigator
var overrun_destination_index: int = 0

@onready var health_component: HealthComponent = $HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var staff_mount: Node3D = $StaffMount if has_node("StaffMount") else null
@onready var muzzle_point: Marker3D = $StaffMount/MuzzlePoint if has_node("StaffMount/MuzzlePoint") else null
@onready var stun_fx: Node3D = $Visuals/StunFX if has_node("Visuals/StunFX") else null
@onready var body_mesh: MeshInstance3D = $Visuals/ArmorMesh if has_node("Visuals/ArmorMesh") else null
@onready var visuals_root: Node3D = $Visuals if has_node("Visuals") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null


func _enter_tree() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and has_node("MultiplayerSynchronizer"):
		net.configure_mission_sync($MultiplayerSynchronizer)


func _ready() -> void:
	# Server is authoritative over AI logic
	set_multiplayer_authority(1)
	navigator = SGCNavigator.new(self)

	if is_shock_guard:
		if health_component != null:
			health_component.max_health = 140.0
			health_component.current_health = 140.0
		move_speed = 4.8
		combat_run_speed = 5.8
		plasma_damage = 42.0
		fire_interval_s = 1.4

	if health_component != null:
		health_component.died.connect(_on_died)
		health_component.stunned.connect(_on_stunned)
		health_component.recovered_from_stun.connect(_on_recovered_from_stun)
		health_component.vaporized.connect(_on_vaporized)
		health_component.damage_taken.connect(_on_damage_taken)

	# Randomize initial fire offset so multiple Jaffa don't shoot in unison
	fire_timer = randf_range(0.5, fire_interval_s)

	_setup_staff_visual()


## Initializes disciplined Stargate 2-by-2 column march mode down the ramp.
func start_column_march(march_target_pos: Vector3) -> void:
	current_state = State.MARCHING_FORMATION
	march_target = march_target_pos
	column_x_lane = march_target_pos.x
	_set_crouching(false)
	_set_staff_ready_position()
	print("JaffaAI [%s]: Commencing column march toward %s (Lane X=%.1f, Rank %d, Front=%s)." % [
		name, str(march_target), column_x_lane, formation_rank, str(is_front_rank)
	])


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state == State.DEAD or current_state == State.STUNNED or current_state == State.DOWNED:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	# State evaluations
	match current_state:
		State.MARCHING_FORMATION:
			_process_marching_formation(delta)
		State.COVER, State.RETREAT:
			_process_cover(delta)
		State.COMBAT, State.ATTACK:
			_process_combat_state(delta)
		State.MELEE:
			_process_melee(delta)
		State.ADVANCE, State.CHASE, State.PATROL, State.IDLE:
			_process_advance_state(delta)

	move_and_slide()


func _process_marching_formation(delta: float) -> void:
	_set_staff_ready_position()

	# Check engagement triggers: target in LOS within combat range
	_find_nearest_target()
	if current_target != null:
		var dist: float = global_position.distance_to(current_target.global_position)
		if dist <= combat_range and _has_line_of_sight(current_target):
			break_formation_and_engage()
			_alert_nearby_formation_jaffa()
			return

	# Reached Gate Room center (Z >= march_target.z, where march_target.z is 0.0)
	if global_position.z >= march_target.z:
		print("JaffaAI [%s]: Column reached Gate Room center (Z=%.1f). Transitioning to base advance." % [name, global_position.z])
		current_state = State.ADVANCE
		_reset_staff_position()
		return

	# Maintain column lane X while marching forward down the ramp (+Z) at march_speed (2.4 m/s) in disciplined synchronized lockstep
	var x_offset: float = column_x_lane - global_position.x
	var steer_x: float = clampf(x_offset * 3.0, -1.0, 1.0)

	velocity.x = move_toward(velocity.x, steer_x * (march_speed * 0.75), 12.0 * delta)
	velocity.z = move_toward(velocity.z, march_speed, 12.0 * delta)

	# Keep orientation locked forward down the ramp (+Z direction) with smooth lane steering
	var target_rot_y: float = atan2(-steer_x * 0.2, -1.0)
	rotation.y = lerp_angle(rotation.y, target_rot_y, clampf(12.0 * delta, 0.0, 1.0))


## Triggers tactical reaction when column formation is engaged.
func break_formation_and_engage() -> void:
	if current_state == State.DEAD or current_state == State.STUNNED or current_state == State.DOWNED:
		return

	if is_front_rank or _is_lead_jaffa_on_ramp():
		# Front ranks halt and crouch to lay down suppressive plasma bolt fire
		current_state = State.COMBAT
		_set_crouching(true)
		velocity = Vector3.ZERO
		suppressive_hold_timer = 4.0
		fire_timer = randf_range(0.1, 0.3)
		print("JaffaAI [%s]: Front rank halting & crouching to unleash plasma barrage!" % name)
	else:
		# Trailing ranks break into tactical combat (flanking via West/East corridors or taking cover behind sandbags)
		current_state = State.COVER
		_set_crouching(false)
		_assign_tactical_role()
		print("JaffaAI [%s]: Trailing rank breaking into tactical cover / corridor flanking!" % name)


func _is_lead_jaffa_on_ramp() -> bool:
	if is_front_rank or formation_rank == 0:
		return true
	var enemies: Node = get_parent()
	if enemies == null:
		return false
	# Only step up to lead rank if all Jaffa in earlier ranks are eliminated
	for child: Node in enemies.get_children():
		var other: JaffaAI = child as JaffaAI
		if other != null and other != self and is_instance_valid(other):
			if other.formation_rank < formation_rank:
				if other.current_state != State.DEAD and other.current_state != State.DOWNED:
					return false
	return true


func _alert_nearby_formation_jaffa() -> void:
	var enemies: Node = get_parent()
	if enemies == null:
		return
	for child: Node in enemies.get_children():
		var other: JaffaAI = child as JaffaAI
		if other != null and other != self and is_instance_valid(other):
			if other.current_state == State.MARCHING_FORMATION or other.current_state == State.ADVANCE:
				if other.current_target == null and current_target != null:
					other.current_target = current_target
				other.break_formation_and_engage()


func _assign_tactical_role() -> void:
	var is_west: bool = (global_position.x < 0.0 or column_x_lane < 0.0)

	if formation_rank == 1:
		# Rank 1 takes sandbag cover
		is_tactical_flanking = false
		tactical_cover_position = _find_nearest_cover(is_west)
		tactical_destination = tactical_cover_position
	else:
		# Rank >= 2 flanks via corridor
		is_tactical_flanking = true
		flank_route_target = Vector3(-18.0, 0.1, 4.0) if is_west else Vector3(18.0, 0.1, 4.0)
		tactical_destination = flank_route_target


func _find_nearest_cover(is_west: bool) -> Vector3:
	var default_pos: Vector3 = Vector3(-5.0, 0.1, 4.0) if is_west else Vector3(2.5, 0.1, 4.0)
	if not is_inside_tree():
		return default_pos

	var cover_nodes: Array[Node] = get_tree().get_nodes_in_group("cover")
	var min_dist: float = 99999.0
	var chosen_pos: Vector3 = default_pos

	for node: Node in cover_nodes:
		var n3d: Node3D = node as Node3D
		if n3d != null:
			var pos: Vector3 = n3d.global_position
			if (is_west and pos.x < 0.0) or (not is_west and pos.x >= 0.0):
				var d: float = global_position.distance_to(pos)
				if d < min_dist:
					min_dist = d
					chosen_pos = Vector3(pos.x, 0.1, pos.z - 0.8)

	return chosen_pos


func _process_cover(delta: float) -> void:
	_find_nearest_target()

	if current_target != null:
		var dist_to_target: float = global_position.distance_to(current_target.global_position)
		if dist_to_target <= melee_range:
			_set_crouching(false)
			current_state = State.MELEE
			_process_melee(delta)
			return

	var dist_to_dest: float = Vector2(global_position.x - tactical_destination.x, global_position.z - tactical_destination.z).length()

	if dist_to_dest > 1.2:
		_set_crouching(false)
		var to_dest: Vector3 = (_get_hallway_destination(tactical_destination) - global_position)
		to_dest.y = 0.0
		var dir: Vector3 = to_dest.normalized()

		velocity.x = move_toward(velocity.x, dir.x * combat_run_speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * combat_run_speed, 20.0 * delta)

		if dir.length_squared() > 0.01:
			rotation.y = atan2(-dir.x, -dir.z)

		if current_target != null and _has_line_of_sight(current_target):
			fire_timer -= delta
			if fire_timer <= 0.0:
				fire_timer = fire_interval_s + randf_range(-0.2, 0.3)
				_fire_staff_blast()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

		if not is_tactical_flanking:
			_set_crouching(true)

		if current_target != null and _has_line_of_sight(current_target):
			var look_dir: Vector3 = (current_target.global_position - global_position)
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.01:
				rotation.y = atan2(-look_dir.x, -look_dir.z)

			fire_timer -= delta
			if fire_timer <= 0.0:
				fire_timer = fire_interval_s + randf_range(-0.3, 0.3)
				_fire_staff_blast()
		elif current_target != null:
			_set_crouching(false)
			current_state = State.COMBAT


func _process_combat_state(delta: float) -> void:
	_find_nearest_target()

	if current_target == null:
		if suppressive_hold_timer > 0.0:
			suppressive_hold_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			return
		_set_crouching(false)
		_reset_staff_position()
		current_state = State.ADVANCE
		var advance_target := _overrun_destination()
		_advance_towards(advance_target, delta, march_speed)
		return

	var dist: float = global_position.distance_to(current_target.global_position)
	if dist <= melee_range:
		_set_crouching(false)
		current_state = State.MELEE
		_process_melee(delta)
		return

	var has_los: bool = _has_line_of_sight(current_target)

	if is_crouching:
		suppressive_hold_timer = 4.0
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

		if has_los:
			var look_dir: Vector3 = (current_target.global_position - global_position)
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.01:
				rotation.y = atan2(-look_dir.x, -look_dir.z)

			fire_timer -= delta
			if fire_timer <= 0.0:
				fire_timer = fire_interval_s + randf_range(-0.3, 0.4)
				_fire_staff_blast()
		else:
			_set_crouching(false)
			_advance_towards(current_target.global_position, delta, move_speed)
	else:
		if has_los and dist <= combat_range:
			_process_combat(delta, dist)
		else:
			current_state = State.ADVANCE
			_advance_towards(current_target.global_position, delta, move_speed)


func _process_advance_state(delta: float) -> void:
	_set_crouching(false)
	_reset_staff_position()
	_find_nearest_target()

	if current_target == null:
		# Proceed to march steadily into the base preserving tactical lane cohesion
		var advance_target := _overrun_destination()
		_advance_towards(advance_target, delta, march_speed)
		return

	var dist: float = global_position.distance_to(current_target.global_position)
	if dist <= melee_range:
		current_state = State.MELEE
		_process_melee(delta)
	elif dist <= combat_range and _has_line_of_sight(current_target):
		current_state = State.COMBAT
		_process_combat(delta, dist)
	else:
		_advance_towards(current_target.global_position, delta, move_speed)


func _set_crouching(crouched: bool) -> void:
	is_crouching = crouched
	var target_y: float = -0.35 if crouched else 0.0
	var col_y: float = 0.65 if crouched else 0.95
	var staff_y: float = 0.75 if crouched else (1.05 if is_shock_guard else 1.0)

	if visuals_root != null:
		visuals_root.position.y = target_y
	if collision_shape != null:
		collision_shape.position.y = col_y
	if staff_mount != null:
		staff_mount.position.y = staff_y


func _set_staff_ready_position() -> void:
	if staff_mount == null:
		return
	staff_mount.position = Vector3(0.05, 0.75 if is_crouching else 1.1, -0.4)
	staff_mount.rotation_degrees = Vector3(-6.0, 0.0, 0.0)


func _reset_staff_position() -> void:
	if staff_mount == null:
		return
	staff_mount.position = Vector3(
		0.38 if is_shock_guard else 0.35,
		0.75 if is_crouching else (1.05 if is_shock_guard else 1.0),
		-0.2
	)
	staff_mount.rotation_degrees = Vector3.ZERO


func _setup_staff_visual() -> void:
	if staff_mount == null:
		return
	if staff_mount.has_node("StaffVisual"):
		return

	var visual_root: Node3D = Node3D.new()
	visual_root.name = "StaffVisual"
	staff_mount.add_child(visual_root)

	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 1.9
	var shaft_mat: StandardMaterial3D = StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.4, 0.3, 0.15)
	shaft_mat.metallic = 0.8
	shaft_mat.roughness = 0.3
	cyl.material = shaft_mat
	shaft.mesh = cyl
	shaft.rotation_degrees.x = 90.0
	shaft.position.z = -0.1
	visual_root.add_child(shaft)

	var head: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.08, 0.3, 0.08)
	var head_mat: StandardMaterial3D = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.65, 0.2)
	head_mat.metallic = 0.95
	head_mat.roughness = 0.2
	prism.material = head_mat
	head.mesh = prism
	head.rotation_degrees.x = -90.0
	head.position.z = -1.0
	visual_root.add_child(head)


func _find_nearest_target() -> void:
	# Find closest active SGC operative or allied Airman defender in perception range
	var closest_los_target: Node3D = null
	var closest_los_dist: float = combat_range * 1.5  # ~33m visual awareness
	var closest_any_target: Node3D = null
	var min_any_dist: float = combat_range

	var candidates: Array[Node3D] = []

	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container != null:
		for child in players_container.get_children():
			var p := child as CharacterBody3D
			if p != null:
				var health := p.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and not health.is_dead:
					candidates.append(p)

	var allies_container := get_tree().root.find_child("Allies", true, false)
	if allies_container != null:
		for child in allies_container.get_children():
			var a := child as CharacterBody3D
			if a != null:
				var health := a.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and not health.is_dead:
					candidates.append(a)

	for c in candidates:
		var d := global_position.distance_to(c.global_position)
		if _has_line_of_sight(c):
			if d < closest_los_dist:
				closest_los_dist = d
				closest_los_target = c
		else:
			if d < min_any_dist:
				min_any_dist = d
				closest_any_target = c

	if closest_los_target != null:
		current_target = closest_los_target
	elif closest_any_target != null and min_any_dist <= combat_range:
		current_target = closest_any_target
	else:
		current_target = null


func _is_target_obscured_by_smoke(target_pos: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var seg_start := global_position + Vector3(0, 1.4, 0)
	var seg_end := target_pos + Vector3(0, 1.0, 0)
	var seg_dir := (seg_end - seg_start)
	var seg_len_sq := seg_dir.length_squared()
	if seg_len_sq < 0.001:
		return false

	for node in get_tree().get_nodes_in_group("smoke_cloud"):
		var cloud := node as Area3D
		if cloud != null and is_instance_valid(cloud):
			var cloud_pos := cloud.global_position
			var t := clampf((cloud_pos - seg_start).dot(seg_dir) / seg_len_sq, 0.0, 1.0)
			var closest_pt := seg_start + seg_dir * t
			if closest_pt.distance_to(cloud_pos) <= 4.5:
				return true
	return false


func _has_line_of_sight(target: Node3D) -> bool:
	if target == null or not is_inside_tree() or not target.is_inside_tree():
		return false
	if _is_target_obscured_by_smoke(target.global_position):
		return false

	var space := get_world_3d().direct_space_state
	if space == null:
		return false

	var from: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.4, 0)
	var exclude_list: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude_list.append((target as CollisionObject3D).get_rid())

	# Test both head and torso for clear unoccluded LOS
	var test_points: Array[Vector3] = [
		target.global_position + Vector3(0, 1.5, 0),  # Head
		target.global_position + Vector3(0, 1.0, 0)   # Torso
	]
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and health.is_downed:
		test_points.append(target.global_position + Vector3(0, 0.35, 0))

	for to in test_points:
		if _cast_los_ray(space, from, to, exclude_list.duplicate()):
			return true

	return false


func _cast_los_ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude_list: Array[RID]) -> bool:
	for iter in range(3):
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1  # Blocked only by World walls/barricades
		query.exclude = exclude_list
		var result := space.intersect_ray(query)
		if result.is_empty():
			return true
		var col: Node = result.get("collider") as Node
		if col != null and (col.name.contains("Glass") or col.name.contains("Overlook")):
			if result.has("rid"):
				exclude_list.append(result["rid"])
			continue
		return false
	return false


func _advance_towards(target_pos: Vector3, delta: float, target_speed: float = -1.0) -> void:
	var move_speed_to_use: float = target_speed if target_speed > 0.0 else move_speed
	var move_dest := navigator.next_position(target_pos, delta) if navigator != null else target_pos

	var to_target := (move_dest - global_position)
	to_target.y = 0.0
	var dir := to_target.normalized()

	velocity.x = move_toward(velocity.x, dir.x * move_speed_to_use, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed_to_use, 20.0 * delta)

	# If no line of sight to target, orient strictly to corridor movement direction
	if (current_target == null or not _has_line_of_sight(current_target)) and dir.length_squared() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)


func _get_hallway_destination(target_pos: Vector3) -> Vector3:
	return navigator.next_position(target_pos) if navigator != null else global_position


func _process_combat(delta: float, dist: float) -> void:
	# Continue advancing down the ramp while in long-range combat (> 10m)
	if dist > 10.0:
		_advance_towards(current_target.global_position, delta)
	else:
		# Tactical stop-and-shoot when holding position at mid-range
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval_s + randf_range(-0.3, 0.4)
		_fire_staff_blast()


func _fire_staff_blast() -> void:
	if current_target == null or not _has_line_of_sight(current_target):
		return

	_dispatch_single_plasma_bolt()

	# Jaffa Shock Guard rapid double-burst logic (fires 2nd bolt after 0.18s)
	if is_shock_guard:
		var burst_timer := get_tree().create_timer(0.18)
		burst_timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and is_inside_tree() and current_state != State.DEAD and current_state != State.STUNNED and current_target != null:
				if _has_line_of_sight(current_target):
					_dispatch_single_plasma_bolt()
		)


func _dispatch_single_plasma_bolt() -> void:
	if current_target == null or not _has_line_of_sight(current_target):
		return

	var origin: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.2, -0.6)
	var target_chest := current_target.global_position + Vector3(0, 1.0, 0)
	var base_dir := (target_chest - origin).normalized()

	# Spread inaccuracy cone
	var spread_rad := deg_to_rad(staff_accuracy_spread_deg)
	var random_yaw := randf_range(-spread_rad, spread_rad)
	var dir := base_dir.rotated(Vector3.UP, random_yaw).normalized()

	# Instantiate plasma bolt across server
	var bolt_scene := load("res://scenes/entities/PlasmaBolt.tscn") as PackedScene
	if bolt_scene != null:
		var bolt := bolt_scene.instantiate() as PlasmaBolt
		bolt.damage = plasma_damage
		var root_node := get_tree().root if is_inside_tree() else null
		if root_node != null:
			root_node.add_child(bolt)
			bolt.initialize(origin, dir, self, true)
		elif get_parent() != null:
			get_parent().add_child(bolt)
			bolt.initialize(origin, dir, self, true)

	staff_fired.emit(origin, dir)

	# Visual muzzle burst RPC
	rpc("play_staff_fire_fx", origin)


func _on_damage_taken(_amount: float, source: Node, _damage_type: String) -> void:
	if is_shock_guard and current_state != State.DEAD:
		rpc("play_armor_spark_fx", global_position + Vector3(0, 1.2, 0))

	if source is Node3D and is_instance_valid(source):
		current_target = source as Node3D

	if current_state == State.MARCHING_FORMATION or current_state == State.ADVANCE:
		break_formation_and_engage()
		_alert_nearby_formation_jaffa()


@rpc("call_local", "unreliable")
func play_armor_spark_fx(pos: Vector3) -> void:
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.85, 0.4)
	spark.light_energy = 5.0
	spark.omni_range = 2.5
	get_tree().root.add_child(spark)
	spark.global_position = pos

	var tween := spark.create_tween()
	tween.tween_property(spark, "light_energy", 0.0, 0.1)
	tween.tween_callback(spark.queue_free)


func _process_melee(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	melee_cooldown -= delta
	if melee_cooldown <= 0.0 and current_target != null:
		melee_cooldown = 1.6
		var target_health := current_target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(35.0, self, "melee_strike")
			print("Jaffa guard struck operative in melee!")


@rpc("call_local", "unreliable")
func play_staff_fire_fx(origin_pos: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	# Orange muzzle burst light
	var burst := OmniLight3D.new()
	burst.light_color = Color(1.0, 0.5, 0.1)
	burst.light_energy = 4.0
	burst.omni_range = 3.0
	get_tree().root.add_child(burst)
	burst.global_position = origin_pos

	var tween := burst.create_tween()
	tween.tween_property(burst, "light_energy", 0.0, 0.09)
	tween.tween_callback(burst.queue_free)


func _on_stunned(duration: float) -> void:
	current_state = State.STUNNED
	_set_crouching(false)
	if stun_fx != null:
		stun_fx.visible = true
	print("Jaffa Guard incapacitated by Zat'nik'tel stun for %.1f s." % duration)


func _on_recovered_from_stun() -> void:
	if current_state == State.STUNNED:
		current_state = State.ADVANCE
		if stun_fx != null:
			stun_fx.visible = false
		print("Jaffa Guard recovered from Zat stun.")


func _on_died() -> void:
	if navigator != null: navigator.reset()
	if _death_notified:
		return
	_death_notified = true
	current_state = State.DEAD
	_set_crouching(false)
	collision_layer = 64  # Corpse-only ray layer: Zat can vaporize, players/bullets pass through.
	if stun_fx != null:
		stun_fx.visible = false

	# Collapse animation (tilt mesh backwards)
	if body_mesh != null:
		var tween := create_tween()
		tween.tween_property(body_mesh, "rotation:x", deg_to_rad(-85.0), 0.35)
		tween.parallel().tween_property(body_mesh, "position:y", 0.2, 0.35)

	if multiplayer.is_server():
		jaffa_died.emit(self)
	print("Jaffa Guard eliminated.")


func _on_vaporized() -> void:
	jaffa_vaporized.emit()
	print("Jaffa Guard corpse vaporized by Zat'nik'tel 3rd shot!")

	# Disintegration flash
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.2, 0.6, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	get_tree().root.add_child(flash)
	flash.global_position = global_position + Vector3(0, 0.5, 0)

	var tween := create_tween()
	if body_mesh != null:
		tween.tween_property(body_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	if multiplayer.is_server():
		tween.tween_callback(queue_free)
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.25)
	flash_tween.tween_callback(flash.queue_free)


func _overrun_destination() -> Vector3:
	var map := get_tree().get_first_node_in_group("sgc_map") as SGCMap
	if map == null: return Vector3(column_x_lane, 0.0, 24.0)
	var destinations: Array[StringName] = [&"EAST_CORRIDOR", &"ROUND_HALLWAY", &"BRIEFING_ROOM", &"STAGING"]
	if column_x_lane < 0: destinations[0] = &"WEST_CORRIDOR"
	var goal := map.definition.region(destinations[overrun_destination_index]).anchor
	if global_position.distance_to(goal) < 1.2 and overrun_destination_index < destinations.size()-1:
		overrun_destination_index += 1
		goal = map.definition.region(destinations[overrun_destination_index]).anchor
	return goal
