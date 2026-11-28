class_name JaffaAI
extends CharacterBody3D
## Goa'uld Serpent / Horus Guard Enemy AI.
## Advances down the Stargate ramp, takes tactical firing positions,
## discharges liquid Naquadah plasma bolts, and enforces canonical Zat status effects.

signal jaffa_died(killer: Node)
signal jaffa_vaporized()
signal staff_fired(origin: Vector3, direction: Vector3)
signal staff_visual_fired
signal patrol_waypoint_reached(index: int)
signal patrol_lap_completed(laps: int)
signal body_discovered(corpse: Node3D, lethal: bool)
signal rally_command_issued(rallied_count: int)
signal shock_grenade_thrown(grenade: Node3D, target_pos: Vector3)
signal kara_kesh_push_fired(affected_count: int)
signal kara_kesh_beam_started(target: Node3D)
signal kara_kesh_beam_ticked(target: Node3D, damage: float)
signal kara_kesh_beam_ended(reason: String)

const ROLE_TROOPER: String = "trooper"
const ROLE_OFFICER: String = "officer"
const ROLE_HEAVY: String = "heavy"
const ROLE_GRENADIER: String = "grenadier"
const ROLE_GOAULD_LORD: String = "goauld_lord"
const VALID_ROLES: PackedStringArray = [
	ROLE_TROOPER, ROLE_OFFICER, ROLE_HEAVY, ROLE_GRENADIER, ROLE_GOAULD_LORD
]

const SHOCK_GRENADE_SCENE_PATH: String = "res://scenes/weapons/GoauldShockGrenade.tscn"
const OFFICER_ALERT_RADIUS: float = 30.0
const OFFICER_RALLY_RADIUS: float = 12.0
const BOSS_RALLY_RADIUS: float = 14.0
const OFFICER_RALLY_COOLDOWN_S: float = 7.5
const RALLY_RESOLVE_DURATION_S: float = 2.5
const HEAVY_FRONTAL_DAMAGE_SCALE: float = 0.70
const HEAVY_SUPPRESSION_HITS: int = 5
const HEAVY_SUPPRESSION_HOLD: float = 0.8
const HEAVY_SUPPRESSION_LIMIT: float = 1.6
const HEAVY_BOLT_SPEED: float = 24.0
const MAX_SHOCK_GRENADES: int = 3
const SHOCK_GRENADE_COOLDOWN_S: float = 9.5
const SHOCK_GRENADE_MIN_RANGE: float = 4.5
const SHOCK_GRENADE_MAX_RANGE: float = 18.0
const KARA_KESH_PUSH_RANGE: float = 10.5
const KARA_KESH_PUSH_HALF_ANGLE_COS: float = 0.5735  # ~55 deg half-angle (~110 deg cone; forgiving close arc)
const KARA_KESH_PUSH_CHARGE_S: float = 0.55
const KARA_KESH_PUSH_COOLDOWN_S: float = 7.0
const KARA_KESH_PUSH_DAMAGE: float = 32.0
const KARA_KESH_PUSH_IMPULSE: float = 13.5
const KARA_KESH_BEAM_MIN_RANGE: float = 3.5
const KARA_KESH_BEAM_MAX_RANGE: float = 16.0
const KARA_KESH_BEAM_CHARGE_S: float = 0.65
const KARA_KESH_BEAM_DURATION_S: float = 2.2
const KARA_KESH_BEAM_TICK_S: float = 0.35
const KARA_KESH_BEAM_TICK_DAMAGE: float = 14.0
const KARA_KESH_BEAM_COOLDOWN_S: float = 8.5

enum KaraKeshState { IDLE, CHARGING_PUSH, CHARGING_BEAM, CHANNELING_BEAM }

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
@export var has_personal_shield: bool = false:
	set(value):
		has_personal_shield = value
		if personal_shield != null and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server() or personal_shield._last_revision < 0):
			personal_shield.set_shield_enabled(value)
@export var combat_role: String = ROLE_TROOPER:
	set(value):
		var clean := value.strip_edges().to_lower()
		if not VALID_ROLES.has(clean):
			clean = ROLE_TROOPER
		combat_role = clean
		if is_node_ready():
			_refresh_role_visuals()
@export var boss_display_name: String = "GOA'ULD SYSTEM LORD":
	set(value):
		boss_display_name = value
		if is_node_ready():
			_refresh_role_visuals()
@export var move_speed: float = 4.2
@export var march_speed: float = 2.4
@export var combat_run_speed: float = 5.5
@export var combat_range: float = 22.0
@export var melee_range: float = 2.2
@export var plasma_damage: float = 45.0
@export var fire_interval_s: float = 2.8
@export var staff_accuracy_spread_deg: float = 3.5

## ASSAULT is the original behaviour, kept for gate waves and column marches. SENTRY is used by
## patrols: it only knows what it sees (JaffaPerception). `start_patrol` selects SENTRY.
enum Profile { ASSAULT, SENTRY }

@export_group("Sentry perception")
@export var sight_range: float = 24.0
## Full horizontal angle of the view cone.
@export var sight_cone_deg: float = 110.0
## Within this distance an operative in line of sight is noticed from any direction.
@export var proximity_radius: float = 1.5
## Seconds of continuous sight to go from unaware to alerted, close up and at sight_range.
@export var notice_time_near: float = 0.8
@export var notice_time_far: float = 2.5
## Seconds for full suspicion to drain away once nothing is seen.
@export var forget_time: float = 3.0
## Seconds an alerted Jaffa keeps fighting an unseen target before it goes to look.
@export var lose_target_time: float = 1.5
## Seconds spent looking around at the last seen position before searching nearby.
@export var investigate_wait: float = 3.0
## Longest walk towards the last seen position before searching from where it is.
@export var investigate_travel_limit: float = 20.0
## After looking at the last seen position, visit this many reachable points around it.
@export var search_points: int = 3
## How far from the last seen position the search points are.
@export var search_radius: float = 5.0
## Seconds spent looking around at each search point.
@export var search_look_time: float = 1.5
@export_group("")

var profile: Profile = Profile.ASSAULT
var perception: JaffaPerception
## Replicated for the overhead tell: JaffaPerception.Level and its 0..1 fill.
var awareness_level: int = 0
var awareness: float = 0.0
var investigating := false
## Set on every peer by the mission's alert director while this Jaffa runs for an alarm console.
var raising_alarm := false
## Server: where this Jaffa is running to (Vector3.INF when not on an errand), and what to face.
var errand := Vector3.INF
var _errand_look := Vector3.INF
var _search_clock := 0.0
var _search_wait := -1.0
## Search points still to visit after looking at the last seen position.
var _search_route: Array[Vector3] = []
var _search_leg := 0.0
var _tell: Label3D

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
## Modular levels: the cover prop this Jaffa is fighting from (LevelNavigator.prop_cover), if any.
var cover_prop: Node3D = null
## Modular flanks use a committed alternate entrance to a last-seen position, on the host.
const FLANK_LIMIT := 20.0
const FLANK_COOLDOWN := 8.0
var _flank_navigation: LevelNavigator
var _flank_known := Vector3.INF
var _flank_time := 0.0
var _flank_cooldown := 0.0
var _flank_subject: WeakRef
var flank_status := "idle"
## Replicated through the guard's existing pose synchronizer for the overhead tell.
var is_suppressed := false
const INCOMING_FIRE_WINDOW := 0.65
const SUPPRESSION_HOLD := 1.3
const SUPPRESSION_LIMIT := 3.0
const SUPPRESSION_RECOVERY := 1.0
var _incoming_fire_window := 0.0
var _incoming_fire_hits := 0
var _suppression_hold := 0.0
var _suppression_limit := 0.0
var _suppression_recovery := 0.0
var _suppression_cover := Vector3.INF
var _rally_resolve_timer := 0.0
var _rally_cooldown := 2.0
var _burst_shots_remaining: int = 0
var _burst_shot_timer: float = 0.0
var shock_grenades_remaining: int = 0
var _shock_grenade_cooldown: float = 2.0
## Replicated Kara Kesh phase for Goa'uld System Lord boss visuals on every peer.
var kara_kesh_state: int = KaraKeshState.IDLE:
	set(value):
		kara_kesh_state = value
		if is_node_ready():
			_update_kara_kesh_visuals()
var _kara_kesh_phase_timer: float = 0.0
var _kara_kesh_tick_timer: float = 0.0
var _kara_kesh_push_cd: float = 1.5
var _kara_kesh_beam_cd: float = 3.0
var _kara_kesh_beam_target: Node3D = null
var _kara_kesh_beam_end: Vector3 = Vector3.ZERO
var _kara_kesh_beam_mesh: MeshInstance3D = null
var _role_badge: Label3D = null
var _role_accent: Node3D = null
## Staff height while standing to fire over a cover prop, above the tallest low cover.
const OVER_COVER_STAFF_HEIGHT := 1.35
## Seconds left standing up to fire over cover, and until the cover is re-checked.
var _peek := 0.0
var _cover_check := 0.0
var suppressive_hold_timer: float = 0.0
var _death_notified: bool = false
## Server-side body discovery flag: prevents repeated rediscovery of the same fallen or stunned Jaffa.
var body_discovered_flag: bool = false
var navigator: SGCNavigator
var overrun_destination_index: int = 0
var patrol_points: Array[Vector3] = []
var patrol_index: int = 0
var patrol_loop: bool = true
var patrol_laps: int = 0

