class_name WeaponBase
extends Node3D
## Base class for SGC firearms, Staff Weapons, and Zat'nik'tels.
## Handles fire rate cooldown, magazine management, spread cones, firing raycasts,
## procedural low-poly weapon meshes, and dynamic muzzle anchoring.

signal fired(origin: Vector3, direction: Vector3, hit_point: Vector3, hit_target: Node)
signal reloaded()
signal ammo_changed(current: int, reserve: int)

const DISPLAY_NAMES := {
	"m249": "M249 SAW Squad Automatic Weapon",
	"m9": "Beretta M9 9mm Pistol",
	"mp5": "HK MP5-SD Tactical SMG",
	"p90": "FN P90 Tactical PDW",
	"staff_weapon": "Ma'Tok Staff Weapon",
	"zat": "Zat'nik'tel",
}

@export var weapon_id: String = "p90"
@export var display_name: String = "FN P90 PDW"
@export var damage: float = 24.0
@export var fire_rate_rpm: float = 900.0
@export var mag_capacity: int = 50
@export var reserve_capacity: int = 250
## Empty for energy/unknown weapons. Compatibility is authored, never supplied by a client.
@export var ammo_type: String = ""
@export var reload_time_s: float = 2.0
@export var base_spread_deg: float = 2.0
@export var bloom_per_shot_deg: float = 0.45
@export var max_spread_deg: float = 7.5
@export var spread_recovery_rate: float = 16.0
@export var max_range_m: float = 50.0

@export var is_plasma: bool = false
@export var is_zat: bool = false
@export var uses_heat: bool = false
@export var heat_per_shot: float = 18.0
@export var heat_dissipation_rate: float = 22.0
@export var overheat_cooldown_time: float = 3.0
@export var plasma_speed_mps: float = 35.0
@export var fire_sound_path: String = "res://audio/sfx_p90.wav"
## Metres a shot is heard by patrolling sentries, in a straight line (walls do not muffle it).
## Suppressed weapons use a small radius; 0 is silent.
@export var noise_radius: float = 30.0

var current_ammo: int = 50
var reserve_ammo: int = 250
var magazine_size: int:
	get:
		return mag_capacity
	set(val):
		mag_capacity = val
		current_ammo = val
var current_spread_deg: float = 2.0
var current_heat: float = 0.0
var is_overheated: bool = false
var overheat_timer: float = 0.0
var is_reloading: bool = false
var fire_cooldown: float = 0.0

signal heat_changed(current_heat: float, is_overheated: bool)

@onready var muzzle_point: Marker3D = $MuzzlePoint if has_node("MuzzlePoint") else null
var audio_player: AudioStreamPlayer3D = null


func _ready() -> void:
	current_ammo = mag_capacity
	reserve_ammo = reserve_capacity
	current_spread_deg = base_spread_deg
	_setup_audio()
	_build_weapon_visual_mesh()


func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists(fire_sound_path):
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "FireAudio"
		audio_player.stream = load(fire_sound_path)
		audio_player.max_distance = 50.0
		audio_player.unit_size = 10.0
		add_child(audio_player)


