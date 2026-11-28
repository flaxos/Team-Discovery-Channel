class_name GoauldShockGrenade
extends Node3D
## Canonical Stargate SG-1 Goa'uld Shock Grenade (SW-3).
## Thrown by Jaffa Shock Grenadiers to flush operatives holding static cover or chokepoints.
## Server simulates a deterministic ballistic arc with wall/floor bounce and 1.45s glowing fuse.
## Detonation checks solid-wall LOS (mask 1), deals bounded concussive damage, and inflicts
## temporary flash-concussion disorientation (0.55x move slow + HUD flash + trauma shake).
## Never names its own class or PlayerController3D/JaffaAI to prevent cyclic script exit leaks.

signal detonated(blast_position: Vector3, affected_count: int)

const KitNetwork := preload("res://scripts/world/FieldKitNetwork.gd")

const BLAST_RADIUS: float = 4.5
const MAX_DAMAGE: float = 25.0
const MIN_DAMAGE: float = 10.0
const DISORIENT_DURATION_S: float = 2.4
const DISORIENT_SPEED_SCALE: float = 0.55
const NOISE_RADIUS: float = 22.0
const GRAVITY: float = 14.5
const BOUNCE_RESTITUTION: float = 0.38
const GROUND_FRICTION: float = 4.5

@export var fuse_time_s: float = 1.45
@export var blast_radius: float = BLAST_RADIUS

var thrower: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var fuse_remaining: float = 1.45
var grounded: bool = false
var _stopped: bool = false
var _pulse_clock: float = 0.0
var detonated_flag: bool = false:
	set(value):
		var was_detonated := detonated_flag
		detonated_flag = value
		if value and not was_detonated and is_node_ready():
			_play_detonation_fx()

@onready var orb_mesh: MeshInstance3D = $OrbMesh if has_node("OrbMesh") else null
@onready var warning_light: OmniLight3D = $WarningLight if has_node("WarningLight") else null


func _enter_tree() -> void:
	KitNetwork.configure(self, ["fuse_time_s", "blast_radius", "detonated_flag"], [])


func _ready() -> void:
	add_to_group(&"shock_grenade")
	fuse_remaining = fuse_time_s
	if detonated_flag:
		_play_detonation_fx()
	if KitNetwork.is_replica(self):
		set_physics_process(false)


func stand_down() -> void:
	_stopped = true
	set_physics_process(false)
	set_process(false)
	if is_inside_tree():
		queue_free()


func launch(initial_velocity: Vector3, owner_hostile: Node3D) -> void:
	thrower = owner_hostile
	velocity = initial_velocity
	fuse_remaining = fuse_time_s
	grounded = false
	detonated_flag = false


func _process(delta: float) -> void:
	if _stopped or detonated_flag:
		return
	_pulse_clock += delta
	if orb_mesh != null:
		orb_mesh.rotation.y += delta * 5.0
		orb_mesh.rotation.x += delta * 3.2
	if warning_light != null:
		var freq := 14.0 if fuse_remaining < 0.55 else 6.0
		warning_light.light_energy = 1.6 + 2.2 * absf(sin(_pulse_clock * freq))


func _physics_process(delta: float) -> void:
	if _stopped or detonated_flag or KitNetwork.is_replica(self):
		return
	_step_ballistics(delta)
	fuse_remaining -= delta
	if fuse_remaining <= 0.0:
		_detonate()


func _step_ballistics(delta: float) -> void:
	var prev_pos := global_position
	if not grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, GROUND_FRICTION * delta)
		velocity.y = 0.0

	var step := velocity * delta
	if step.length_squared() < 0.00001:
		return
	var next_pos := prev_pos + step
	var world3d := get_world_3d()
	if world3d != null and world3d.direct_space_state != null:
		var exclude: Array[RID] = []
		if thrower is CollisionObject3D and is_instance_valid(thrower):
			exclude.append((thrower as CollisionObject3D).get_rid())
		var query := PhysicsRayQueryParameters3D.create(prev_pos, next_pos, 1 | 128, exclude)
		var hit := world3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", next_pos) as Vector3
			var hit_normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
			global_position = hit_pos + hit_normal * 0.14
			if hit_normal.y > 0.65:
				if absf(velocity.y) < 1.8:
					velocity.y = 0.0
					velocity.x *= 0.65
					velocity.z *= 0.65
					grounded = true
				else:
					velocity = velocity.bounce(hit_normal) * BOUNCE_RESTITUTION
			else:
				velocity = velocity.bounce(hit_normal) * BOUNCE_RESTITUTION
			return
	global_position = next_pos


func _has_blast_los(target_pos: Vector3) -> bool:
	var world3d := get_world_3d()
	if world3d == null or world3d.direct_space_state == null:
		return true
	var from := global_position + Vector3.UP * 0.25
	var to := target_pos + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := world3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var col := hit.get("collider") as Node
	if col != null and (col.name.contains("Glass") or col.name.contains("Overlook")):
		return true
	return false


func _detonate() -> void:
	if detonated_flag or _stopped:
		return
	var affected := 0
	var blast_origin := global_position
	var containers: Array[Node] = []
	var players_node := MissionWorld.find(self, "Players")
	if players_node != null:
		containers.append(players_node)
	var allies_node := MissionWorld.find(self, "Allies")
	if allies_node != null:
		containers.append(allies_node)

	var src: Node = thrower if is_instance_valid(thrower) else self
	for container: Node in containers:
		for child: Node in container.get_children():
			var actor := child as Node3D
			if actor == null or not is_instance_valid(actor):
				continue
			var health := actor.get_node_or_null("HealthComponent") as HealthComponent
			if health == null or health.is_dead or health.is_downed:
				continue
			var dist := blast_origin.distance_to(actor.global_position)
			if dist > blast_radius:
				continue
			if not _has_blast_los(actor.global_position):
				continue
			affected += 1
			var falloff := clampf(1.0 - (dist / maxf(blast_radius, 0.1)), 0.0, 1.0)
			var dmg := lerpf(MIN_DAMAGE, MAX_DAMAGE, falloff)
			health.take_damage(dmg, src, "shock_grenade")
			if actor.has_method(&"apply_disorientation"):
				var dur := lerpf(DISORIENT_DURATION_S * 0.6, DISORIENT_DURATION_S, falloff)
				var flash := lerpf(0.45, 0.92, falloff)
				actor.call(&"apply_disorientation", dur, flash, DISORIENT_SPEED_SCALE)

	if is_inside_tree():
		get_tree().call_group(&"noise_listeners", &"hear", blast_origin, NOISE_RADIUS, self)

	detonated_flag = true
	detonated.emit(blast_origin, affected)
	var cleanup := get_tree().create_timer(0.45)
	cleanup.timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			queue_free()
	)


func _play_detonation_fx() -> void:
	if orb_mesh != null:
		orb_mesh.visible = false
	if warning_light != null:
		warning_light.light_color = Color(1.0, 0.96, 0.80)
		warning_light.light_energy = 10.0
		warning_light.omni_range = blast_radius * 2.0
		var lt := create_tween()
		lt.tween_property(warning_light, "light_energy", 0.0, 0.35)
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var flash_sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.1
	flash_sphere.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.92, 0.65, 0.88)
	flash_sphere.material_override = mat
	add_child(flash_sphere)
	var tw := flash_sphere.create_tween()
	tw.tween_property(flash_sphere, "scale", Vector3.ONE * (blast_radius * 1.45), 0.22)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_callback(flash_sphere.queue_free)
	if ResourceLoader.exists("res://audio/sfx_zat.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_zat.wav")
		audio.bus = &"SFX"
		audio.max_distance = 40.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