@onready var health_component: HealthComponent = $HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var staff_mount: Node3D = $StaffMount if has_node("StaffMount") else null
@onready var muzzle_point: Marker3D = $StaffMount/MuzzlePoint if has_node("StaffMount/MuzzlePoint") else null
@onready var kara_kesh_mount: Node3D = $KaraKeshMount if has_node("KaraKeshMount") else null
@onready var kara_kesh_light: OmniLight3D = $KaraKeshMount/ChargeLight if has_node("KaraKeshMount/ChargeLight") else null
@onready var stun_fx: Node3D = $Visuals/StunFX if has_node("Visuals/StunFX") else null
@onready var body_mesh: MeshInstance3D = $Visuals/ArmorMesh if has_node("Visuals/ArmorMesh") else null
@onready var visuals_root: Node3D = $Visuals if has_node("Visuals") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var personal_shield: GoauldPersonalShield = $PersonalShield if has_node("PersonalShield") else null


func _enter_tree() -> void:
	var net: SGCNetworkManager = get_node_or_null("/root/NetworkManager") as SGCNetworkManager
	if net != null and has_node("MultiplayerSynchronizer"):
		net.configure_mission_sync($MultiplayerSynchronizer)


func _ready() -> void:
	collision_mask |= 128
	# Server is authoritative over AI logic
	set_multiplayer_authority(1)
	navigator = SGCNavigator.new(self)
	perception = JaffaPerception.new(self)
	_build_tell()

	if is_shock_guard:
		if health_component != null:
			health_component.max_health = 140.0
			health_component.current_health = 140.0
		move_speed = 4.8
		combat_run_speed = 5.8
		plasma_damage = 42.0
		fire_interval_s = 1.4

	_apply_role_stats()

	if health_component != null:
		health_component.died.connect(_on_died)
		health_component.stunned.connect(_on_stunned)
		health_component.recovered_from_stun.connect(_on_recovered_from_stun)
		health_component.vaporized.connect(_on_vaporized)
		health_component.damage_taken.connect(_on_damage_taken)

	# Randomize initial fire offset so multiple Jaffa don't shoot in unison
	fire_timer = randf_range(0.5, fire_interval_s)

	if personal_shield != null:
		personal_shield.set_shield_enabled(has_personal_shield, false)
		personal_shield.shield_deflected.connect(_on_shield_deflected)
		personal_shield.shield_overloaded.connect(_on_shield_overloaded)

	if not is_boss():
		_setup_staff_visual()
	_refresh_role_visuals()
	_update_kara_kesh_visuals()


func is_boss() -> bool:
	return combat_role == ROLE_GOAULD_LORD


func is_officer() -> bool:
	return combat_role == ROLE_OFFICER


func is_heavy() -> bool:
	return combat_role == ROLE_HEAVY


func is_grenadier() -> bool:
	return combat_role == ROLE_GRENADIER


func role_label() -> String:
	match combat_role:
		ROLE_OFFICER:
			return "FIRST PRIME"
		ROLE_HEAVY:
			return "HEAVY CANNON"
		ROLE_GRENADIER:
			return "SHOCK GRENADIER"
		ROLE_GOAULD_LORD:
			return boss_display_name if not boss_display_name.strip_edges().is_empty() else "GOA'ULD SYSTEM LORD"
		_:
			return ""


func alarm_raise_speed_multiplier() -> float:
	return 0.75 if combat_role == ROLE_OFFICER else 1.0


func _apply_role_stats() -> void:
	match combat_role:
		ROLE_OFFICER:
			if health_component != null:
				var hp := 160.0 if is_shock_guard else 135.0
				health_component.max_health = hp
				health_component.current_health = hp
			move_speed = maxf(move_speed, 4.5)
			combat_run_speed = maxf(combat_run_speed, 5.8)
			combat_range = 24.0
		ROLE_HEAVY:
			if health_component != null:
				health_component.max_health = 220.0
				health_component.current_health = 220.0
			move_speed = 3.2
			combat_run_speed = 4.0
			plasma_damage = 34.0
			fire_interval_s = 2.4
			staff_accuracy_spread_deg = 4.5
		ROLE_GRENADIER:
			if health_component != null:
				health_component.max_health = 115.0
				health_component.current_health = 115.0
			move_speed = maxf(move_speed, 4.4)
			combat_run_speed = maxf(combat_run_speed, 5.5)
			shock_grenades_remaining = MAX_SHOCK_GRENADES
		ROLE_GOAULD_LORD:
			is_shock_guard = true
			has_personal_shield = true
			if health_component != null:
				health_component.max_health = 320.0
				health_component.current_health = 320.0
			if personal_shield != null:
				personal_shield.max_energy = 140.0
				personal_shield.energy = 140.0
			move_speed = 3.9
			combat_run_speed = 5.0
			combat_range = 24.0
			plasma_damage = 38.0
			fire_interval_s = 2.0


func modify_incoming_damage(amount: float, source: Node, damage_type: String) -> float:
	if combat_role != ROLE_HEAVY:
		return amount
	if damage_type not in ["bullet", "50cal_heavy"]:
		return amount
	if source == null or not is_instance_valid(source) or not (source is Node3D):
		return amount
	var forward := -global_transform.basis.z
	forward.y = 0.0
	var to_source := (source as Node3D).global_position - global_position
	to_source.y = 0.0
	if forward.length_squared() < 0.0001 or to_source.length_squared() < 0.0001:
		return amount
	if forward.normalized().dot(to_source.normalized()) > 0.15:
		return amount * HEAVY_FRONTAL_DAMAGE_SCALE
	return amount


func _refresh_role_visuals() -> void:
	var label_text := role_label()
	if label_text.is_empty():
		if _role_badge != null:
			_role_badge.visible = false
		if _role_accent != null:
			_role_accent.visible = false
		return
	if _role_badge == null:
		_role_badge = Label3D.new()
		_role_badge.name = "RoleBadge"
		_role_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_role_badge.font_size = 42 if is_boss() else 34
		_role_badge.outline_size = 10
		add_child(_role_badge)
	_role_badge.position = Vector3(0.0, 2.34 if is_boss() else 2.18, 0.0)
	_role_badge.text = label_text
	match combat_role:
		ROLE_OFFICER:
			_role_badge.modulate = Color(0.98, 0.82, 0.28)
		ROLE_HEAVY:
			_role_badge.modulate = Color(0.95, 0.48, 0.24)
		ROLE_GRENADIER:
			_role_badge.modulate = Color(0.36, 0.85, 1.0)
		ROLE_GOAULD_LORD:
			_role_badge.modulate = Color(1.0, 0.85, 0.25)
	_role_badge.visible = current_state != State.DEAD

	if _tell != null and is_boss():
		_tell.position = Vector3(0.0, 2.68, 0.0)

	if is_boss():
		return
	if _role_accent != null:
		_role_accent.queue_free()
		_role_accent = null
	if visuals_root == null:
		return
	_role_accent = Node3D.new()
	_role_accent.name = "RoleAccent"
	visuals_root.add_child(_role_accent)
	var accent_mat := StandardMaterial3D.new()
	accent_mat.metallic = 0.0
	accent_mat.roughness = 0.28
	match combat_role:
		ROLE_OFFICER:
			accent_mat.albedo_color = Color(0.95, 0.78, 0.22)
			for side: float in [-0.34, 0.34]:
				var ep := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(0.20, 0.09, 0.24)
				b.material = accent_mat
				ep.mesh = b
				ep.position = Vector3(side, 1.46, 0.0)
				_role_accent.add_child(ep)
		ROLE_HEAVY:
			accent_mat.albedo_color = Color(0.68, 0.28, 0.16)
			for side: float in [-0.40, 0.40]:
				var pauldron := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(0.24, 0.26, 0.34)
				b.material = accent_mat
				pauldron.mesh = b
				pauldron.position = Vector3(side, 1.36, 0.0)
				_role_accent.add_child(pauldron)
		ROLE_GRENADIER:
			accent_mat.albedo_color = Color(0.35, 0.82, 0.96)
			accent_mat.emission_enabled = true
			accent_mat.emission = Color(0.35, 0.82, 0.96)
			accent_mat.emission_energy_multiplier = 0.65
			for side: float in [-0.30, 0.30]:
				var orb := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.09
				s.height = 0.18
				s.material = accent_mat
				orb.mesh = s
				orb.position = Vector3(side, 0.96, -0.22)
				_role_accent.add_child(orb)


func has_active_shield() -> bool:
	return personal_shield != null and personal_shield.is_active()


func set_personal_shield_enabled(enabled: bool) -> void:
	has_personal_shield = enabled
	if personal_shield != null:
		personal_shield.set_shield_enabled(enabled)


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


## Walks the waypoints in order through the shared navigator; resumes after combat.
func start_patrol(points: Array[Vector3], loop: bool = true) -> void:
	_clear_modular_flank()
	_clear_suppression()
	patrol_points = points.duplicate()
	patrol_index = 0
	patrol_laps = 0
	patrol_loop = loop
	profile = Profile.SENTRY
	add_to_group(&"noise_listeners")
	if current_state not in [State.DEAD, State.STUNNED, State.DOWNED]:
		current_state = State.PATROL