const GLB_MODELS := {
	"p90": "res://assets/weapons/p90.glb",
	"mp5": "res://assets/weapons/mp5sd.glb",
	"m9": "res://assets/weapons/beretta_m9.glb",
	"m249": "res://assets/weapons/m249.glb",
	"staff_weapon": "res://assets/weapons/tri_vane_staff.glb",
	"zat": "res://assets/weapons/loop_frame_zat.glb",
}
## Sprint 7: source +X faces the suppressor crown; measured centre in packed FBX units.
## The wrapper uses a measured centimetre scale, keeping the gameplay muzzle unchanged.
const MP5_MODEL_MUZZLE := Vector3(32.410175, -4.766182, 0.012022)
const MP5_MODEL_BASIS := Basis(Vector3(0, 0, -0.01), Vector3(0, 0.01, 0), Vector3(0.01, 0, 0))
## AP-1f: COLLADA conversion faces -X; measured crown centre, scaled to metres.
const M249_MODEL_MUZZLE := Vector3(-481.81909, 113.9233, 0.00441)
const M249_MODEL_BASIS := Basis(Vector3(0, 0, 0.001), Vector3(0, 0.001, 0), Vector3(-0.001, 0, 0))
## AP-1e: measured bore centre and scale of p90.glb in its own space (muzzle faces -Z).
## The wrapper applies the measured scale and puts this point on the unchanged MuzzlePoint.
const P90_MODEL_MUZZLE := Vector3(-0.002205, -0.448702, -8.765554)
const P90_MODEL_SCALE := 0.02847984
const P90_MODEL_BASIS := Basis(
	Vector3(P90_MODEL_SCALE, 0, 0),
	Vector3(0, P90_MODEL_SCALE, 0),
	Vector3(0, 0, P90_MODEL_SCALE)
)
## AP-1d: measured bore centre of beretta_m9.glb in its own space (muzzle faces model -X).
## The wrapper turns it to face -Z and puts this point on the unchanged MuzzlePoint.
const M9_MODEL_MUZZLE := Vector3(-0.1255, 0.1303, 0.0)
const M9_MODEL_BASIS := Basis(Vector3.UP, -PI / 2.0)
## Parsed and sanitized weapon models, kept on the tree root for the session so that every
## operative's copy shares one set of meshes and textures. Decoding the M9's textures takes
## about 55 ms; without this every peer paid it when each operative first drew a sidearm.
const GLB_CACHE_META := &"weapon_glb_cache"
## Measured centre of the staff's circular nose lip in the authored mesh.
const STAFF_MODEL_EMITTER := Vector3(0.0, 0.0, -1.05)
## Keeps the 1.907 m NPC visual within its 2 m procedural envelope.
const JAFFA_STAFF_VISUAL_SCALE := 1.16
## Measured aperture centre in the authored sidearm's -Z weapon space.
const ZAT_MODEL_EMITTER := Vector3(0, 0.05, -0.20)


static func attach_staff_visual(parent: Node3D, muzzle: Vector3, visual_scale: float = 1.0) -> bool:
	var model := load_glb_model(GLB_MODELS["staff_weapon"])
	if model == null:
		return false
	var basis := Basis.from_scale(Vector3.ONE * visual_scale)
	model.transform = Transform3D(basis, muzzle - basis * STAFF_MODEL_EMITTER)
	parent.add_child(model)
	return true


static func load_glb_model(res_path: String) -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	var cache: Dictionary = tree.root.get_meta(GLB_CACHE_META, {}) if tree != null else {}
	var template := cache.get(res_path) as PackedScene
	if template == null:
		template = _parse_glb_model(res_path)
		if template == null:
			return null
		if tree != null:
			cache[res_path] = template
			tree.root.set_meta(GLB_CACHE_META, cache)
	var imported := template.instantiate() as Node3D
	imported.name = "ImportedGLB"
	return imported


