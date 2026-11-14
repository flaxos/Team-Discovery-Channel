class_name JaffaPerception
extends RefCounted
## Sight and awareness for a patrolling Jaffa (the sentry profile). Server only.
##
## Sight needs range, a horizontal view cone and an unobstructed ray: walls, floors, closed
## doors and smoke all block it. Awareness fills while an operative is seen, faster when close,
## and drains when nothing is. Full awareness is an alert. An alerted Jaffa that has not seen
## anyone for `lose_target_time` reports the target lost, so its owner can investigate.
## Tuning values are exported on JaffaAI so they can differ per scene. `jaffa` is deliberately
## not typed as JaffaAI: the two scripts would then reference each other and never be freed.
enum Level { UNAWARE, SUSPICIOUS, ALERTED }
## Perception runs at this interval, not every physics tick.
const INTERVAL := 0.1
## Awareness while investigating: a sighting during the search alerts quickly.
const SEARCH_AWARENESS := 0.75
const CLOSE_RANGE := 4.0

## The owning JaffaAI. Variant on purpose; see the class comment.
var jaffa: Variant
var level: Level = Level.UNAWARE
var awareness := 0.0
## Where an operative was last seen, or where an alert said to look.
var stimulus := Vector3.INF
## The operative an alerted Jaffa is engaging, while it is still being seen.
var target: Node3D
var searching := false
var unseen := 0.0
var _clock := 0.0
var _containers: Array[Node] = []


func _init(body: Node3D) -> void:
	jaffa = body


## Advances perception by `delta`; the work happens every INTERVAL. Returns "alerted" on the
## tick awareness becomes full, "lost" once an alerted target has been out of sight too long.
func update(delta: float) -> String:
	_clock += delta
	if _clock < INTERVAL:
		return ""
	var dt := _clock
	_clock = 0.0
	var seen := visible_target()
	if seen != null:
		stimulus = seen.global_position
		unseen = 0.0
		if level == Level.ALERTED:
			target = seen
			return ""
		var here: Vector3 = jaffa.global_position
		var span: float = maxf(float(jaffa.sight_range) - CLOSE_RANGE, 0.1)
		var far: float = clampf((here.distance_to(stimulus) - CLOSE_RANGE) / span, 0.0, 1.0)
		var notice: float = lerpf(float(jaffa.notice_time_near), float(jaffa.notice_time_far), far)
		awareness = minf(1.0, awareness + dt / notice)
		if awareness >= 1.0:
			alert(seen, stimulus)
			return "alerted"
		level = Level.SUSPICIOUS
		return ""
	if level == Level.ALERTED:
		unseen += dt
		target = null
		return "lost" if unseen >= float(jaffa.lose_target_time) else ""
	if not searching:
		awareness = maxf(0.0, awareness - dt / float(jaffa.forget_time))
		level = Level.SUSPICIOUS if awareness > 0.0 else Level.UNAWARE
	return ""


## Full alert. `by` may be null when the cause is not an operative.
func alert(by: Node3D, at: Vector3) -> void:
	level = Level.ALERTED
	awareness = 1.0
	target = by
	stimulus = at
	unseen = 0.0
	searching = false


## The target is lost: hold suspicion while the owner searches the last seen position.
func investigate() -> void:
	level = Level.SUSPICIOUS
	awareness = SEARCH_AWARENESS
	target = null
	searching = true


func calm() -> void:
	level = Level.UNAWARE
	awareness = 0.0
	target = null
	searching = false
	unseen = 0.0


## Nearest operative in sight. A downed one only counts when no standing one is seen.
func visible_target() -> Node3D:
	var standing: Array[Node3D] = []
	var downed: Array[Node3D] = []
	for container in _operative_containers():
		for child in container.get_children():
			var body := child as Node3D
			var health := child.get_node_or_null("HealthComponent") as HealthComponent
			if body != null and health != null and not health.is_dead:
				(downed if health.is_downed else standing).append(body)
	var best := _nearest_seen(standing)
	return best if best != null else _nearest_seen(downed)


func can_see(body: Node3D) -> bool:
	var here: Vector3 = jaffa.global_position
	var offset: Vector3 = body.global_position - here
	if offset.length() > float(jaffa.sight_range):
		return false
	var flat := Vector3(offset.x, 0.0, offset.z)
	if offset.length() > float(jaffa.proximity_radius) and flat.length_squared() > 0.01:
		var basis: Basis = jaffa.global_basis
		var forward: Vector3 = -basis.z
		forward.y = 0.0
		if forward.angle_to(flat) > deg_to_rad(float(jaffa.sight_cone_deg) * 0.5):
			return false
	return bool(jaffa._has_line_of_sight(body, true))


func _nearest_seen(bodies: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for body in bodies:
		var here: Vector3 = jaffa.global_position
		var distance: float = here.distance_to(body.global_position)
		if distance < best_distance and can_see(body):
			best = body
			best_distance = distance
	return best


## Operative containers, looked up once and again only if they leave the tree.
func _operative_containers() -> Array[Node]:
	for node in _containers:
		if not is_instance_valid(node) or not node.is_inside_tree():
			_containers.clear()
			break
	if _containers.is_empty() and bool(jaffa.is_inside_tree()):
		for id: String in ["Players", "Allies"]:
			# The sentry's own world: with two loaded, the other one's operatives are not here.
			var found: Node = MissionWorld.find(jaffa as Node, id)
			if found != null:
				_containers.append(found)
	return _containers