## Mission over: stop fighting and moving for good. Safe on replicas.
func stand_down() -> void:
	_clear_modular_flank()
	_clear_suppression()
	_burst_shots_remaining = 0
	_burst_shot_timer = 0.0
	_cancel_kara_kesh("stand_down")
	if personal_shield != null:
		personal_shield.stand_down()
	current_target = null
	velocity = Vector3.ZERO
	investigating = false
	errand = Vector3.INF
	raising_alarm = false
	cover_prop = null
	if perception != null:
		perception.calm()
	awareness_level = JaffaPerception.Level.UNAWARE
	awareness = 0.0
	if current_state not in [State.DEAD, State.STUNNED, State.DOWNED]:
		_set_crouching(false)
		_reset_staff_position()
		current_state = State.IDLE
	set_physics_process(false)


func _resume_state() -> State:
	if patrol_points.is_empty():
		return State.ADVANCE
	return State.CHASE if profile == Profile.SENTRY and investigating else State.PATROL


## Server side: run perception and react to what it reports.
func _update_perception(delta: float) -> void:
	match perception.update(delta):
		"alerted":
			_engage(perception.target, true)
		"lost":
			if _flank_navigation == null:
				_start_investigation()
			else:
				# Continue only the bounded plan to the last sighting, never chase hidden motion.
				current_target = null
		"body_dead":
			var corpse: Node3D = perception.discovered_body
			perception.discovered_body = null
			if corpse != null and is_instance_valid(corpse):
				corpse.set(&"body_discovered_flag", true)
				body_discovered.emit(corpse, true)
				investigating = false
				current_target = null
				perception.alert(null, corpse.global_position)
				var compound_alert := MissionWorld.find(self, "Alert") as MissionAlert
				if compound_alert != null:
					compound_alert.report_body_discovered(corpse.global_position)
				if current_state not in [State.DEAD, State.STUNNED, State.DOWNED]:
					current_state = State.CHASE
		"body_stunned":
			var stunned_body: Node3D = perception.discovered_body
			perception.discovered_body = null
			if stunned_body != null and is_instance_valid(stunned_body):
				stunned_body.set(&"body_discovered_flag", true)
				body_discovered.emit(stunned_body, false)
				investigate_at(stunned_body.global_position)
	if perception.level == JaffaPerception.Level.ALERTED and perception.target != null:
		current_target = perception.target
	_publish_awareness()


## Turn an alert into combat. `spread` passes it to nearby Jaffa (one hop).
func _engage(target: Node3D, spread: bool) -> void:
	current_target = target
	investigating = false
	if not is_suppressed and current_state in [State.PATROL, State.ADVANCE, State.IDLE, State.CHASE, State.MARCHING_FORMATION]:
		break_formation_and_engage()
	if spread:
		_alert_nearby_formation_jaffa()


## Server: a noise at `at` that carries `radius` metres with wall and closed-door attenuation.
## A sentry within effective acoustic range that is not already fighting turns suspicious and
## goes to look. Called through the `noise_listeners` group by weapons and explosives.
func hear(at: Vector3, radius: float, source: Node = null) -> void:
	if profile != Profile.SENTRY or perception == null or not is_physics_processing():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if source != null and is_instance_valid(source) and MissionWorld.of(source) != MissionWorld.of(self):
		return
	if errand != Vector3.INF or global_position.distance_to(at) > radius:
		return
	var world_node := MissionWorld.of(self)
	var level := world_node.get_node_or_null("Level") as LevelAssembly if world_node != null else null
	if LevelAcoustics.effective_distance(get_world_3d(), level, at, global_position) > radius:
		return
	investigate_at(at)


## Server: go and look at `at` (an alarm or a noise). An alerted Jaffa is already fighting and
## ignores it.
func investigate_at(at: Vector3) -> void:
	if perception == null or perception.level == JaffaPerception.Level.ALERTED:
		return
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		return
	perception.stimulus = at
	_start_investigation()
	_publish_awareness()


## Server: run to `spot` and stand there facing `look`, ignoring combat, until end_run().
## Perception keeps running, so the Jaffa still notices and reports what it sees.
func run_to(spot: Vector3, look: Vector3) -> void:
	_clear_modular_flank()
	_clear_suppression()
	errand = spot
	_errand_look = look
	_set_crouching(false)
	if current_state not in [State.DEAD, State.STUNNED, State.DOWNED]:
		current_state = State.CHASE


func end_run() -> void:
	if errand == Vector3.INF:
		return
	errand = Vector3.INF
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		return
	if current_target != null:
		break_formation_and_engage()
	else:
		current_state = _resume_state()


func _process_errand(delta: float) -> void:
	_reset_staff_position()
	var offset := errand - global_position
	offset.y = 0.0
	if offset.length() > 0.6:
		_advance_towards(errand, delta, combat_run_speed)
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if heading.length_squared() > 0.01:
			rotation.y = atan2(-heading.x, -heading.z)
		return
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	var look := _errand_look - global_position
	look.y = 0.0
	if look.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), clampf(8.0 * delta, 0.0, 1.0))


func _start_investigation() -> void:
	_clear_modular_flank()
	perception.investigate()
	investigating = true
	current_target = null
	cover_prop = null
	_search_clock = 0.0
	_search_wait = -1.0
	_search_route.clear()
	_search_leg = 0.0
	_set_crouching(false)
	if current_state not in [State.DEAD, State.STUNNED, State.DOWNED]:
		current_state = State.CHASE


func _publish_awareness() -> void:
	awareness_level = perception.level
	awareness = snappedf(perception.awareness, 0.05)


## A sentry with no target: patrol, stop and stare while suspicious, or search a position:
## walk to it, look around, then visit a few reachable points around it, looking at each.
func _process_sentry_calm(delta: float) -> void:
	if investigating:
		current_state = State.CHASE
		_search_clock += delta
		if _search_wait < 0.0:
			var offset := perception.stimulus - global_position
			offset.y = 0.0
			var stalled: bool = navigator != null and navigator.status in ["unreachable", "blocked_door"]
			if offset.length() > 1.5 and _search_clock < investigate_travel_limit and not stalled:
				_advance_towards(perception.stimulus, delta, move_speed)
				return
			_search_wait = investigate_wait
			_search_route = _search_route_around(global_position)
		if _search_wait > 0.0:
			# Stops at zero: a negative value means "still walking to the position".
			_search_wait = maxf(0.0, _search_wait - delta)
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			rotation.y += delta * 1.1  # look around
			return
		if not _search_route.is_empty():
			var leg := _search_route[0] - global_position
			leg.y = 0.0
			var blocked: bool = navigator != null and navigator.status in ["unreachable", "blocked_door", "stuck"]
			_search_leg += delta
			if leg.length() > 1.0 and _search_leg < 8.0 and not blocked:
				_advance_towards(_search_route[0], delta, march_speed)
				return
			_search_route.pop_front()
			_search_leg = 0.0
			_search_wait = search_look_time
			return
		investigating = false
		perception.calm()
		_publish_awareness()
		current_state = _resume_state()
		return
	if perception.level == JaffaPerception.Level.ALERTED and perception.stimulus.is_finite():
		# Alerted by a fallen comrade without direct visual contact: move to the body while
		# MissionAlert dispatches an alarm runner; perception transitions to search if quiet.
		var offset := perception.stimulus - global_position
		offset.y = 0.0
		if offset.length() > 1.8:
			_advance_towards(perception.stimulus, delta, move_speed)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			rotation.y += delta * 1.4
		return
	if perception.level == JaffaPerception.Level.SUSPICIOUS:
		# Stop and look where something was seen; keep looking until it is forgotten or confirmed.
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		var look := perception.stimulus - global_position
		look.y = 0.0
		if look.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), clampf(4.0 * delta, 0.0, 1.0))
		return
	if current_state in [State.ADVANCE, State.CHASE]:
		current_state = _resume_state()
	_advance_towards(_overrun_destination(), delta, march_speed)