static func _parse_glb_model(res_path: String) -> PackedScene:
	var global_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(global_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(global_path, state) != OK:
		return null
	var imported := doc.generate_scene(state) as Node3D
	if imported == null:
		return null
	RuntimeGLB.apply_mesh_lods(imported)
	_sanitize_glb_materials(imported, res_path == GLB_MODELS["m249"])
	for node: Node in imported.find_children("*", "", true, false):
		node.owner = imported
	var template := PackedScene.new()
	var packed := template.pack(imported)
	imported.free()
	return template if packed == OK else null


static func _sanitize_glb_materials(root_node: Node, ignore_vertex_colors: bool = false) -> void:
	if root_node is MeshInstance3D:
		var mi := root_node as MeshInstance3D
		if mi.material_override is BaseMaterial3D:
			var mat := (mi.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			mat.metallic = 0.0
			if ignore_vertex_colors:
				mat.vertex_color_use_as_albedo = false
			mi.material_override = mat
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var smat := mi.get_surface_override_material(s) as BaseMaterial3D
				if smat == null:
					smat = mi.mesh.surface_get_material(s) as BaseMaterial3D
				if smat != null:
					var clean := smat.duplicate() as BaseMaterial3D
					clean.metallic = 0.0
					if ignore_vertex_colors:
						# The SAW's COLLADA contains part-ID colours, not an albedo tint.
						clean.vertex_color_use_as_albedo = false
					RuntimeGLB.add_mipmaps(clean)
					mi.set_surface_override_material(s, clean)
	for child in root_node.get_children():
		_sanitize_glb_materials(child, ignore_vertex_colors)


func _build_weapon_visual_mesh() -> void:
	if has_node("WeaponModel"):
		return

	var model_root := Node3D.new()
	model_root.name = "WeaponModel"
	add_child(model_root)

	var muzzle_offset := Vector3(0, 0, -0.45)

	match weapon_id:
		"p90":
			muzzle_offset = Vector3(0, 0.02, -0.30)
			var glb_p90 := load_glb_model(GLB_MODELS["p90"])
			if glb_p90 != null:
				# AP-1e: CC BY 4.0 model by Rotuma (credits/ATTRIBUTIONS.md), real size.
				glb_p90.transform = Transform3D(
					P90_MODEL_BASIS, muzzle_offset - P90_MODEL_BASIS * P90_MODEL_MUZZLE
				)
				model_root.add_child(glb_p90)
			else:
				# Compact bullpup frame fallback
				var receiver := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.08, 0.14, 0.44)
				receiver.mesh = rm
				var rmat := StandardMaterial3D.new()
				rmat.albedo_color = Color(0.18, 0.20, 0.22)
				receiver.material_override = rmat
				model_root.add_child(receiver)

				# Top horizontal magazine strip
				var mag := MeshInstance3D.new()
				var mm := BoxMesh.new()
				mm.size = Vector3(0.06, 0.03, 0.32)
				mag.mesh = mm
				var mmat := StandardMaterial3D.new()
				mmat.albedo_color = Color(0.85, 0.65, 0.2, 0.85)
				mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mag.material_override = mmat
				mag.position = Vector3(0, 0.08, 0.02)
				model_root.add_child(mag)

		"m249":
			muzzle_offset = Vector3(0, 0.03, -0.62)
			var glb_m249 := load_glb_model(GLB_MODELS["m249"])
			if glb_m249 != null:
				# AP-1f: CC BY 4.0 model by AK / skaf13; keep all gameplay anchors.
				glb_m249.transform = Transform3D(
					M249_MODEL_BASIS, muzzle_offset - M249_MODEL_BASIS * M249_MODEL_MUZZLE
				)
				model_root.add_child(glb_m249)
			else:
				# Heavy machine gun receiver + box drum
				var receiver := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.10, 0.16, 0.62)
				receiver.mesh = rm
				var rmat := StandardMaterial3D.new()
				rmat.albedo_color = Color(0.24, 0.26, 0.28)
				rmat.metallic = 0.8
				receiver.material_override = rmat
				model_root.add_child(receiver)

				var drum := MeshInstance3D.new()
				var dm := BoxMesh.new()
				dm.size = Vector3(0.12, 0.14, 0.16)
				drum.mesh = dm
				var dmat := StandardMaterial3D.new()
				dmat.albedo_color = Color(0.22, 0.30, 0.18)
				drum.material_override = dmat
				drum.position = Vector3(0, -0.12, 0.04)
				model_root.add_child(drum)

				var barrel := MeshInstance3D.new()
				var bm := CylinderMesh.new()
				bm.top_radius = 0.02
				bm.bottom_radius = 0.02
				bm.height = 0.35
				barrel.mesh = bm
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.15, 0.15, 0.15)
				bmat.metallic = 0.9
				barrel.material_override = bmat
				barrel.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90)), Vector3(0, 0.03, -0.42))
				model_root.add_child(barrel)

		"mp5":
			muzzle_offset = Vector3(0, 0.01, -0.36)
			var glb_mp5 := load_glb_model(GLB_MODELS["mp5"])
			if glb_mp5 != null:
				# WillyG99 CC BY 4.0 MP5SD body; optional source optic is omitted.
				glb_mp5.transform = Transform3D(
					MP5_MODEL_BASIS, muzzle_offset - MP5_MODEL_BASIS * MP5_MODEL_MUZZLE
				)
				model_root.add_child(glb_mp5)
			else:
				# SMG frame + curved magazine fallback
				var receiver := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.07, 0.12, 0.40)
				receiver.mesh = rm
				var rmat := StandardMaterial3D.new()
				rmat.albedo_color = Color(0.12, 0.13, 0.15)
				receiver.material_override = rmat
				model_root.add_child(receiver)

				var mag := MeshInstance3D.new()
				var mm := BoxMesh.new()
				mm.size = Vector3(0.04, 0.16, 0.06)
				mag.mesh = mm
				var mmat := StandardMaterial3D.new()
				mmat.albedo_color = Color(0.2, 0.2, 0.22)
				mag.material_override = mmat
				mag.position = Vector3(0, -0.11, -0.06)
				mag.rotation_degrees.x = 15.0
				model_root.add_child(mag)

			muzzle_offset = Vector3(0, 0.01, -0.36)

		"staff_weapon":
			muzzle_offset = Vector3(0, 0, -1.05)
			var staff_muzzle := muzzle_point.position if muzzle_point != null else muzzle_offset
			if not attach_staff_visual(model_root, staff_muzzle):
				# Long Goa'uld Naquadah bronze polearm with flared plasma head
				var shaft := MeshInstance3D.new()
				var sm := CylinderMesh.new()
				sm.top_radius = 0.025
				sm.bottom_radius = 0.025
				sm.height = 1.6
				shaft.mesh = sm
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.68, 0.50, 0.20)
				smat.metallic = 0.85
				smat.roughness = 0.3
				shaft.material_override = smat
				shaft.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90)), Vector3(0, 0, -0.2))
				model_root.add_child(shaft)

				var head := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(0.09, 0.14, 0.24)
				head.mesh = hm
				var hmat := StandardMaterial3D.new()
				hmat.albedo_color = Color(0.9, 0.6, 0.15)
				hmat.emission_enabled = true
				hmat.emission = Color(1.0, 0.55, 0.1)
				hmat.emission_energy_multiplier = 1.2
				head.material_override = hmat
				head.position = Vector3(0, 0, -0.95)
				model_root.add_child(head)

		"zat":
			muzzle_offset = Vector3(0, 0.05, -0.20)
			var zat_visual := load_glb_model(GLB_MODELS["zat"])
			if zat_visual != null:
				var zat_muzzle := muzzle_point.position if muzzle_point != null else muzzle_offset
				zat_visual.position = zat_muzzle - ZAT_MODEL_EMITTER
				model_root.add_child(zat_visual)
			else:
				# Serpentine curved Goa'uld sidearm with glowing blue arc emitter
				var body := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.06, 0.14, 0.24)
				body.mesh = bm
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.60, 0.45, 0.20)
				bmat.metallic = 0.85
				body.material_override = bmat
				model_root.add_child(body)

				var arc := MeshInstance3D.new()
				var am := SphereMesh.new()
				am.radius = 0.035
				am.height = 0.07
				arc.mesh = am
				var amat := StandardMaterial3D.new()
				amat.albedo_color = Color(0.2, 0.65, 1.0)
				amat.emission_enabled = true
				amat.emission = Color(0.2, 0.65, 1.0)
				amat.emission_energy_multiplier = 1.5
				arc.material_override = amat
				arc.position = Vector3(0, 0.05, -0.14)
				model_root.add_child(arc)

		"m9":
			muzzle_offset = Vector3(0, 0.02, -0.18)
			var glb_m9 := load_glb_model(GLB_MODELS["m9"])
			if glb_m9 != null:
				# AP-1d: CC BY 4.0 model by emran.bayati (credits/ATTRIBUTIONS.md), real size.
				glb_m9.transform = Transform3D(
					M9_MODEL_BASIS, muzzle_offset - M9_MODEL_BASIS * M9_MODEL_MUZZLE
				)
				model_root.add_child(glb_m9)
			else:
				# Sleek black 9mm handgun fallback
				var slide := MeshInstance3D.new()
				var sm := BoxMesh.new()
				sm.size = Vector3(0.05, 0.07, 0.20)
				slide.mesh = sm
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.12, 0.12, 0.14)
				smat.metallic = 0.7
				slide.material_override = smat
				model_root.add_child(slide)

				var grip := MeshInstance3D.new()
				var gm := BoxMesh.new()
				gm.size = Vector3(0.05, 0.10, 0.06)
				grip.mesh = gm
				var gmat := StandardMaterial3D.new()
				gmat.albedo_color = Color(0.08, 0.08, 0.08)
				grip.material_override = gmat
				grip.position = Vector3(0, -0.06, 0.06)
				grip.rotation_degrees.x = 12.0
				model_root.add_child(grip)

	if muzzle_point == null:
		var mp := Marker3D.new()
		mp.name = "MuzzlePoint"
		mp.position = muzzle_offset
		add_child(mp)
		muzzle_point = mp


