class_name ThrownKnife
extends Node3D
## Server-authoritative thrown combat knife (GDD.md:149, SW-1 stealth follow-up).
##
## Specified as an interaction with perception, acoustics, personal shields, and co-op sync:
## - Travels at moderate throwing speed (18 m/s), so an active Goa'uld Personal Shield deflects it
##   (alerting the shielded officer and dropping the knife nearby), whereas close-quarters [F] slow
##   melee and rear [E] stealth takedowns bypass the shield.
## - Hitting an unalerted, unshielded Jaffa deals lethal stealth damage (150 HP, "thrown_knife_stealth")
##   without triggering 1-hop alerts or raising MissionAlert; the corpse remains discoverable unless
##   dragged out of sight or Zat-vaporized.
## - Hitting an alerted Jaffa deals 75 HP ("thrown_knife") combat damage.
## - Hitting world geometry lodges the blade and emits a quiet 8 m acoustic lure through
##   `noise_listeners` (attenuated by walls and closed doors via LevelAcoustics) so operatives can
##   distract patrolling sentries.
## - Lodged/dropped knives can be recovered on the server via proximity pickup or [E] interact,
##   restoring throwing_knives_count up to MAX_THROWING_KNIVES.
##
## Intentionally never references its own `class_name` or `PlayerController3D` by class_name
## to prevent circular script exit leaks.

signal impacted(target: Node, hit_pos: Vector3, deflected: bool)
signal recovered(by_operative: Node)

const KitNetwork := preload("res://scripts/world/FieldKitNetwork.gd")

const SPEED: float = 18.0
const GRAVITY: float = 4.5
const MAX_RANGE: float = 18.0
const STEALTH_DAMAGE: float = 150.0
const COMBAT_DAMAGE: float = 75.0
const DISTRACTION_NOISE_RADIUS: float = 8.0
const AUTO_RECOVER_RADIUS: float = 1.25
const INTERACT_RECOVER_RADIUS: float = 2.4
const FLIGHT_COLLISION_MASK: int = 1 | 2 | 4 | 8 | 16 | 32 | 128

var thrower: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var travel_distance: float = 0.0
var lodged: bool = false:
	set(value):
		lodged = value
		if value and not is_in_group(&"interactable"):
			add_to_group(&"interactable")
var deflected: bool = false
var retrieved: bool = false
var _recover_grace: float = 0.35
var _stopped: bool = false

@onready var visual_pivot: Node3D = $KnifeVisual if has_node("KnifeVisual") else null


func _enter_tree() -> void:
	KitNetwork.configure(self, ["lodged", "deflected", "retrieved"], [])


func _ready() -> void:
	add_to_group(&"thrown_knife")
	if lodged and not is_in_group(&"interactable"):
		add_to_group(&"interactable")
	if KitNetwork.is_replica(self):
		set_physics_process(false)


func stand_down() -> void:
	_stopped = true
	set_physics_process(false)


func launch(direction: Vector3, owner_operative: Node3D) -> void:
	thrower = owner_operative
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else -global_transform.basis.z
	velocity = dir * SPEED + Vector3.UP * 1.15
	travel_distance = 0.0
	lodged = false
	deflected = false
	retrieved = false
	_recover_grace = 0.35
	_orient_along(velocity)