## Up to `search_points` reachable floor points about `search_radius` from `center` on the same
## deck, in spread-out directions and a short walk away. Empty off a modular level.
func _search_route_around(center: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	var level := LevelNavigator.find_level(self)
	if level == null or not level.ready_for_navigation or search_points <= 0:
		return route
	var start := randf() * TAU
	# Opposite directions first, then the quarters between them.
	for step: float in [0.0, 0.5, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875]:
		if route.size() >= search_points:
			break
		var angle := start + TAU * step
		var wanted := center + Vector3(sin(angle), 0.0, cos(angle)) * search_radius
		var spot := NavigationServer3D.map_get_closest_point(level.navigation_map, wanted)
		if absf(spot.y - center.y) > 1.0 or Vector2(spot.x - center.x, spot.z - center.z).length() < 2.5:
			continue
		var crowded := false
		for other in route:
			crowded = crowded or other.distance_to(spot) < 2.5
		if crowded:
			continue
		var path := level.local_path(center, spot)
		if path.is_empty() or path[-1].distance_to(spot) > 1.0:
			continue
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		if length <= search_radius * 2.0:
			route.append(spot)
	return route


func _build_tell() -> void:
	_tell = Label3D.new()
	_tell.name = "AwarenessTell"
	_tell.position = Vector3(0, 2.45, 0)
	_tell.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tell.font_size = 96
	_tell.outline_size = 16
	_tell.visible = false
	add_child(_tell)


## Overhead tell on every peer, from the replicated awareness: "?" fills as suspicion builds,
## a red "!" once alerted.
func _process(_delta: float) -> void:
	if _role_badge != null:
		_role_badge.visible = not role_label().is_empty() and current_state != State.DEAD
	if _tell == null:
		return
	_tell.visible = (
		(raising_alarm or is_suppressed or awareness_level != JaffaPerception.Level.UNAWARE)
		and current_state != State.DEAD
	)
	if not _tell.visible:
		return
	if raising_alarm:
		_tell.text = "!!"
		_tell.modulate = Color(1.0, 0.2, 0.75)
	elif is_suppressed:
		_tell.text = "↓"
		_tell.modulate = Color(1.0, 0.67, 0.28)
	elif awareness_level == JaffaPerception.Level.ALERTED:
		_tell.text = "!"
		_tell.modulate = Color(1.0, 0.25, 0.15)
	else:
		_tell.text = "?"
		_tell.modulate = Color(1.0, 0.85, 0.2, 0.35 + 0.65 * clampf(awareness, 0.0, 1.0))


func _patrol_destination() -> Vector3:
	if not patrol_loop and patrol_laps > 0:
		return patrol_points[-1]
	if global_position.distance_to(patrol_points[patrol_index]) < 1.0:
		patrol_waypoint_reached.emit(patrol_index)
		if patrol_index == patrol_points.size() - 1:
			patrol_laps += 1
			patrol_lap_completed.emit(patrol_laps)
			if patrol_loop:
				patrol_index = 0
		else:
			patrol_index += 1
	return patrol_points[patrol_index]


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_flank_cooldown = maxf(0.0, _flank_cooldown - delta)
	_rally_resolve_timer = maxf(0.0, _rally_resolve_timer - delta)
	_rally_cooldown = maxf(0.0, _rally_cooldown - delta)
	_shock_grenade_cooldown = maxf(0.0, _shock_grenade_cooldown - delta)
	_kara_kesh_push_cd = maxf(0.0, _kara_kesh_push_cd - delta)
	_kara_kesh_beam_cd = maxf(0.0, _kara_kesh_beam_cd - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state == State.DEAD or current_state == State.STUNNED or current_state == State.DOWNED:
		_clear_modular_flank()
		_clear_suppression()
		_burst_shots_remaining = 0
		_cancel_kara_kesh("incapacitated")
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	if profile == Profile.SENTRY:
		_update_perception(delta)
		if errand != Vector3.INF:
			_process_errand(delta)
			move_and_slide()
			return
		if _process_suppression(delta):
			move_and_slide()
			return

	_process_burst_fire(delta)
	if combat_role in [ROLE_OFFICER, ROLE_GOAULD_LORD] and current_target != null and _rally_cooldown <= 0.0:
		_try_officer_rally()
	if is_boss() and _process_kara_kesh(delta):
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


func can_be_suppressed() -> bool:
	return (
		profile == Profile.SENTRY and is_physics_processing() and errand == Vector3.INF
		and not has_active_shield()
		and _rally_resolve_timer <= 0.0
		and current_state not in [State.DEAD, State.STUNNED, State.DOWNED]
		and not health_component.is_dead and not health_component.is_stunned and not health_component.is_downed
	)


## Nearby ballistic pressure makes a sentry duck (2 rounds for troopers, 5 rounds for Heavy).
## Perception continues to own the target and receives no new sighting from this reaction.
func register_incoming_fire(origin: Vector3) -> void:
	if not multiplayer.is_server() or not can_be_suppressed() or _suppression_recovery > 0.0:
		return
	var hold_s: float = HEAVY_SUPPRESSION_HOLD if is_heavy() else SUPPRESSION_HOLD
	var limit_s: float = HEAVY_SUPPRESSION_LIMIT if is_heavy() else SUPPRESSION_LIMIT
	var hits_needed: int = HEAVY_SUPPRESSION_HITS if is_heavy() else 2
	if is_suppressed:
		_suppression_hold = hold_s
		return
	if _incoming_fire_window <= 0.0:
		_incoming_fire_hits = 1
		_incoming_fire_window = INCOMING_FIRE_WINDOW
		return
	_incoming_fire_hits += 1
	_incoming_fire_window = INCOMING_FIRE_WINDOW
	if _incoming_fire_hits < hits_needed:
		return
	var level := LevelNavigator.find_level(self)
	if level == null:
		return
	if _flank_navigation != null:
		_end_modular_flank("suppressed")
	is_suppressed = true
	_incoming_fire_window = 0.0
	_incoming_fire_hits = 0
	_suppression_hold = hold_s
	_suppression_limit = limit_s
	var threat_floor := origin - Vector3.UP * LevelNavigator.THREAT_TORSO
	var found := LevelNavigator.prop_cover(level, self, threat_floor, 7.0)
	_suppression_cover = found.get("spot", Vector3.INF)
	_peek = 0.0
	_set_crouching(true)


func _process_suppression(delta: float) -> bool:
	_incoming_fire_window = maxf(0.0, _incoming_fire_window - delta)
	if _incoming_fire_window <= 0.0:
		_incoming_fire_hits = 0
	_suppression_recovery = maxf(0.0, _suppression_recovery - delta)
	if not is_suppressed:
		return false
	_suppression_hold -= delta
	_suppression_limit -= delta
	if _suppression_hold <= 0.0 or _suppression_limit <= 0.0:
		_clear_suppression()
		_suppression_recovery = SUPPRESSION_RECOVERY
		_set_crouching(false)
		return false
	_set_crouching(true)
	if _suppression_cover.is_finite() and global_position.distance_to(_suppression_cover) > 0.85:
		_advance_towards(_suppression_cover, delta, march_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 17.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 17.0 * delta)
	return true


func _clear_suppression() -> void:
	is_suppressed = false
	_incoming_fire_window = 0.0
	_incoming_fire_hits = 0
	_suppression_hold = 0.0
	_suppression_limit = 0.0
	_suppression_recovery = 0.0
	_suppression_cover = Vector3.INF


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
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if current_state == State.DEAD or current_state == State.STUNNED or current_state == State.DOWNED:
		return

	if _try_modular_flank():
		return
	if profile == Profile.SENTRY and _take_prop_cover(10.0):
		# Modular levels: a sentry with low cover close by fights from behind it.
		current_state = State.COVER
		_set_crouching(false)
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
	var spread_radius: float = OFFICER_ALERT_RADIUS if combat_role in [ROLE_OFFICER, ROLE_GOAULD_LORD] else combat_range
	for child: Node in enemies.get_children():
		var other: JaffaAI = child as JaffaAI
		if other != null and other != self and is_instance_valid(other):
			if other.profile == Profile.SENTRY:
				# One hop, as before: the alerted sentry engages but does not pass it on.
				if (
					other.global_position.distance_to(global_position) <= spread_radius
					and other.perception.level != JaffaPerception.Level.ALERTED
					and other.current_state not in [State.DEAD, State.STUNNED, State.DOWNED]
				):
					var known := is_instance_valid(current_target)
					other.perception.alert(
						current_target if known else null,
						current_target.global_position if known else global_position
					)
					other._publish_awareness()
					other._engage(other.perception.target, false)
				continue
			if other.current_state == State.PATROL and other.global_position.distance_to(global_position) > spread_radius:
				continue
			if other.current_state in [State.MARCHING_FORMATION, State.ADVANCE, State.PATROL]:
				if other.current_target == null and current_target != null:
					other.current_target = current_target
				other.break_formation_and_engage()


## One nearby trailing sentry can leave an engaged lead's firing position. This only
## consumes perception's last sighting; it never asks an unseen target where it moved.
func _try_modular_flank() -> bool:
	if not multiplayer.is_server() or profile != Profile.SENTRY or formation_rank < 1 or is_front_rank or _flank_cooldown > 0.0:
		return false
	if not is_instance_valid(current_target) or perception == null or not perception.can_see(current_target):
		return false
	if global_position.distance_to(perception.stimulus) <= melee_range + 1.0:
		return false
	var level := LevelNavigator.find_level(self)
	if level == null or errand != Vector3.INF:
		return false
	var health := current_target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and (health.is_dead or health.is_downed):
		return false
	var supported := false
	for child in get_parent().get_children():
		var other := child as JaffaAI
		if other == null or other == self or not other.is_physics_processing() or other.global_position.distance_to(global_position) > combat_range:
			continue
		if other._flank_navigation != null:
			return false
		if other.formation_rank < formation_rank and other.current_state in [State.COMBAT, State.COVER, State.ATTACK]:
			supported = supported or (other.profile == Profile.SENTRY and other.current_target == current_target)
	if not supported:
		return false
	var route := LevelNavigator.new(self, level)
	if route.plan_flank(perception.stimulus).is_empty():
		return false
	_flank_navigation = route
	_flank_known = perception.stimulus
	_flank_subject = weakref(current_target)
	_flank_time = 0.0
	_flank_cooldown = FLANK_COOLDOWN
	flank_status = "moving"
	is_tactical_flanking = true
	cover_prop = null
	flank_route_target = route.destination
	tactical_destination = flank_route_target
	current_state = State.COVER
	_set_crouching(false)
	return true


func _clear_modular_flank() -> void:
	if _flank_navigation != null:
		_flank_cooldown = FLANK_COOLDOWN
		if flank_status == "moving":
			flank_status = "cancelled"
		_flank_navigation.reset()
	_flank_navigation = null
	_flank_subject = null
	is_tactical_flanking = false


func _end_modular_flank(reason: String) -> void:
	flank_status = reason
	_clear_modular_flank()
	_flank_cooldown = FLANK_COOLDOWN
	velocity.x = 0.0
	velocity.z = 0.0
	if perception.target == null or not is_instance_valid(perception.target):
		_start_investigation()
		return
	current_target = perception.target
	if _take_prop_cover(20.0):
		current_state = State.COVER
	else:
		current_state = State.COMBAT
	_set_crouching(false)


func _process_modular_flank(delta: float) -> void:
	if not multiplayer.is_server() or _flank_navigation == null:
		return
	_flank_time += delta
	var subject := _flank_subject.get_ref() as Node3D if _flank_subject != null else null
	var health := subject.get_node_or_null("HealthComponent") as HealthComponent if is_instance_valid(subject) else null
	if not is_instance_valid(subject) or not subject.is_inside_tree() or (health != null and (health.is_dead or health.is_downed)):
		_end_modular_flank("target_gone")
		return
	if _flank_time >= FLANK_LIMIT:
		_end_modular_flank("timeout")
		return
	if perception.target != null and global_position.distance_to(perception.stimulus) <= melee_range:
		_end_modular_flank("close_threat")
		return
	if perception.target != null and perception.stimulus.distance_to(_flank_known) > 4.0:
		_end_modular_flank("target_changed")
		return
	var point := _flank_navigation.next_position(flank_route_target, delta)
	if _flank_navigation.status in ["blocked_door", "unreachable", "stuck"]:
		_end_modular_flank(_flank_navigation.status)
		return
	if _flank_navigation.status == "arrived":
		_end_modular_flank("arrived")
		return
	var heading := point - global_position
	heading.y = 0.0
	var direction := heading.normalized()
	velocity.x = move_toward(velocity.x, direction.x * combat_run_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * combat_run_speed, 20.0 * delta)
	if direction.length_squared() > 0.01:
		rotation.y = atan2(-direction.x, -direction.z)


func _assign_tactical_role() -> void:
	var level := LevelNavigator.find_level(self)
	if level != null:
		# Modular levels: behind a cover prop if one qualifies, else a room cover marker, else
		# hold the current position.
		is_tactical_flanking = false
		if _take_prop_cover(20.0):
			return
		var threat := current_target.global_position if current_target != null else global_position
		var cover := LevelNavigator.cover_position(level, self, threat)
		tactical_cover_position = cover if cover != Vector3.INF else global_position
		tactical_destination = tactical_cover_position
		return

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


## Modular levels: pick the nearest qualifying cover prop within `max_walk` metres, not one a
## nearby Jaffa already holds. Sets the destination and `cover_prop`; false when none qualifies.
func _take_prop_cover(max_walk: float) -> bool:
	cover_prop = null
	var level := LevelNavigator.find_level(self)
	if level == null or current_target == null or not is_instance_valid(current_target):
		return false
	var taken: Array[Vector3] = []
	var siblings: Node = get_parent()
	if siblings != null:
		for child in siblings.get_children():
			var other := child as JaffaAI
			if other != null and other != self and other.cover_prop != null:
				taken.append(other.tactical_destination)
	var found := LevelNavigator.prop_cover(level, self, current_target.global_position, max_walk, taken)
	if found.is_empty():
		return false
	cover_prop = found["prop"]
	tactical_cover_position = found["spot"]
	tactical_destination = tactical_cover_position
	_peek = 0.0
	_cover_check = 0.5
	return true


## Behind a cover prop: crouch facing the threat, stand to fire when ready, crouch again. Look
## for other cover once the threat has an angle round this prop.
func _hold_prop_cover(delta: float) -> void:
	var look := current_target.global_position - global_position
	look.y = 0.0
	if look.length_squared() > 0.01:
		rotation.y = atan2(-look.x, -look.z)
	_cover_check -= delta
	if _cover_check <= 0.0:
		_cover_check = 0.5
		if not LevelNavigator.prop_blocks(cover_prop, global_position, current_target.global_position):
			if not _take_prop_cover(20.0):
				_set_crouching(false)
				current_state = State.COMBAT
			return
	fire_timer -= delta
	if _peek > 0.0:
		_peek -= delta
		if _peek <= 0.0:
			_set_crouching(true)
		return
	if fire_timer <= 0.0:
		_set_crouching(false)
		# Fire over the top: the muzzle sits clear above the prop, not inside it.
		if staff_mount != null:
			staff_mount.position.y = OVER_COVER_STAFF_HEIGHT
		_peek = 0.7
		fire_timer = fire_interval_s + randf_range(-0.3, 0.3)
		_fire_staff_blast()
	else:
		_set_crouching(true)


func _find_nearest_cover(is_west: bool) -> Vector3:
	var default_pos: Vector3 = Vector3(-5.0, 0.1, 4.0) if is_west else Vector3(2.5, 0.1, 4.0)
	if not is_inside_tree():
		return default_pos

	var cover_nodes: Array[Node] = MissionWorld.in_group(self, &"cover")
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
	if _flank_navigation != null:
		_process_modular_flank(delta)
		return
	_find_nearest_target()

	if current_target == null and not patrol_points.is_empty():
		# Patrols do not hold cover forever: wait out the suppression timer, then resume.
		current_state = State.COMBAT
		suppressive_hold_timer = 4.0
		return

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

		if cover_prop != null and is_instance_valid(cover_prop) and current_target != null:
			_hold_prop_cover(delta)
			return

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
		current_state = _resume_state()
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

			if is_boss() and kara_kesh_state == KaraKeshState.IDLE:
				if dist <= KARA_KESH_PUSH_RANGE and _kara_kesh_push_cd <= 0.0:
					_set_crouching(false)
					trigger_kara_kesh_push()
					return
				if dist >= KARA_KESH_BEAM_MIN_RANGE and dist <= KARA_KESH_BEAM_MAX_RANGE and _kara_kesh_beam_cd <= 0.0:
					_set_crouching(false)
					trigger_kara_kesh_beam(current_target)
					return

			if is_grenadier() and shock_grenades_remaining > 0 and _shock_grenade_cooldown <= 0.0:
				if dist >= SHOCK_GRENADE_MIN_RANGE and dist <= SHOCK_GRENADE_MAX_RANGE:
					if try_throw_shock_grenade(current_target.global_position) != null:
						return

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

	if profile == Profile.SENTRY and current_target == null:
		_process_sentry_calm(delta)
		return

	if current_target == null:
		# Proceed to march steadily into the base preserving tactical lane cohesion
		if current_state == State.ADVANCE:
			current_state = _resume_state()
		var advance_target := _overrun_destination()
		_advance_towards(advance_target, delta, march_speed)
		return

	var dist: float = global_position.distance_to(current_target.global_position)
	if dist <= melee_range:
		current_state = State.MELEE
		_process_melee(delta)
	elif dist <= combat_range and _has_line_of_sight(current_target):
		if current_state == State.PATROL:
			# A patrol reacts like an interrupted column: lead suppresses, the rest take cover.
			break_formation_and_engage()
			_alert_nearby_formation_jaffa()
			return
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
	if muzzle_point != null and WeaponBase.attach_staff_visual(
		visual_root, muzzle_point.position, WeaponBase.JAFFA_STAFF_VISUAL_SCALE
	):
		return

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
	if profile == Profile.SENTRY:
		# A sentry knows only what perception gave it; drop a target that is gone or dead.
		if current_target != null:
			var gone := not is_instance_valid(current_target) or not current_target.is_inside_tree()
			var health: HealthComponent = (
				null if gone else current_target.get_node_or_null("HealthComponent") as HealthComponent
			)
			if gone or (health != null and health.is_dead):
				current_target = null
		return
	# Find closest active SGC operative or allied Airman defender in perception range.
	# A downed one is only a target when no standing one is known.
	var candidates: Array[Node3D] = []
	var downed: Array[Node3D] = []

	var players_container := MissionWorld.find(self, "Players")
	if players_container != null:
		for child in players_container.get_children():
			var p := child as CharacterBody3D
			if p != null:
				var health := p.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and not health.is_dead:
					(downed if health.is_downed else candidates).append(p)

	var allies_container := MissionWorld.find(self, "Allies")
	if allies_container != null:
		for child in allies_container.get_children():
			var a := child as CharacterBody3D
			if a != null:
				var health := a.get_node_or_null("HealthComponent") as HealthComponent
				if health != null and not health.is_dead:
					(downed if health.is_downed else candidates).append(a)

	current_target = _nearest_of(candidates)
	if current_target == null:
		current_target = _nearest_of(downed)


func _nearest_of(candidates: Array[Node3D]) -> Node3D:
	var closest_los_target: Node3D = null
	var closest_los_dist: float = combat_range * 1.5  # ~33m visual awareness
	var closest_any_target: Node3D = null
	var min_any_dist: float = combat_range
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
		return closest_los_target
	if closest_any_target != null and min_any_dist <= combat_range:
		return closest_any_target
	return null


func _is_target_obscured_by_smoke(target_pos: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var seg_start := global_position + Vector3(0, 1.4, 0)
	var seg_end := target_pos + Vector3(0, 1.0, 0)
	var seg_dir := (seg_end - seg_start)
	var seg_len_sq := seg_dir.length_squared()
	if seg_len_sq < 0.001:
		return false

	for node in MissionWorld.in_group(self, &"smoke_cloud"):
		var cloud := node as Area3D
		if cloud != null and is_instance_valid(cloud):
			var cloud_pos := cloud.global_position
			var t := clampf((cloud_pos - seg_start).dot(seg_dir) / seg_len_sq, 0.0, 1.0)
			var closest_pt := seg_start + seg_dir * t
			if closest_pt.distance_to(cloud_pos) <= 4.5:
				return true
	return false


## Height a Jaffa looks from, standing or crouched: a crouched Jaffa can still peek over low cover.
const EYE_HEIGHT := 1.55


## Clear line from the staff's muzzle (for firing) or from the eyes (`from_eye`, for perception).
func _has_line_of_sight(target: Node3D, from_eye: bool = false) -> bool:
	if target == null or not is_inside_tree() or not target.is_inside_tree():
		return false
	if _is_target_obscured_by_smoke(target.global_position):
		return false

	var space := get_world_3d().direct_space_state
	if space == null:
		return false

	var from: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.4, 0)
	if from_eye:
		from = global_position + Vector3(0, EYE_HEIGHT, 0)
	var exclude_list: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude_list.append((target as CollisionObject3D).get_rid())

	# Test both head and torso for clear unoccluded LOS (duck lower when operative is crouched in cover without peeking)
	var crouched_in_cover: bool = (
		target.get(&"is_crouching") == true
		and target.get(&"is_in_cover") == true
		and target.get(&"is_peeking") != true
	)
	var test_points: Array[Vector3] = []
	if crouched_in_cover:
		test_points = [
			target.global_position + Vector3(0, 0.65, 0),
			target.global_position + Vector3(0, 0.42, 0),
		]
	else:
		test_points = [
			target.global_position + Vector3(0, 1.5, 0),  # Head
			target.global_position + Vector3(0, 1.0, 0)   # Torso
		]
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and (health.is_downed or health.is_dead or health.is_stunned):
		if health.is_dead:
			test_points = [target.global_position + Vector3(0, 0.45, 0)]
		else:
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
	# Face active target in combat so frontal armor/Kara Kesh arcs stay aligned.
	var look_dir: Vector3 = current_target.global_position - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-look_dir.x, -look_dir.z), clampf(10.0 * delta, 0.0, 1.0))

	# Goa'uld System Lord Boss: prioritize Kara Kesh telekinetic push / focused energy beam
	if is_boss() and kara_kesh_state == KaraKeshState.IDLE and _has_line_of_sight(current_target):
		if dist <= KARA_KESH_PUSH_RANGE and _kara_kesh_push_cd <= 0.0:
			trigger_kara_kesh_push()
			return
		if dist >= KARA_KESH_BEAM_MIN_RANGE and dist <= KARA_KESH_BEAM_MAX_RANGE and _kara_kesh_beam_cd <= 0.0:
			trigger_kara_kesh_beam(current_target)
			return

	# Shock Grenadier: flush operatives holding cover or mid-range chokepoints
	if is_grenadier() and shock_grenades_remaining > 0 and _shock_grenade_cooldown <= 0.0:
		if dist >= SHOCK_GRENADE_MIN_RANGE and dist <= SHOCK_GRENADE_MAX_RANGE:
			if try_throw_shock_grenade(current_target.global_position) != null:
				return

	# Continue advancing down the ramp while in long-range combat (> 10m)
	var hold_dist: float = 8.0 if is_boss() else 10.0
	if dist > hold_dist:
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
	if is_suppressed or current_target == null or not _has_line_of_sight(current_target):
		return

	_dispatch_single_plasma_bolt()

	if is_heavy():
		# Heavy Staff Cannon Trooper: sustained 3-bolt rapid suppressive volley (0.14s spacing)
		_burst_shots_remaining = 2
		_burst_shot_timer = 0.14
	elif is_shock_guard and not is_boss():
		# Jaffa Shock Guard rapid double-burst logic (fires 2nd bolt after 0.18s)
		_burst_shots_remaining = 1
		_burst_shot_timer = 0.18


