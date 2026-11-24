class_name DeployableTurret
extends Node3D
## SGC Browning M2HB .50 Cal Deployable Heavy Machine Gun.
## Operates in automated sentry mode OR mounted by an operative via [E] for manual suppressing fire.

signal turret_fired(origin: Vector3, dir: Vector3)
signal player_mounted(player: Node)
signal player_dismounted(player: Node)
## Metres the blast or shot is heard by patrolling sentries (JaffaAI.hear).
const NOISE_RADIUS := 35.0
const MOUNT_REACH := 2.4
const GUNNER_REAR_OFFSET := 1.0
const TurretVisual := preload("res://scripts/assets/M2TurretVisual.gd")

@export var fire_rate_rpm: float = 500.0
@export var damage: float = 52.0
@export var auto_targeting_range: float = 28.0
@export var is_automated_sentry: bool = false
@export var mounted_spread_deg: float = 0.25
@export var gun_shield_damage_reduction: float = 0.65

var fire_cooldown: float = 0.0
var current_target: Node3D = null
var mounted_player: CharacterBody3D = null
var mounted_actor_path: NodePath
var _remote_aim := Vector3.ZERO
var _remote_fire := false

@onready var muzzle_point: Marker3D = $TurretHead/MuzzlePoint if has_node("TurretHead/MuzzlePoint") else null
@onready var turret_head: Node3D = $TurretHead if has_node("TurretHead") else null
@onready var interact_area: Area3D = $InteractArea if has_node("InteractArea") else null


func _enter_tree() -> void:
	var net := get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	var sync := get_node_or_null("TurretReplication") as MultiplayerSynchronizer
	if net != null and sync != null:
		net.configure_mission_sync(sync)


func _exit_tree() -> void:
	_set_occupant(null)


func _ready() -> void:
	add_to_group("turret")
	add_to_group("mounted_turret")
	if TurretVisual.attach(self, turret_head):
		for path: String in ["TripodBase", "TurretHead/ReceiverMesh", "TurretHead/GunShieldMesh"]:
			var fallback := get_node_or_null(path) as MeshInstance3D
			if fallback != null:
				fallback.hide()
		var shield := get_node_or_null("TurretHead/FittedGunShield") as Node3D
		if shield != null:
			shield.show()
	if interact_area != null:
		interact_area.body_entered.connect(_on_interact_entered)
		interact_area.body_exited.connect(_on_interact_exited)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		var replica := get_node_or_null(mounted_actor_path) as CharacterBody3D if not mounted_actor_path.is_empty() else null
		_set_occupant(replica)
		_place_occupant()
		return

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	if is_instance_valid(mounted_player):
		var operative := mounted_player as PlayerController3D
		if operative != null and (not operative.is_inside_tree() or operative.is_queued_for_deletion() \
				or (operative.health_component != null and (operative.health_component.is_downed \
					or operative.health_component.is_dead))):
			dismount()
			return
		var remote := operative != null and not operative.is_local_authority
		var target: Vector3 = _remote_aim if remote else mounted_player.get("current_aim_target")
		_aim_head(target)
		_place_occupant()
		if remote and _remote_fire and turret_head != null and target != Vector3.ZERO \
				and (operative.health_component == null or not operative.health_component.is_stunned):
			try_manual_fire((target - turret_head.global_position).normalized())
		_remote_fire = false
		return
	if not mounted_actor_path.is_empty():
		dismount()

	# Sentry mode: server authoritative target acquisition
	if not is_automated_sentry or not multiplayer.is_server():
		return

	_find_target()
	if current_target != null:
		var target_pos := current_target.global_position + Vector3(0, 1.0, 0)
		var aim_dir := (target_pos - global_position).normalized()

		if turret_head != null:
			turret_head.look_at(target_pos, Vector3.UP)

		if fire_cooldown <= 0.0:
			fire_cooldown = 60.0 / fire_rate_rpm
			_fire_shot(aim_dir)


func _aim_head(target: Vector3) -> void:
	if target == Vector3.ZERO or turret_head == null:
		return
	var flat_target := Vector3(target.x, turret_head.global_position.y, target.z)
	if turret_head.global_position.distance_squared_to(flat_target) > 0.2:
		turret_head.look_at(flat_target, Vector3.UP)


func try_manual_fire(aim_dir: Vector3) -> bool:
	if not multiplayer.is_server() or fire_cooldown > 0.0 or aim_dir == Vector3.ZERO:
		return false
	fire_cooldown = 60.0 / fire_rate_rpm
	_fire_shot(aim_dir)
	return true


func receive_player_input(target: Vector3, fire: bool) -> bool:
	if not multiplayer.is_server():
		_request_input.rpc_id(1, target, fire)
		return false
	_aim_head(target)
	_place_occupant()
	return fire and turret_head != null and target != Vector3.ZERO \
		and try_manual_fire((target - turret_head.global_position).normalized())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _request_input(target: Vector3, fire: bool) -> void:
	if not multiplayer.is_server() or not is_instance_valid(mounted_player) or not target.is_finite():
		return
	var operative := mounted_player as PlayerController3D
	if operative == null or multiplayer.get_remote_sender_id() != operative.peer_id:
		return
	_remote_aim = target
	_remote_fire = fire


func request_mount(player: PlayerController3D) -> void:
	if multiplayer.is_server():
		_mount_in_reach(player)
	elif player.is_local_authority:
		_request_mount.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_mount() -> void:
	if not multiplayer.is_server():
		return
	var world := MissionWorld.of(self) as GateRoom
	if world != null:
		var actor := world.players_container.get_node_or_null(str(multiplayer.get_remote_sender_id())) as PlayerController3D
		_mount_in_reach(actor)