func _orient_along(vec: Vector3) -> void:
	if vec.length_squared() < 0.0001 or not is_inside_tree():
		return
	var target := global_position + vec.normalized()
	if not target.is_equal_approx(global_position):
		var up := Vector3.UP if absf(vec.normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		look_at(target, up)


func _physics_process(delta: float) -> void:
	if _stopped or retrieved or KitNetwork.is_replica(self):
		return
	if lodged:
		if _recover_grace > 0.0:
			_recover_grace = maxf(0.0, _recover_grace - delta)
			return
		_check_auto_recovery()
		return
	_step_flight(delta)


func _step_flight(delta: float) -> void:
	var prev_pos := global_position
	velocity.y -= GRAVITY * delta
	var step := velocity * delta
	var step_len := step.length()
	if step_len < 0.0001:
		return
	var next_pos := prev_pos + step
	var world3d := get_world_3d()
	if world3d != null and world3d.direct_space_state != null:
		var exclude: Array[RID] = []
		if thrower is CollisionObject3D and is_instance_valid(thrower):
			exclude.append((thrower as CollisionObject3D).get_rid())
		var query := PhysicsRayQueryParameters3D.create(prev_pos, next_pos, FLIGHT_COLLISION_MASK, exclude)
		query.collide_with_areas = false
		var hit := world3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_resolve_hit(hit)
			return
	global_position = next_pos
	travel_distance += step_len
	if visual_pivot != null:
		visual_pivot.rotation.x -= delta * 18.0
	if travel_distance >= MAX_RANGE:
		_lodge_at(global_position, Vector3.UP, false)


func _resolve_hit(hit: Dictionary) -> void:
	var collider: Node = hit.get("collider") as Node
	var hit_pos: Vector3 = hit.get("position", global_position) as Vector3
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	if collider != null and is_instance_valid(collider) and collider.has_node("HealthComponent"):
		var enemies := MissionWorld.find(self, "Enemies")
		if enemies != null and collider.get_parent() == enemies:
			var health := collider.get_node_or_null("HealthComponent") as HealthComponent
			if health != null and not health.is_dead:
				var shield_active: bool = collider.has_method(&"has_active_shield") and bool(collider.call(&"has_active_shield"))
				var alerted: bool = int(collider.get(&"awareness_level")) == JaffaPerception.Level.ALERTED
				var dmg := COMBAT_DAMAGE if alerted else STEALTH_DAMAGE
				var dmg_type := "thrown_knife" if alerted else "thrown_knife_stealth"
				health.take_damage(dmg, thrower if is_instance_valid(thrower) else self, dmg_type)
				if shield_active:
					deflected = true
					var drop_pos := _ground_point(hit_pos + hit_normal * 0.65)
					_lodge_at(drop_pos, Vector3.UP, false)
					impacted.emit(collider, hit_pos, true)
					return
				var drop_pos := _ground_point(hit_pos)
				_lodge_at(drop_pos, Vector3.UP, false)
				impacted.emit(collider, hit_pos, false)
				return
	_lodge_at(hit_pos + hit_normal * 0.04, hit_normal, true)
	impacted.emit(collider, hit_pos, false)


func _ground_point(pos: Vector3) -> Vector3:
	var world3d := get_world_3d()
	if world3d == null or world3d.direct_space_state == null:
		return pos
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.4, pos + Vector3.DOWN * 4.0, 1)
	var hit := world3d.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return (hit["position"] as Vector3) + Vector3.UP * 0.08
	return pos


func _lodge_at(pos: Vector3, normal: Vector3, emit_distraction: bool) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	lodged = true
	_recover_grace = 0.25
	if visual_pivot != null:
		visual_pivot.rotation = Vector3(deg_to_rad(-35.0), 0.0, 0.0)
		if normal.length_squared() > 0.01 and absf(normal.dot(Vector3.UP)) < 0.7:
			_orient_along(-normal)
	if emit_distraction and is_inside_tree():
		get_tree().call_group(&"noise_listeners", &"hear", pos, DISTRACTION_NOISE_RADIUS, self)


func _check_auto_recovery() -> void:
	var players := MissionWorld.find(self, "Players")
	if players == null:
		return
	for child in players.get_children():
		var body := child as Node3D
		if body == null or not is_instance_valid(body):
			continue
		if body.global_position.distance_to(global_position) <= AUTO_RECOVER_RADIUS:
			if try_recover(body):
				return


func interact(operative: Node) -> void:
	if not lodged or retrieved or operative == null:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_recover.rpc_id(1, get_path_to(operative))
	else:
		try_recover(operative)


@rpc("any_peer", "call_remote", "reliable")
func request_recover(operative_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var operative := get_node_or_null(operative_path) as Node3D
	if operative == null or MissionWorld.of(operative) != MissionWorld.of(self):
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and operative.get_multiplayer_authority() != sender:
		return
	try_recover(operative)


func try_recover(operative: Node) -> bool:
	if not lodged or retrieved or operative == null or not is_instance_valid(operative):
		return false
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	var body := operative as Node3D
	if body == null or body.global_position.distance_to(global_position) > INTERACT_RECOVER_RADIUS:
		return false
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and (health.is_dead or health.is_downed or health.is_stunned):
		return false
	var current_count: Variant = body.get(&"throwing_knives_count")
	var max_count: Variant = body.get(&"MAX_THROWING_KNIVES")
	if not (current_count is int and max_count is int):
		return false
	if int(current_count) >= int(max_count):
		return false
	body.set(&"throwing_knives_count", int(current_count) + 1)
	if body.has_method(&"_send_field_kit_inventory"):
		body.call(&"_send_field_kit_inventory")
	retrieved = true
	recovered.emit(body)
	queue_free()
	return true