func _process_burst_fire(delta: float) -> void:
	if _burst_shots_remaining <= 0:
		return
	_burst_shot_timer -= delta
	if _burst_shot_timer > 0.0:
		return
	_burst_shots_remaining -= 1
	_burst_shot_timer = 0.14 if is_heavy() else 0.18
	if (
		not is_suppressed
		and current_state not in [State.DEAD, State.STUNNED, State.DOWNED]
		and current_target != null
		and is_instance_valid(current_target)
		and _has_line_of_sight(current_target)
	):
		_dispatch_single_plasma_bolt()
	else:
		_burst_shots_remaining = 0


func _dispatch_single_plasma_bolt() -> void:
	if is_suppressed or current_target == null or not _has_line_of_sight(current_target):
		return

	var origin: Vector3 = (
		kara_kesh_mount.global_position
		if (is_boss() and kara_kesh_mount != null)
		else (muzzle_point.global_position if muzzle_point != null else global_position + Vector3(0, 1.2, -0.6))
	)
	var aim_height: float = 0.60 if (
		current_target.get(&"is_crouching") == true
		and current_target.get(&"is_in_cover") == true
		and current_target.get(&"is_peeking") != true
	) else 1.0
	var target_chest := current_target.global_position + Vector3(0, aim_height, 0)
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
		if is_heavy():
			bolt.speed = HEAVY_BOLT_SPEED
		var root_node := get_tree().root if is_inside_tree() else null
		if root_node != null:
			root_node.add_child(bolt)
			bolt.initialize(origin, dir, self, true)
		elif get_parent() != null:
			get_parent().add_child(bolt)
			bolt.initialize(origin, dir, self, true)

	staff_fired.emit(origin, dir)

	# Visual muzzle burst RPC
	play_staff_fire_fx(origin)
	SGCNetworkManager.mission_rpc(self, &"play_staff_fire_fx", [origin], health_component)