func _process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown = maxf(0.0, fire_cooldown - delta)

	# Bloom recovery toward base spread
	if current_spread_deg > base_spread_deg:
		current_spread_deg = move_toward(current_spread_deg, base_spread_deg, spread_recovery_rate * delta)

	# Heat dissipation & venting for energy weapons
	if uses_heat:
		if is_overheated:
			overheat_timer -= delta
			if overheat_timer <= 0.0:
				is_overheated = false
				current_heat = 0.0
				heat_changed.emit(current_heat, is_overheated)
		elif current_heat > 0.0:
			current_heat = maxf(0.0, current_heat - heat_dissipation_rate * delta)
			heat_changed.emit(current_heat, is_overheated)


## Attempts to discharge the weapon, factoring in spread modifier (moving, crouch).
func _operative() -> Node:
	var actor: Node = get_parent()
	while actor != null and not actor is PlayerController3D:
		actor = actor.get_parent()
	return actor


func consume_shot() -> bool:
	if is_reloading or fire_cooldown > 0.0:
		return false

	if uses_heat:
		if is_overheated:
			return false
		current_heat += heat_per_shot
		if current_heat >= 100.0:
			current_heat = 100.0
			is_overheated = true
			overheat_timer = overheat_cooldown_time
			heat_changed.emit(current_heat, is_overheated)
		else:
			heat_changed.emit(current_heat, is_overheated)
	else:
		if current_ammo <= 0:
			if not is_reloading and reserve_ammo > 0:
				reload()
			return false
		current_ammo -= 1
		ammo_changed.emit(current_ammo, reserve_ammo)

	var shot_interval := 60.0 / fire_rate_rpm
	fire_cooldown = shot_interval

	# Accumulate spread bloom
	current_spread_deg = minf(max_spread_deg, current_spread_deg + bloom_per_shot_deg)

	return true


