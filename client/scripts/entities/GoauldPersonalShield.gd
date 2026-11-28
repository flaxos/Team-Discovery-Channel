class_name GoauldPersonalShield
extends Node3D
## Server-authoritative velocity-gated Goa'uld Personal Shield component.
## Deflects fast ballistic projectiles and prevents gunfire suppression while active;
## penetrated by slow close-quarters melee/takedowns and overloaded by Zat, Staff plasma, or explosives.
## Intentionally avoids typing JaffaAI / HealthComponent to prevent circular GDScript references.

const SHIELD_SHADER: Shader = preload("res://scripts/entities/goauld_personal_shield.gdshader")

signal shield_state_changed(active: bool, energy: float, max_energy: float, overloaded: bool)
signal shield_deflected(source: Node, damage_type: String, impact_pos: Vector3)
signal shield_overloaded(source: Node, damage_type: String)
signal shield_restored()

const MAX_ENERGY: float = 100.0
const PLASMA_SHIELD_DRAIN: float = 55.0
const OVERLOAD_DURATION_S: float = 6.0
const RECHARGE_DELAY_S: float = 3.5
const RECHARGE_RATE: float = 35.0
const EXPLOSIVE_BLEED_FACTOR: float = 0.50

@export var enabled: bool = false
@export var max_energy: float = MAX_ENERGY

var energy: float = MAX_ENERGY
var is_overloaded: bool = false
var overload_timer: float = 0.0
var recharge_delay_timer: float = 0.0
var frozen: bool = false
var deflect_count: int = 0
var overload_count: int = 0

var aura_mesh: MeshInstance3D = null
var aura_light: OmniLight3D = null
var _aura_mat: ShaderMaterial = null
var _flash_tween: Tween = null
var _revision: int = 0
var _last_revision: int = -1
var _recharge_sync_clock: float = 0.0
var _snapshot_timer: float = 0.0


func _enter_tree() -> void:
	set_multiplayer_authority(1)


func _ready() -> void:
	_build_visuals()
	var health := _health_node()
	if health != null:
		if health.has_signal(&"died"):
			health.connect(&"died", _on_owner_incapacitated)
		if health.has_signal(&"stunned"):
			health.connect(&"stunned", _on_owner_stunned)
		if health.has_signal(&"downed"):
			health.connect(&"downed", _on_owner_incapacitated)
		if health.has_signal(&"vaporized"):
			health.connect(&"vaporized", _on_owner_incapacitated)
		if health.has_signal(&"recovered_from_stun"):
			health.connect(&"recovered_from_stun", _on_owner_recovered)
	_refresh_visuals()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_shield_snapshot.rpc_id(1)


func _build_visuals() -> void:
	if aura_mesh == null:
		aura_mesh = MeshInstance3D.new()
		aura_mesh.name = "AuraMesh"
		var sphere := SphereMesh.new()
		sphere.radius = 0.72
		sphere.height = 2.15
		sphere.radial_segments = 24
		sphere.rings = 14
		aura_mesh.mesh = sphere
		aura_mesh.position = Vector3(0.0, 1.05, 0.0)
		aura_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aura_mat = ShaderMaterial.new()
		_aura_mat.shader = SHIELD_SHADER
		aura_mesh.material_override = _aura_mat
		add_child(aura_mesh)
	if aura_light == null:
		aura_light = OmniLight3D.new()
		aura_light.name = "AuraLight"
		aura_light.position = Vector3(0.0, 1.1, 0.0)
		aura_light.light_color = Color(1.0, 0.72, 0.25)
		aura_light.light_energy = 1.1
		aura_light.omni_range = 3.0
		add_child(aura_light)


func set_shield_enabled(value: bool, publish: bool = true) -> void:
	var changed := enabled != value
	enabled = value
	if value:
		energy = max_energy
		is_overloaded = false
		overload_timer = 0.0
		recharge_delay_timer = 0.0
	_refresh_visuals()
	if _can_mutate() and changed:
		shield_state_changed.emit(is_active(), energy, max_energy, is_overloaded)
		if publish and is_node_ready():
			_publish_state()


func is_active() -> bool:
	return enabled and not frozen and not is_overloaded and energy > 0.0 and _owner_can_project_shield()


func stand_down() -> void:
	frozen = true
	overload_timer = 0.0
	recharge_delay_timer = 0.0
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	set_physics_process(false)
	_refresh_visuals()


