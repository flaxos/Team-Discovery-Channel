class_name SGCAirmanAI
extends CharacterBody3D
## SGC Airman AI Base Defender Fireteam.
## Spawns in Armory / Staging corridors on Sublevel 28, scrambles to the Gate Room upon Red Alert,
## returns fire with MP5 bursts, mounts unmanned .50 Cal turrets, and provides two-way revive support.

signal airman_downed(airman: SGCAirmanAI)
signal airman_revived(airman: SGCAirmanAI)
signal airman_died(airman: SGCAirmanAI)
signal turret_mounted(turret: DeployableTurret)
signal turret_dismounted(turret: DeployableTurret)
signal order_acknowledged(airman: SGCAirmanAI, order_type: String)

enum State { STAGING, SCRAMBLE, COMBAT, MAN_TURRET, REVIVE_PLAYER, MOVE_TO_TURRET, ORDER_MOVE, ORDER_REGROUP, DOWNED, DEAD }

@export var airman_callsign: String = "AIRMAN DAVIS"
@export var move_speed: float = 5.2
@export var weapon_damage: float = 22.0
@export var fire_rate_rpm: float = 600.0
@export var combat_range: float = 22.0

var current_state: State = State.STAGING
var fire_cooldown: float = 0.0
var revive_channel_time: float = 0.0
const REVIVE_DURATION_S: float = 2.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var mounted_turret: DeployableTurret = null
var current_target_jaffa: JaffaAI = null
var target_player_to_revive: CharacterBody3D = null
var target_turret_to_mount: DeployableTurret = null
var ordered_position: Vector3 = Vector3.ZERO
var order_leader: CharacterBody3D = null

@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var body_mesh: Node3D = $Visuals/BodyMesh if has_node("Visuals/BodyMesh") else null
@onready var nameplate: Label3D = $Nameplate if has_node("Nameplate") else null


func _ready() -> void:
	if health_component != null:
		health_component.max_health = 100.0
		health_component.current_health = 100.0
		health_component.can_be_downed = true
		health_component.downed.connect(_on_downed)
		health_component.revived.connect(_on_revived)
		health_component.died.connect(_on_died)

	if nameplate != null:
		nameplate.text = airman_callsign


func scramble_to_gate_room() -> void:
	if current_state == State.DEAD or current_state == State.DOWNED:
		return
	current_state = State.SCRAMBLE
	print("SGCAirmanAI [%s]: Scrambling to Gate Room! Engaging hostiles!" % airman_callsign)


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not multiplayer.is_server():
		move_and_slide()
		return

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

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

	move_and_slide()


func _process_scramble(delta: float) -> void:
	# Advance toward the Gate Room arena center (0, 0, 5)
	var target_pos := Vector3(randf_range(-3.0, 3.0), 0.1, 5.0)
	var dir := (target_pos - global_position)
	dir.y = 0.0

	if dir.length() > 2.0:
		velocity.x = dir.normalized().x * move_speed
		velocity.z = dir.normalized().z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		current_state = State.COMBAT


func _process_combat(delta: float) -> void:
	# Check if any operative is downed and needs emergency revive
	var downed_player := _find_nearest_downed_player()
	if downed_player != null:
		target_player_to_revive = downed_player
		current_state = State.REVIVE_PLAYER
		revive_channel_time = 0.0
		print("SGCAirmanAI [%s]: Squadmate down! Providing covering fire and moving to revive!" % airman_callsign)
		return

	# Check if an unmanned .50 Cal Browning is available to mount
	var turret := _find_available_turret()
	if turret != null and global_position.distance_to(turret.global_position) <= 8.0:
		mount_turret(turret)
		return

	# Acquire target Jaffa
	_find_nearest_jaffa()
	if current_target_jaffa == null:
		# Hold tactical sandbag line
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		return

	var dist := global_position.distance_to(current_target_jaffa.global_position)
	var aim_dir := (current_target_jaffa.global_position - global_position)
	aim_dir.y = 0.0
	if aim_dir.length_squared() > 0.01:
		rotation.y = atan2(-aim_dir.x, -aim_dir.z)

	if dist > 8.0:
		# Advance toward sandbag line
		velocity.x = aim_dir.normalized().x * (move_speed * 0.7)
		velocity.z = aim_dir.normalized().z * (move_speed * 0.7)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	# Fire MP5 bursts at Jaffa
	if fire_cooldown <= 0.0 and dist <= combat_range:
		fire_cooldown = 60.0 / fire_rate_rpm
		_fire_mp5(aim_dir.normalized())