const TAKEDOWN_RANGE := 2.2
const TAKEDOWN_MAX_DY := 1.2
## Cosine threshold: forward.dot(to_operative) <= TAKEDOWN_REAR_DOT means the operative is behind
## the Jaffa (outside its front cone, in the rear hemisphere).
const TAKEDOWN_REAR_DOT := -0.15


## True when `operative` can silently take down this standing, unalerted Jaffa from behind.
## Goa'uld System Lord bosses resist instant rear takedowns (allowing flank melee bypass instead).
func can_be_taken_down_by(operative: Node3D) -> bool:
	if is_boss():
		return false
	if operative == null or not is_instance_valid(operative) or not is_inside_tree():
		return false
	if health_component == null or health_component.is_dead or health_component.is_stunned or health_component.is_downed:
		return false
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED, State.COMBAT, State.ATTACK, State.MELEE, State.COVER]:
		return false
	var op_health := operative.get_node_or_null("HealthComponent") as HealthComponent
	if op_health != null and (op_health.is_dead or op_health.is_downed or op_health.is_stunned):
		return false
	var flat_dist := Vector2(
		operative.global_position.x - global_position.x,
		operative.global_position.z - global_position.z
	).length()
	if flat_dist > TAKEDOWN_RANGE or absf(operative.global_position.y - global_position.y) > TAKEDOWN_MAX_DY:
		return false
	if not _has_line_of_sight(operative, true):
		return false
	if profile == Profile.SENTRY and perception != null and perception.level == JaffaPerception.Level.ALERTED:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return false
	forward = forward.normalized()
	var to_op := operative.global_position - global_position
	to_op.y = 0.0
	if to_op.length_squared() > 0.0001 and forward.dot(to_op.normalized()) > TAKEDOWN_REAR_DOT:
		return false
	return true


## Server: silently eliminates this Jaffa via a close-quarters takedown without alerting nearby sentries.
func perform_stealth_takedown(operative: Node3D) -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	if not can_be_taken_down_by(operative):
		return false
	current_target = null
	investigating = false
	errand = Vector3.INF
	raising_alarm = false
	if perception != null:
		perception.calm()
		_publish_awareness()
	health_component.take_damage(health_component.current_health + 50.0, operative, "stealth_takedown")
	print("Jaffa Guard [%s] silently neutralized via stealth takedown!" % name)
	return true


func _on_damage_taken(_amount: float, source: Node, damage_type: String) -> void:
	if is_shock_guard and current_state != State.DEAD:
		var spark_at := global_position + Vector3(0, 1.2, 0)
		play_armor_spark_fx(spark_at)
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			SGCNetworkManager.mission_rpc(self, &"play_armor_spark_fx", [spark_at], health_component)

	var is_silent_incapacitation := (
		damage_type in ["zat_stun", "zat_kill", "zat_vaporize", "stealth_takedown", "thrown_knife_stealth"]
		or (damage_type == "melee_slow_flank" and health_component != null and (health_component.is_dead or health_component.current_health <= 0.0))
	)

	if profile == Profile.SENTRY and perception != null and multiplayer.is_server():
		if is_silent_incapacitation and perception.level != JaffaPerception.Level.ALERTED:
			# Silent Zat incapacitation or stealth takedown / lethal flank drops an unalerted sentry before it can
			# shout or alert nearby sentries.
			investigating = false
			current_target = null
			perception.calm()
			_publish_awareness()
			return
		_react_to_hostile_contact(source)
		return

	if is_silent_incapacitation:
		return

	_react_to_hostile_contact(source)


func _react_to_hostile_contact(source: Node) -> void:
	if profile == Profile.SENTRY and perception != null and multiplayer.is_server():
		var hit_by_operative := (
			source is Node3D and is_instance_valid(source) and source.has_node("HealthComponent")
		)
		var attacker: Node3D = source as Node3D if hit_by_operative else null
		var at := (
			(source as Node3D).global_position
			if source is Node3D and is_instance_valid(source)
			else global_position
		)
		var was_alerted := perception.level == JaffaPerception.Level.ALERTED
		perception.alert(attacker, at)
		_publish_awareness()
		if not was_alerted:
			_engage(attacker, true)
		elif attacker != null:
			current_target = attacker
		return

	if source is Node3D and is_instance_valid(source):
		current_target = source as Node3D

	if current_state in [State.MARCHING_FORMATION, State.ADVANCE, State.PATROL]:
		break_formation_and_engage()
		_alert_nearby_formation_jaffa()