func _mount_in_reach(player: PlayerController3D) -> void:
	if player != null and not is_instance_valid(player.mounted_turret) and player.health_component != null \
			and not player.health_component.is_dead and not player.health_component.is_downed \
			and not player.health_component.is_stunned \
			and global_position.distance_to(player.global_position) < MOUNT_REACH:
		mount(player)


func mount(player: CharacterBody3D) -> void:
	if not multiplayer.is_server() or is_instance_valid(mounted_player):
		return
	mounted_actor_path = get_path_to(player)
	_set_occupant(player)
	_place_occupant()
	player_mounted.emit(player)
	print("DeployableTurret: Operative %s mounted the .50 Cal Browning!" % player.name)


func mount_airman(airman: CharacterBody3D) -> void:
	mount(airman)


func _set_occupant(actor: CharacterBody3D) -> void:
	if is_instance_valid(mounted_player):
		if mounted_player == actor:
			return
		var previous := mounted_player as PlayerController3D
		if previous != null and previous.mounted_turret == self:
			previous.mounted_turret = null
	mounted_player = actor
	if actor is PlayerController3D:
		(actor as PlayerController3D).mounted_turret = self


func _place_occupant() -> void:
	if not is_instance_valid(mounted_player) or turret_head == null:
		return
	var rear := turret_head.global_basis.z
	rear.y = 0.0
	rear = rear.normalized()
	mounted_player.global_position = global_position + rear * GUNNER_REAR_OFFSET
	mounted_player.velocity = Vector3.ZERO
	var yaw := atan2(rear.x, rear.z)
	var operative := mounted_player as PlayerController3D
	if operative != null:
		# The camera still follows the operative's input yaw. Only the body faces the receiver.
		if operative.visuals != null:
			operative.visuals.global_rotation = Vector3(0, yaw, 0)
	else:
		mounted_player.global_rotation = Vector3(0, yaw, 0)


func dismount() -> void:
	if not multiplayer.is_server():
		if is_instance_valid(mounted_player) and mounted_player is PlayerController3D \
				and (mounted_player as PlayerController3D).is_local_authority:
			_request_dismount.rpc_id(1)
		return
	var previous := mounted_player
	mounted_actor_path = NodePath()
	_remote_aim = Vector3.ZERO
	_remote_fire = false
	_set_occupant(null)
	if is_instance_valid(previous):
		player_dismounted.emit(previous)
		print("DeployableTurret: Operative %s dismounted the .50 Cal Browning." % previous.name)


@rpc("any_peer", "call_remote", "reliable")
func _request_dismount() -> void:
	if multiplayer.is_server() and is_instance_valid(mounted_player) and mounted_player is PlayerController3D \
			and (mounted_player as PlayerController3D).peer_id == multiplayer.get_remote_sender_id():
		dismount()


func _on_interact_entered(body: Node) -> void:
	if body is PlayerController3D and (body as PlayerController3D).is_local_authority:
		print("DeployableTurret: In range of .50 Cal. Press [E] to mount.")


func _on_interact_exited(body: Node) -> void:
	if multiplayer.is_server() and body == mounted_player:
		dismount()


func _find_target() -> void:
	var enemies_container := MissionWorld.find(self, "Enemies")
	if enemies_container == null:
		return

	var nearest: Node3D = null
	var min_dist := auto_targeting_range

	for child in enemies_container.get_children():
		var jaffa := child as JaffaAI
		if jaffa != null and jaffa.health_component != null and not jaffa.health_component.is_dead:
			var d := global_position.distance_to(jaffa.global_position)
			if d < min_dist:
				min_dist = d
				nearest = jaffa

	current_target = nearest


func _fire_shot(dir: Vector3) -> void:
	var origin: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.0, -0.8)

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * auto_targeting_range)
	query.collision_mask = 1 | 4  # World and Jaffa

	var result := space.intersect_ray(query)
	var hit_pos := origin + dir * auto_targeting_range

	if not result.is_empty():
		hit_pos = result["position"]
		var hit_node := result["collider"] as Node
		if hit_node != null:
			var health := hit_node.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(damage, self, "50cal_heavy")

	turret_fired.emit(origin, dir)
	get_tree().call_group(&"noise_listeners", &"hear", origin, NOISE_RADIUS, self)
	var world := MissionWorld.of(self) as GateRoom
	if world != null:
		var operative := mounted_player as PlayerController3D if is_instance_valid(mounted_player) else null
		var operator_id := operative.peer_id if operative != null else 0
		world.play_turret_fx(origin, hit_pos, operator_id)
		SGCNetworkManager.mission_rpc(world, &"play_turret_fx", [origin, hit_pos, operator_id])
	else:
		show_turret_fx(self, origin, hit_pos)


static func show_turret_fx(parent: Node, origin: Vector3, hit_point: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tracer := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	tracer.mesh = imm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.3, 0.95)
	tracer.material_override = mat
	tracer.top_level = true
	parent.add_child(tracer)

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(origin)
	imm.surface_add_vertex(hit_point)
	imm.surface_end()

	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(tracer.queue_free)

	if ResourceLoader.exists("res://audio/sfx_m249.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_m249.wav")
		audio.max_distance = 60.0
		audio.unit_size = 12.0
		parent.add_child(audio)
		audio.global_position = origin
		audio.finished.connect(audio.queue_free)
		audio.play()