func _physics_process(delta: float) -> void:
	if not _can_mutate() or frozen or not enabled or not _owner_can_project_shield():
		return
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0 and (is_overloaded or energy < max_energy):
		_snapshot_timer = 0.25
		_publish_state()
	if is_overloaded:
		overload_timer -= delta
		if overload_timer <= 0.0:
			is_overloaded = false
			overload_timer = 0.0
			energy = max_energy
			recharge_delay_timer = 0.0
			_refresh_visuals()
			shield_restored.emit()
			shield_state_changed.emit(is_active(), energy, max_energy, false)
			_publish_state("restore")
	elif energy < max_energy:
		if recharge_delay_timer > 0.0:
			recharge_delay_timer = maxf(0.0, recharge_delay_timer - delta)
			return
		var prev_energy := energy
		energy = minf(max_energy, energy + RECHARGE_RATE * delta)
		if _aura_mat != null:
			_aura_mat.set_shader_parameter(&"energy_ratio", clampf(energy / maxf(max_energy, 1.0), 0.0, 1.0))
		_recharge_sync_clock += delta
		if energy >= max_energy or _recharge_sync_clock >= 0.25:
			_recharge_sync_clock = 0.0
			if energy != prev_energy:
				shield_state_changed.emit(is_active(), energy, max_energy, false)
				_publish_state()


func intercept_damage(amount: float, source: Node, damage_type: String) -> Dictionary:
	if not is_active() or not _can_mutate() or frozen:
		return {"blocked": false, "damage": amount}

	if damage_type in [
		"stealth_takedown", "melee_slow", "melee_slow_flank",
		"kawoosh_vortex", "ring_crush", "zat_kill", "zat_vaporize"
	]:
		return {"blocked": false, "damage": amount}

	if damage_type in ["bullet", "50cal_heavy", "thrown_knife", "thrown_knife_stealth"]:
		deflect_count += 1
		var impact := _impact_point_for(source)
		_play_deflect_fx(impact)
		shield_deflected.emit(source, damage_type, impact)
		_publish_state("deflect", impact)
		return {"blocked": true, "damage": 0.0}

	if damage_type == "plasma":
		energy = maxf(0.0, energy - PLASMA_SHIELD_DRAIN)
		recharge_delay_timer = RECHARGE_DELAY_S
		if energy <= 0.0:
			_trigger_overload(source, damage_type)
		else:
			deflect_count += 1
			var impact := _impact_point_for(source)
			_play_deflect_fx(impact)
			shield_deflected.emit(source, damage_type, impact)
			shield_state_changed.emit(is_active(), energy, max_energy, false)
			_publish_state("deflect", impact)
		return {"blocked": true, "damage": 0.0}

	if damage_type in ["c4_explosion", "claymore_shrapnel"]:
		_trigger_overload(source, damage_type)
		return {"blocked": false, "damage": amount * EXPLOSIVE_BLEED_FACTOR}

	return {"blocked": false, "damage": amount}


func intercept_zat(source: Node) -> bool:
	if not is_active() or not _can_mutate() or frozen:
		return false
	_trigger_overload(source, "zat_overload")
	return true


func _trigger_overload(source: Node, damage_type: String) -> void:
	energy = 0.0
	is_overloaded = true
	overload_timer = OVERLOAD_DURATION_S
	recharge_delay_timer = 0.0
	overload_count += 1
	_refresh_visuals()
	_play_overload_fx()
	shield_overloaded.emit(source, damage_type)
	shield_state_changed.emit(false, 0.0, max_energy, true)
	_publish_state("overload", global_position + Vector3(0.0, 1.05, 0.0))


func _on_owner_stunned(_duration: float) -> void:
	_refresh_visuals()


func _on_owner_incapacitated() -> void:
	_refresh_visuals()


func _on_owner_recovered() -> void:
	_refresh_visuals()


func _refresh_visuals() -> void:
	var show_aura := is_active()
	if aura_mesh != null:
		aura_mesh.visible = show_aura
	if aura_light != null:
		aura_light.visible = show_aura
		if show_aura:
			aura_light.light_energy = 1.1 * (0.5 + 0.5 * clampf(energy / maxf(max_energy, 1.0), 0.0, 1.0))
	if _aura_mat != null:
		_aura_mat.set_shader_parameter(&"energy_ratio", clampf(energy / maxf(max_energy, 1.0), 0.0, 1.0))