func _fire_mp5(dir: Vector3) -> void:
	var origin := global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * combat_range)
	query.collision_mask = 1 | 4  # World and Jaffa

	var result := space.intersect_ray(query)
	var hit_pos := origin + dir * combat_range
	if not result.is_empty():
		hit_pos = result["position"]
		var col: Node = result["collider"] as Node
		if col != null:
			var health := col.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(weapon_damage, self, "bullet")

	rpc("play_mp5_fx", origin, hit_pos)


@rpc("call_local", "unreliable")
func play_mp5_fx(from: Vector3, to: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	tracer.mesh = imm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.4, 0.9)
	tracer.material_override = mat
	get_tree().root.add_child(tracer)

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(from)
	imm.surface_add_vertex(to)
	imm.surface_end()

	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(tracer.queue_free)


func _process_turret(delta: float) -> void:
	if mounted_turret == null or not is_instance_valid(mounted_turret):
		current_state = State.COMBAT
		return

	# If a player approaches within 2.2m of turret, politely dismount so player can use it
	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container != null:
		for child in players_container.get_children():
			var p := child as PlayerController3D
			if p != null and not p.health_component.is_dead and global_position.distance_to(p.global_position) <= 2.2:
				print("SGCAirmanAI [%s]: Yielding .50 Cal to operative %s!" % [airman_callsign, p.name])
				dismount_turret()
				return

	# Acquire target descending the ramp
	_find_nearest_jaffa()
	if current_target_jaffa != null:
		var target_pos := current_target_jaffa.global_position + Vector3(0, 1.0, 0)
		var aim_dir := (target_pos - mounted_turret.global_position).normalized()
		mounted_turret.try_manual_fire(aim_dir)


func mount_turret(turret: DeployableTurret) -> void:
	if turret == null or turret.mounted_player != null:
		return
	mounted_turret = turret
	turret.mount(self)
	current_state = State.MAN_TURRET
	global_position = turret.global_position + turret.global_transform.basis.z * 0.75
	turret_mounted.emit(turret)
	print("SGCAirmanAI [%s]: Manning .50 Cal Browning emplacement!" % airman_callsign)


func dismount_turret() -> void:
	if mounted_turret != null:
		var t := mounted_turret
		mounted_turret.dismount()
		mounted_turret = null
		current_state = State.COMBAT
		turret_dismounted.emit(t)


func _process_revive(delta: float) -> void:
	if target_player_to_revive == null or not is_instance_valid(target_player_to_revive):
		target_player_to_revive = null
		current_state = State.COMBAT
		return

	var target_health := target_player_to_revive.get_node_or_null("HealthComponent") as HealthComponent
	if target_health == null or not target_health.is_downed:
		target_player_to_revive = null
		current_state = State.COMBAT
		return

	var dist := global_position.distance_to(target_player_to_revive.global_position)
	if dist > 1.8:
		# Sprint to downed squadmate
		var dir := (target_player_to_revive.global_position - global_position).normalized()
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
	current_state = State.ORDER_MOVE
	order_acknowledged.emit(self, "MOVE")
	print("SGCAirmanAI [%s]: Moving to position %s! Taking cover!" % [airman_callsign, str(pos)])


func order_mount_turret(turret: DeployableTurret) -> void:
	if current_state == State.DEAD or current_state == State.DOWNED or turret == null:
		return
	if mounted_turret != null and mounted_turret != turret:
		dismount_turret()
	target_turret_to_mount = turret
	var d := global_position.distance_to(turret.global_position)
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

	var dist := global_position.distance_to(target_turret_to_mount.global_position)
	if dist > 2.0:
		var dir := (target_turret_to_mount.global_position - global_position).normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		mount_turret(target_turret_to_mount)