func try_fire(spread_mult: float = 1.0, direction_override: Vector3 = Vector3.ZERO) -> bool:
	if MissionWorld.combat_ended(self):
		return false
	var operative: Node = _operative()
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return operative.request_weapon_fire() if operative != null and operative.is_local_authority else false
	if not consume_shot():
		return false

	var origin: Vector3 = muzzle_point.global_position if muzzle_point != null else global_position
	var base_forward: Vector3 = -global_transform.basis.z

	# 3D Aim-Elevation: if parent operative has an active 3D aim target, align shot vector toward it
	var parent_entity: Node = get_parent()
	if parent_entity != null and not ("current_aim_target" in parent_entity) and parent_entity.get_parent() != null:
		parent_entity = parent_entity.get_parent()

	if parent_entity != null and "current_aim_target" in parent_entity:
		var target: Vector3 = parent_entity.get("current_aim_target")
		if target != Vector3.ZERO:
			base_forward = (target - origin).normalized()

	if direction_override != Vector3.ZERO:
		base_forward = direction_override

	# Apply cone spread
	var effective_spread_deg := current_spread_deg * spread_mult
	var spread_rad := deg_to_rad(effective_spread_deg)
	var random_yaw := randf_range(-spread_rad, spread_rad)
	var random_pitch := randf_range(-spread_rad * 0.5, spread_rad * 0.5)
	var dir := (base_forward.rotated(Vector3.UP, random_yaw)).rotated(base_forward.cross(Vector3.UP).normalized(), random_pitch).normalized()

	_perform_shot(origin, dir)
	return true