func _play_deflect_fx(impact_pos: Vector3) -> void:
	if _aura_mat != null:
		_aura_mat.set_shader_parameter(&"impact_flash", 1.0)
		_aura_mat.set_shader_parameter(&"energy_ratio", clampf(energy / maxf(max_energy, 1.0), 0.0, 1.0))
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_method(
			func(val: float) -> void:
				if _aura_mat != null:
					_aura_mat.set_shader_parameter(&"impact_flash", val),
			1.0,
			0.0,
			0.18
		)
	if aura_light != null and aura_light.visible:
		aura_light.light_energy = 3.2
		var lt := create_tween()
		lt.tween_property(aura_light, "light_energy", 1.1, 0.16)
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.85, 0.35)
	spark.light_energy = 4.5
	spark.omni_range = 2.6
	add_child(spark)
	spark.global_position = impact_pos
	var st := spark.create_tween()
	st.tween_property(spark, "light_energy", 0.0, 0.12)
	st.tween_callback(spark.queue_free)


func _play_overload_fx() -> void:
	if _aura_mat != null:
		_aura_mat.set_shader_parameter(&"overload_flash", 1.0)
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_method(
			func(val: float) -> void:
				if _aura_mat != null:
					_aura_mat.set_shader_parameter(&"overload_flash", val),
			1.0,
			0.0,
			0.22
		)
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var burst := OmniLight3D.new()
	burst.light_color = Color(0.35, 0.85, 1.0)
	burst.light_energy = 6.0
	burst.omni_range = 4.0
	add_child(burst)
	burst.global_position = global_position + Vector3(0.0, 1.1, 0.0)
	var bt := burst.create_tween()
	bt.tween_property(burst, "light_energy", 0.0, 0.22)
	bt.tween_callback(burst.queue_free)
	if ResourceLoader.exists("res://audio/sfx_zat.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://audio/sfx_zat.wav")
		audio.bus = &"SFX"
		audio.max_distance = 35.0
		add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()


func _impact_point_for(source: Node) -> Vector3:
	var center := global_position + Vector3(0.0, 1.1, 0.0)
	if source is Node3D and is_instance_valid(source):
		var dir := ((source as Node3D).global_position + Vector3(0.0, 1.1, 0.0)) - center
		if dir.length_squared() > 0.001:
			return center + dir.normalized() * 0.72
	return center + (-global_basis.z) * 0.72


func _health_node() -> Node:
	var parent := get_parent()
	return parent.get_node_or_null("HealthComponent") if parent != null else null


func _owner_can_project_shield() -> bool:
	var health := _health_node()
	if health == null:
		return true
	return not (
		bool(health.get("is_dead"))
		or bool(health.get("is_downed"))
		or bool(health.get("is_stunned"))
		or bool(health.get("is_vaporized"))
	)


func _can_mutate() -> bool:
	return not is_inside_tree() or not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _state() -> Dictionary:
	return {
		"revision": _revision,
		"enabled": enabled,
		"energy": energy,
		"max_energy": max_energy,
		"overloaded": is_overloaded,
		"overload_timer": overload_timer,
	}


func _publish_state(event: String = "", impact_pos: Vector3 = Vector3.ZERO) -> void:
	_revision += 1
	if is_inside_tree() and not is_queued_for_deletion() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		SGCNetworkManager.mission_rpc(
			self, &"sync_shield_state", [_state(), event, impact_pos], _health_node()
		)


@rpc("any_peer", "call_remote", "reliable")
func request_shield_snapshot() -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		var net: Node = get_node_or_null("/root/NetworkManager")
		if net != null and net.is_in_active_session() and multiplayer == net.multiplayer:
			if not (net.get("mission_ready_peers") as Dictionary).has(sender):
				return
		if sender in multiplayer.get_peers():
			sync_shield_state.rpc_id(sender, _state(), "", Vector3.ZERO)


@rpc("authority", "call_remote", "reliable")
func sync_shield_state(state: Dictionary, event: String, impact_pos: Vector3) -> void:
	var revision: int = int(state.get("revision", -1))
	if revision <= _last_revision:
		return
	_last_revision = revision
	var was_overloaded := is_overloaded
	enabled = bool(state.get("enabled", enabled))
	energy = float(state.get("energy", energy))
	max_energy = float(state.get("max_energy", max_energy))
	is_overloaded = bool(state.get("overloaded", false))
	overload_timer = float(state.get("overload_timer", 0.0))
	if event == "deflect":
		deflect_count += 1
		_play_deflect_fx(impact_pos)
	elif event == "overload":
		overload_count += 1
		_play_overload_fx()
	elif event == "restore" and was_overloaded and not is_overloaded:
		shield_restored.emit()
	_refresh_visuals()
	shield_state_changed.emit(is_active(), energy, max_energy, is_overloaded)