func _on_shield_deflected(source: Node, _damage_type: String, _impact_pos: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_react_to_hostile_contact(source)


func _on_shield_overloaded(source: Node, _damage_type: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if kara_kesh_state != KaraKeshState.IDLE:
		_cancel_kara_kesh("shield_overloaded")
	_react_to_hostile_contact(source)


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
	staff_visual_fired.emit()
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
	_clear_modular_flank()
	_clear_suppression()
	_burst_shots_remaining = 0
	_cancel_kara_kesh("stunned")
	current_state = State.STUNNED
	current_target = null
	investigating = false
	errand = Vector3.INF
	raising_alarm = false
	velocity = Vector3.ZERO
	if perception != null and perception.level != JaffaPerception.Level.ALERTED:
		perception.calm()
		_publish_awareness()
	_set_crouching(false)
	if stun_fx != null:
		stun_fx.visible = true
	print("Jaffa Guard incapacitated by Zat'nik'tel stun for %.1f s." % duration)


func _on_recovered_from_stun() -> void:
	body_discovered_flag = false
	if current_state == State.STUNNED:
		current_state = _resume_state()
		if stun_fx != null:
			stun_fx.visible = false
		print("Jaffa Guard recovered from Zat stun.")


func _on_died() -> void:
	_clear_modular_flank()
	_clear_suppression()
	_burst_shots_remaining = 0
	_cancel_kara_kesh("died")
	if _role_badge != null:
		_role_badge.visible = false
	if navigator != null: navigator.reset()
	if _death_notified:
		return
	_death_notified = true
	body_discovered_flag = false
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
	if not patrol_points.is_empty(): return _patrol_destination()
	var map := MissionWorld.first_in_group(self, &"sgc_map") as SGCMap
	if map == null: return Vector3(column_x_lane, 0.0, 24.0)
	var destinations: Array[StringName] = [&"EAST_CORRIDOR", &"ROUND_HALLWAY", &"BRIEFING_ROOM", &"STAGING"]
	if column_x_lane < 0: destinations[0] = &"WEST_CORRIDOR"
	var goal := map.definition.region(destinations[overrun_destination_index]).anchor
	if global_position.distance_to(goal) < 1.2 and overrun_destination_index < destinations.size()-1:
		overrun_destination_index += 1
		goal = map.definition.region(destinations[overrun_destination_index]).anchor
	return goal


# ==============================================================================
# SW-3: CANONICAL SPECIALIST ABILITIES & GOA'ULD SYSTEM LORD KARA KESH
# ==============================================================================

## Server: Officer / System Lord command pulse. Clears suppression on nearby allied Jaffa,
## grants brief rally resolve, and shares target intel across the tactical command radius.
func issue_rally_command() -> int:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return 0
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		return 0
	var enemies := get_parent()
	if enemies == null:
		return 0
	var radius: float = BOSS_RALLY_RADIUS if is_boss() else OFFICER_RALLY_RADIUS
	var rallied: int = 0
	var known := is_instance_valid(current_target)
	for child: Node in enemies.get_children():
		var ally := child as JaffaAI
		if ally == null or ally == self or not is_instance_valid(ally):
			continue
		if ally.current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
			continue
		if ally.global_position.distance_to(global_position) > radius:
			continue
		var touched := false
		if ally.is_suppressed:
			ally._clear_suppression()
			ally._set_crouching(false)
			touched = true
		if ally._rally_resolve_timer < RALLY_RESOLVE_DURATION_S * 0.5:
			ally._rally_resolve_timer = RALLY_RESOLVE_DURATION_S
			touched = true
		if ally.profile == Profile.SENTRY and ally.perception != null and ally.perception.level != JaffaPerception.Level.ALERTED and known:
			ally.perception.alert(current_target, current_target.global_position)
			ally._publish_awareness()
			ally._engage(current_target, false)
			touched = true
		if touched:
			rallied += 1
	if rallied > 0:
		_rally_cooldown = OFFICER_RALLY_COOLDOWN_S
		rally_command_issued.emit(rallied)
		play_rally_fx(global_position + Vector3(0.0, 1.35, 0.0))
		SGCNetworkManager.mission_rpc(self, &"play_rally_fx", [global_position + Vector3(0.0, 1.35, 0.0)], health_component)
	return rallied


func _try_officer_rally() -> void:
	var enemies := get_parent()
	if enemies == null:
		return
	var radius: float = BOSS_RALLY_RADIUS if is_boss() else OFFICER_RALLY_RADIUS
	var needs_rally := false
	for child: Node in enemies.get_children():
		var ally := child as JaffaAI
		if ally == null or ally == self or not is_instance_valid(ally):
			continue
		if ally.current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
			continue
		if ally.global_position.distance_to(global_position) > radius:
			continue
		if ally.is_suppressed or (ally.profile == Profile.SENTRY and ally.perception != null and ally.perception.level != JaffaPerception.Level.ALERTED):
			needs_rally = true
			break
	if needs_rally:
		issue_rally_command()


@rpc("call_local", "unreliable")
func play_rally_fx(pos: Vector3) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var pulse := OmniLight3D.new()
	pulse.light_color = Color(1.0, 0.82, 0.28)
	pulse.light_energy = 4.2
	pulse.omni_range = 6.0
	add_child(pulse)
	pulse.global_position = pos
	var tw := pulse.create_tween()
	tw.tween_property(pulse, "light_energy", 0.0, 0.25)
	tw.tween_callback(pulse.queue_free)


## Server: Shock Grenadier throws a canonical Goa'uld Shock Grenade toward `target_pos`.
func try_throw_shock_grenade(target_pos: Vector3) -> Node3D:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return null
	if not is_grenadier() or shock_grenades_remaining <= 0 or _shock_grenade_cooldown > 0.0:
		return null
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		return null
	var deployments := MissionWorld.find(self, "FieldKitDeployments") as Node3D
	if deployments == null:
		return null
	var scene := load(SHOCK_GRENADE_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var origin := global_position + Vector3(0.0, 1.45, 0.0) + (-global_transform.basis.z * 0.45)
	var delta_vec := target_pos - origin
	var horiz := Vector3(delta_vec.x, 0.0, delta_vec.z)
	var horiz_dist := horiz.length()
	if horiz_dist < 1.0 or horiz_dist > SHOCK_GRENADE_MAX_RANGE + 2.0:
		return null
	var flight_t := clampf(horiz_dist / 12.5, 0.45, 1.05)
	var vel := Vector3(
		delta_vec.x / flight_t,
		(delta_vec.y + 0.5 * 14.5 * flight_t * flight_t) / flight_t,
		delta_vec.z / flight_t
	)
	var grenade := scene.instantiate() as Node3D
	grenade.name = "ShockGrenade_%d_%d" % [get_instance_id(), shock_grenades_remaining]
	grenade.position = MissionWorld.local(deployments, origin)
	deployments.add_child(grenade, true)
	if grenade.has_method(&"launch"):
		grenade.call(&"launch", vel, self)
	shock_grenades_remaining -= 1
	_shock_grenade_cooldown = SHOCK_GRENADE_COOLDOWN_S
	shock_grenade_thrown.emit(grenade, target_pos)
	return grenade


## Server: initiates the Goa'uld System Lord's Kara Kesh telekinetic shockwave push telegraph.
func trigger_kara_kesh_push() -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	if not is_boss() or kara_kesh_state != KaraKeshState.IDLE:
		return false
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		return false
	kara_kesh_state = KaraKeshState.CHARGING_PUSH
	_kara_kesh_phase_timer = KARA_KESH_PUSH_CHARGE_S
	_kara_kesh_push_cd = KARA_KESH_PUSH_COOLDOWN_S
	_set_crouching(false)
	return true


## Server: initiates the Goa'uld System Lord's Kara Kesh focused neural/energy beam telegraph.
func trigger_kara_kesh_beam(target: Node3D) -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	if not is_boss() or kara_kesh_state != KaraKeshState.IDLE:
		return false
	if target == null or not is_instance_valid(target) or current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		return false
	kara_kesh_state = KaraKeshState.CHARGING_BEAM
	_kara_kesh_beam_target = target
	_kara_kesh_phase_timer = KARA_KESH_BEAM_CHARGE_S
	_kara_kesh_tick_timer = 0.0
	_kara_kesh_beam_cd = KARA_KESH_BEAM_COOLDOWN_S
	_set_crouching(false)
	return true


func _process_kara_kesh(delta: float) -> bool:
	if kara_kesh_state == KaraKeshState.IDLE:
		return false
	if current_state in [State.DEAD, State.STUNNED, State.DOWNED]:
		_cancel_kara_kesh("incapacitated")
		return false

	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

	var aim_target: Node3D = (
		_kara_kesh_beam_target
		if (_kara_kesh_beam_target != null and is_instance_valid(_kara_kesh_beam_target))
		else (current_target if (current_target != null and is_instance_valid(current_target)) else null)
	)
	if aim_target != null and is_instance_valid(aim_target):
		var look := aim_target.global_position - global_position
		look.y = 0.0
		if look.length_squared() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), clampf(12.0 * delta, 0.0, 1.0))

	match kara_kesh_state:
		KaraKeshState.CHARGING_PUSH:
			_kara_kesh_phase_timer -= delta
			if _kara_kesh_phase_timer <= 0.0:
				_execute_kara_kesh_push()
				kara_kesh_state = KaraKeshState.IDLE
			return true
		KaraKeshState.CHARGING_BEAM:
			if not _is_kara_kesh_target_valid(_kara_kesh_beam_target):
				_cancel_kara_kesh("target_lost")
				return false
			_kara_kesh_phase_timer -= delta
			if _kara_kesh_phase_timer <= 0.0:
				if not _has_kara_kesh_los(_kara_kesh_beam_target):
					_cancel_kara_kesh("los_blocked")
					return false
				kara_kesh_state = KaraKeshState.CHANNELING_BEAM
				_kara_kesh_phase_timer = KARA_KESH_BEAM_DURATION_S
				_kara_kesh_tick_timer = 0.0
				kara_kesh_beam_started.emit(_kara_kesh_beam_target)
				_publish_kara_kesh_beam(true, _kara_kesh_beam_target.global_position + Vector3(0.0, 1.1, 0.0))
			return true
		KaraKeshState.CHANNELING_BEAM:
			if not _is_kara_kesh_target_valid(_kara_kesh_beam_target):
				_cancel_kara_kesh("target_lost")
				return false
			if global_position.distance_to(_kara_kesh_beam_target.global_position) > KARA_KESH_BEAM_MAX_RANGE + 1.5:
				_cancel_kara_kesh("out_of_range")
				return false
			if not _has_kara_kesh_los(_kara_kesh_beam_target):
				_cancel_kara_kesh("los_blocked")
				return false
			var end_pt := _kara_kesh_beam_target.global_position + Vector3(0.0, 1.1, 0.0)
			_publish_kara_kesh_beam(true, end_pt)
			_kara_kesh_tick_timer -= delta
			if _kara_kesh_tick_timer <= 0.0:
				_kara_kesh_tick_timer = KARA_KESH_BEAM_TICK_S
				var target_health := _kara_kesh_beam_target.get_node_or_null("HealthComponent") as HealthComponent
				if target_health != null and not target_health.is_dead and not target_health.is_downed:
					target_health.take_damage(KARA_KESH_BEAM_TICK_DAMAGE, self, "kara_kesh_beam")
					if _kara_kesh_beam_target.has_method(&"apply_disorientation"):
						_kara_kesh_beam_target.call(&"apply_disorientation", 0.65, 0.28, 0.55)
					kara_kesh_beam_ticked.emit(_kara_kesh_beam_target, KARA_KESH_BEAM_TICK_DAMAGE)
			_kara_kesh_phase_timer -= delta
			if _kara_kesh_phase_timer <= 0.0:
				_cancel_kara_kesh("completed")
			return true
	return false


func _execute_kara_kesh_push() -> void:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var origin := kara_kesh_mount.global_position if kara_kesh_mount != null else global_position + Vector3(0.0, 1.35, 0.0)
	var affected: int = 0
	var containers: Array[Node] = []
	var players_node := MissionWorld.find(self, "Players")
	if players_node != null:
		containers.append(players_node)
	var allies_node := MissionWorld.find(self, "Allies")
	if allies_node != null:
		containers.append(allies_node)

	for container: Node in containers:
		for child: Node in container.get_children():
			var actor := child as Node3D
			if actor == null or not is_instance_valid(actor):
				continue
			var health := actor.get_node_or_null("HealthComponent") as HealthComponent
			if health == null or health.is_dead or health.is_downed:
				continue
			var offset := actor.global_position - global_position
			var flat := Vector3(offset.x, 0.0, offset.z)
			var dist := flat.length()
			if dist > KARA_KESH_PUSH_RANGE or absf(offset.y) > 2.2:
				continue
			var push_dir := flat.normalized() if dist > 0.05 else forward
			if dist > 1.8 and forward.dot(push_dir) < KARA_KESH_PUSH_HALF_ANGLE_COS:
				continue
			if not _has_kara_kesh_los(actor):
				continue
			affected += 1
			health.take_damage(KARA_KESH_PUSH_DAMAGE, self, "kara_kesh_push")
			if actor.has_method(&"apply_external_impulse"):
				actor.call(&"apply_external_impulse", push_dir * KARA_KESH_PUSH_IMPULSE)
			elif actor is CharacterBody3D:
				(actor as CharacterBody3D).velocity += push_dir * KARA_KESH_PUSH_IMPULSE

	kara_kesh_push_fired.emit(affected)
	play_kara_kesh_push_fx(origin, forward)
	SGCNetworkManager.mission_rpc(self, &"play_kara_kesh_push_fx", [origin, forward], health_component)


func _cancel_kara_kesh(reason: String) -> void:
	var was_active := kara_kesh_state != KaraKeshState.IDLE
	var was_beam := kara_kesh_state == KaraKeshState.CHANNELING_BEAM
	kara_kesh_state = KaraKeshState.IDLE
	_kara_kesh_phase_timer = 0.0
	_kara_kesh_tick_timer = 0.0
	_kara_kesh_beam_target = null
	if was_beam or _kara_kesh_beam_mesh != null:
		if reason == "stand_down":
			_apply_kara_kesh_beam_visual(false, Vector3.ZERO)
		else:
			_publish_kara_kesh_beam(false, Vector3.ZERO)
	if was_active and was_beam:
		kara_kesh_beam_ended.emit(reason)


func _is_kara_kesh_target_valid(target: Variant) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		return false
	var target_node := target as Node3D
	if not target_node.is_inside_tree():
		return false
	var health := target_node.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and (health.is_dead or health.is_downed):
		return false
	return true


func _has_kara_kesh_los(target: Node3D) -> bool:
	if target == null or not is_inside_tree():
		return false
	var world3d := get_world_3d()
	if world3d == null or world3d.direct_space_state == null:
		return false
	var from := kara_kesh_mount.global_position if kara_kesh_mount != null else global_position + Vector3(0.0, 1.35, 0.0)
	var to := target.global_position + Vector3(0.0, 1.1, 0.0)
	var exclude: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	return _cast_los_ray(world3d.direct_space_state, from, to, exclude)


func _publish_kara_kesh_beam(active: bool, end_pos: Vector3) -> void:
	_apply_kara_kesh_beam_visual(active, end_pos)
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		SGCNetworkManager.mission_rpc(self, &"sync_kara_kesh_beam", [active, end_pos], health_component)


@rpc("authority", "call_remote", "unreliable")
func sync_kara_kesh_beam(active: bool, end_pos: Vector3) -> void:
	_apply_kara_kesh_beam_visual(active, end_pos)


func _update_kara_kesh_visuals() -> void:
	if kara_kesh_light != null:
		match kara_kesh_state:
			KaraKeshState.IDLE:
				kara_kesh_light.light_energy = 0.8
				kara_kesh_light.omni_range = 3.2
			KaraKeshState.CHARGING_PUSH:
				kara_kesh_light.light_energy = 4.6
				kara_kesh_light.omni_range = 5.5
			KaraKeshState.CHARGING_BEAM:
				kara_kesh_light.light_energy = 3.8
				kara_kesh_light.omni_range = 4.8
			KaraKeshState.CHANNELING_BEAM:
				kara_kesh_light.light_energy = 5.5
				kara_kesh_light.omni_range = 6.0
	if kara_kesh_state != KaraKeshState.CHANNELING_BEAM and _kara_kesh_beam_mesh != null:
		_kara_kesh_beam_mesh.visible = false


func _apply_kara_kesh_beam_visual(active: bool, end_pos: Vector3) -> void:
	_kara_kesh_beam_end = end_pos
	if not active or not is_inside_tree() or kara_kesh_mount == null:
		if _kara_kesh_beam_mesh != null:
			_kara_kesh_beam_mesh.visible = false
		return
	if _kara_kesh_beam_mesh == null:
		_kara_kesh_beam_mesh = MeshInstance3D.new()
		_kara_kesh_beam_mesh.name = "KaraKeshBeamMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.055
		cyl.bottom_radius = 0.085
		cyl.height = 1.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.82, 0.24, 0.88)
		cyl.material = mat
		_kara_kesh_beam_mesh.mesh = cyl
		_kara_kesh_beam_mesh.top_level = true
		_kara_kesh_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		kara_kesh_mount.add_child(_kara_kesh_beam_mesh)
	var start_pos := kara_kesh_mount.global_position
	var delta_vec := end_pos - start_pos
	var length := delta_vec.length()
	if length < 0.05:
		_kara_kesh_beam_mesh.visible = false
		return
	_kara_kesh_beam_mesh.visible = true
	_kara_kesh_beam_mesh.global_position = start_pos + delta_vec * 0.5
	var up := Vector3.UP if absf(delta_vec.normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	_kara_kesh_beam_mesh.look_at(end_pos, up)
	_kara_kesh_beam_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_kara_kesh_beam_mesh.scale = Vector3(1.0, length, 1.0)


@rpc("call_local", "unreliable")
func play_kara_kesh_push_fx(origin: Vector3, forward: Vector3) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var wave := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.65
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.84, 0.28, 0.9)
	torus.material = mat
	wave.mesh = torus
	wave.top_level = true
	add_child(wave)
	wave.global_position = origin
	var dir := forward.normalized() if forward.length_squared() > 0.001 else -global_transform.basis.z
	wave.look_at(origin + dir, Vector3.UP)
	wave.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := wave.create_tween()
	tw.tween_property(wave, "global_position", origin + dir * (KARA_KESH_PUSH_RANGE * 0.75), 0.24)
	tw.parallel().tween_property(wave, "scale", Vector3(4.2, 4.2, 4.2), 0.24)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tw.tween_callback(wave.queue_free)