func _process_order_move(delta: float) -> void:
	var dist := global_position.distance_to(ordered_position)
	var dir := (ordered_position - global_position)
	dir.y = 0.0

	if dist > 1.2:
		velocity.x = dir.normalized().x * move_speed
		velocity.z = dir.normalized().z * move_speed
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

	# While moving or holding, return fire at any Jaffa in range
	_find_nearest_jaffa()
	if current_target_jaffa != null:
		var jaffa_dist := global_position.distance_to(current_target_jaffa.global_position)
		if jaffa_dist <= combat_range and fire_cooldown <= 0.0:
			var aim_dir := (current_target_jaffa.global_position - global_position)
			aim_dir.y = 0.0
			if aim_dir.length_squared() > 0.01 and dist <= 1.2:
				rotation.y = atan2(-aim_dir.x, -aim_dir.z)
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_mp5(aim_dir.normalized())


func _process_order_regroup(delta: float) -> void:
	if order_leader == null or not is_instance_valid(order_leader):
		current_state = State.COMBAT
		return

	var dist := global_position.distance_to(order_leader.global_position)
	var dir := (order_leader.global_position - global_position)
	dir.y = 0.0

	if dist > 2.5:
		velocity.x = dir.normalized().x * move_speed
		velocity.z = dir.normalized().z * move_speed
		rotation.y = atan2(-dir.x, -dir.z)
		if body_mesh != null:
			body_mesh.scale.y = 1.0
			body_mesh.position.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		rotation.y = lerp_angle(rotation.y, order_leader.rotation.y, 8.0 * delta)

	# Cover fire
	_find_nearest_jaffa()
	if current_target_jaffa != null and fire_cooldown <= 0.0:
		var jaffa_dist := global_position.distance_to(current_target_jaffa.global_position)
		if jaffa_dist <= combat_range:
			var aim_dir := (current_target_jaffa.global_position - global_position).normalized()
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_mp5(aim_dir)


func _process_downed_crawl(delta: float) -> void:
	if body_mesh != null:
		body_mesh.scale.y = 0.45
		body_mesh.position.y = 0.2

	# Slow crawl toward nearest cover / sandbags
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)


func _find_nearest_jaffa() -> void:
	var enemies_container := get_tree().root.find_child("Enemies", true, false)
	if enemies_container == null:
		current_target_jaffa = null
		return

	var nearest: JaffaAI = null
	var min_dist := combat_range
	for child in enemies_container.get_children():
		var jaffa := child as JaffaAI
		if jaffa != null and jaffa.health_component != null and not jaffa.health_component.is_dead:
			var d := global_position.distance_to(jaffa.global_position)
			if d < min_dist:
				min_dist = d
				nearest = jaffa
	current_target_jaffa = nearest


func _find_nearest_downed_player() -> PlayerController3D:
	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container == null:
		return null

	for child in players_container.get_children():
		var p := child as PlayerController3D
		if p != null and p.health_component != null and p.health_component.is_downed:
			return p
	return null


func _find_available_turret() -> DeployableTurret:
	for node in get_tree().get_nodes_in_group("turret"):
		var turret := node as DeployableTurret
		if turret != null and turret.mounted_player == null:
			return turret

	# Search by name in GateRoom bunker geometry
	var west := get_tree().root.find_child("TurretWest", true, false) as DeployableTurret
	if west != null and west.mounted_player == null:
		return west
	var east := get_tree().root.find_child("TurretEast", true, false) as DeployableTurret
	if east != null and east.mounted_player == null:
		return east
	return null


func _on_downed() -> void:
	current_state = State.DOWNED
	if mounted_turret != null:
		dismount_turret()
	airman_downed.emit(self)
	print("SGCAirmanAI [%s]: MAN DOWN! Airman is bleeding out!" % airman_callsign)


func _on_revived() -> void:
	current_state = State.COMBAT
	if body_mesh != null:
		body_mesh.scale.y = 1.0
		body_mesh.position.y = 0.0
	airman_revived.emit(self)
	print("SGCAirmanAI [%s]: Back on my feet! Resuming fire!" % airman_callsign)


func _on_died() -> void:
	current_state = State.DEAD
	if mounted_turret != null:
		dismount_turret()
	collision_layer = 0
	airman_died.emit(self)
	print("SGCAirmanAI [%s]: KIA." % airman_callsign)