func _perform_shot(origin: Vector3, dir: Vector3) -> void:
	if MissionWorld.combat_ended(self):
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if audio_player != null:
		audio_player.play()
	var shooter: Node = _operative()
	if noise_radius > 0.0 and is_inside_tree():
		get_tree().call_group(
			&"noise_listeners", &"hear", origin, noise_radius, shooter if shooter != null else get_parent()
		)

	if is_plasma:
		var bolt_scene := load("res://scenes/entities/PlasmaBolt.tscn") as PackedScene
		if bolt_scene != null:
			var bolt := bolt_scene.instantiate() as PlasmaBolt
			var actor: Node = _operative()
			if actor == null:
				actor = get_parent()
			var is_enemy: bool = not actor is PlayerController3D
			bolt.damage = damage
			bolt.speed = plasma_speed_mps
			get_tree().root.add_child(bolt)
			bolt.initialize(origin, dir, actor, is_enemy)
			fired.emit(origin, dir, origin + dir * max_range_m, null)
			return

	var world := get_world_3d()
	if world == null:
		fired.emit(origin, dir, origin + dir * max_range_m, null)
		return

	var space := world.direct_space_state
	var exclude_list: Array[RID] = []
	if get_parent() is CollisionObject3D:
		exclude_list.append((get_parent() as CollisionObject3D).get_rid())
	elif get_parent() != null and get_parent().get_parent() is CollisionObject3D:
		exclude_list.append((get_parent().get_parent() as CollisionObject3D).get_rid())

	var range_end := origin + dir * max_range_m
	var hit_pos := range_end
	var trace_end := range_end
	var hit_node: Node = null

	# Trace ray with ballistic penetration through reinforced observation glass
	for iter in range(4):
		var query := PhysicsRayQueryParameters3D.create(origin, range_end)
		query.collision_mask = 1 | 2 | 4 | 128 | (64 if is_zat else 0)  # Zat can target nonblocking corpses.
		query.exclude = exclude_list
		var result := space.intersect_ray(query)
		if result.is_empty():
			trace_end = range_end
			break

		var col: Node = result["collider"] as Node
		hit_pos = result["position"]
		trace_end = hit_pos
		hit_node = col

		# If hit observation glass, allow high-velocity bullet penetration through window
		if col != null and (col.name.contains("Glass") or col.name.contains("Overlook")):
			if result.has("rid"):
				exclude_list.append(result["rid"])
			continue
		else:
			_apply_hit(hit_node)
			break

	if not is_zat and not is_plasma and shooter is PlayerController3D:
		var mission := MissionWorld.of(shooter)
		if mission.has_method(&"register_operative_shot"):
			mission.register_operative_shot(origin, trace_end, hit_node)
	fired.emit(origin, dir, hit_pos, hit_node)


func _apply_hit(target: Node) -> void:
	if (multiplayer.has_multiplayer_peer() and not multiplayer.is_server()) or target == null:
		return
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		if is_zat:
			health.apply_zat_shot(_operative() if _operative() != null else get_parent())
		else:
			var damage_type := "plasma" if is_plasma else "bullet"
			health.take_damage(damage, _operative() if _operative() != null else get_parent(), damage_type)


func reload() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var actor: Node = _operative()
		if actor != null and actor.is_local_authority:
			actor.request_weapon_reload()
		return
	if uses_heat or is_reloading or current_ammo >= mag_capacity or reserve_ammo <= 0:
		return
	is_reloading = true
	_notify_operative_state()
	var timer := get_tree().create_timer(reload_time_s)
	timer.timeout.connect(func() -> void:
		var needed := mag_capacity - current_ammo
		var transfer := mini(needed, reserve_ammo)
		current_ammo += transfer
		reserve_ammo -= transfer
		is_reloading = false
		ammo_changed.emit(current_ammo, reserve_ammo)
		reloaded.emit()
		_notify_operative_state()
	)


func resupply() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	reserve_ammo = reserve_capacity
	ammo_changed.emit(current_ammo, reserve_ammo)
	_notify_operative_state()


func _notify_operative_state() -> void:
	var actor: Node = _operative()
	if actor != null and actor.has_method("_broadcast_weapon_state"):
		actor._broadcast_weapon_state()
