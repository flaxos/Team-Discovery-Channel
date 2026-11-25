extends Node3D
## Presentation for installed pads. The server owns the phase and the riders.

const Metal := preload("res://scripts/props/ring_transport_metal.gdshader")
const Field := preload("res://scripts/props/ring_transport_field.gdshader")
const FIELD_HEIGHT := 2.9

var _phase: StringName = &"INACTIVE"
var _elapsed := 0.0
var _duration := 1.0
var _sending := false
var _rings: Node3D
var _light: OmniLight3D
var _floor_material := ShaderMaterial.new()
var _ring_material := ShaderMaterial.new()
var _field_material := ShaderMaterial.new()
var _field: MeshInstance3D
var _streaks: CPUParticles3D


func configure(rings: Node3D, plate: MeshInstance3D, light: OmniLight3D) -> void:
	_rings = rings
	_light = light
	_rings.position.y = 0.0
	_floor_material.shader = Metal
	_floor_material.set_shader_parameter(&"floor_plate", true)
	plate.material_override = _floor_material
	_ring_material.shader = Metal
	var band := _ring_mesh()
	for ring: MeshInstance3D in _rings.get_children():
		ring.mesh = band
		ring.material_override = _ring_material

	_field_material.shader = Field
	var column := CylinderMesh.new()
	column.top_radius = 2.04
	column.bottom_radius = 2.04
	column.height = FIELD_HEIGHT
	column.cap_top = false
	column.cap_bottom = false
	_field = MeshInstance3D.new()
	_field.mesh = column
	_field.material_override = _field_material
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_field.position.y = FIELD_HEIGHT * 0.5 + 0.095
	add_child(_field)
	_make_streaks()
	_process(0.0)
	set_process(false)


func show_phase(phase: StringName, sending: bool, elapsed: float, duration: float) -> void:
	_phase = phase
	_elapsed = elapsed
	_duration = duration
	_sending = sending
	_field_material.set_shader_parameter(&"receiving", not sending)
	if phase == &"BEAM" and elapsed < 0.20:
		_streaks.position.y = 0.14 if sending else FIELD_HEIGHT - 0.08
		_streaks.direction = Vector3.UP if sending else Vector3.DOWN
		_streaks.restart()
	_process(0.0)
	set_process(phase != &"INACTIVE")


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var lift := 0.0
	var power := 0.0
	var field := 0.0
	var sweep := -1.0
	match _phase:
		&"TELEGRAPH":
			lift = smoothstep(0.19, 0.90, progress)
			power = lerpf(0.08, 0.88, smoothstep(0.0, 0.80, progress))
			field = 0.25 * smoothstep(0.58, 1.0, progress)
		&"SLAM":
			lift = 1.0
			power = 0.9 + 0.1 * progress
			field = 0.40
			sweep = lerpf(-0.06, 0.67, progress) if _sending else -1.0
		&"BEAM":
			lift = 1.0
			power = lerpf(1.0, 0.67, smoothstep(0.30, 1.0, progress))
			field = lerpf(1.0, 0.27, progress)
			sweep = lerpf(0.67, 1.20, progress * 2.0) if _sending else progress * 1.85
		&"RETRACT":
			lift = 1.0 - smoothstep(0.0, 0.94, progress)
			power = 0.67 * (1.0 - smoothstep(0.10, 1.0, progress))
			field = 0.27 * (1.0 - smoothstep(0.0, 0.45, progress))
	_floor_material.set_shader_parameter(&"charge", power)
	_ring_material.set_shader_parameter(&"charge", power)
	_field_material.set_shader_parameter(&"strength", field)
	_field_material.set_shader_parameter(&"sweep", sweep)
	_field.visible = field > 0.001
	_rings.visible = lift > 0.001
	var index := 0
	for ring: MeshInstance3D in _rings.get_children():
		var rise := smoothstep(0.025 * index, 1.0 - 0.035 * index, lift)
		ring.position.y = lerpf(-0.08, 0.32 + 0.54 * index, rise)
		ring.rotation.y = (0.04 * index + 0.18 * (1.0 - rise)) * (-1 if index % 2 else 1)
		ring.visible = ring.position.y >= 0.05
		index += 1
	_light.light_energy = power * power * (1.65 + field * 1.45)


func _make_streaks() -> void:
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.68, 0.26)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.52, 0.11)
	ember_material.emission_energy_multiplier = 1.7
	var ember := BoxMesh.new()
	ember.size = Vector3(0.014, 0.13, 0.014)
	ember.material = ember_material
	_streaks = CPUParticles3D.new()
	_streaks.emitting = false
	_streaks.one_shot = true
	_streaks.amount = 76
	_streaks.lifetime = 0.69
	_streaks.explosiveness = 0.80
	_streaks.gravity = Vector3.ZERO
	_streaks.spread = 4.0
	_streaks.mesh = ember
	_streaks.initial_velocity_min = 1.7
	_streaks.initial_velocity_max = 4.0
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_streaks.emission_ring_axis = Vector3.UP
	_streaks.emission_ring_radius = 2.03
	_streaks.emission_ring_inner_radius = 1.27
	_streaks.emission_ring_height = 0.02
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streaks)


## Machined annulus with bevels. Shared by all five bands at the authored radius.
static func _ring_mesh() -> ArrayMesh:
	var profile := PackedVector2Array([
		Vector2(2.09, 0.052), Vector2(2.12, 0.071), Vector2(2.25, 0.071),
		Vector2(2.30, 0.035), Vector2(2.30, -0.035), Vector2(2.25, -0.071),
		Vector2(2.12, -0.071), Vector2(2.09, -0.052),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in range(72):
		var start := Vector2.from_angle(TAU * side / 72.0)
		var end := Vector2.from_angle(TAU * (side + 1) / 72.0)
		for edge in range(profile.size()):
			var a := profile[edge]
			var b := profile[(edge + 1) % profile.size()]
			var normal := Vector2(a.y - b.y, b.x - a.x).normalized()
			_add_corner(surface, start, a, normal)
			_add_corner(surface, start, b, normal)
			_add_corner(surface, end, a, normal)
			_add_corner(surface, start, b, normal)
			_add_corner(surface, end, b, normal)
			_add_corner(surface, end, a, normal)
	return surface.commit()


static func _add_corner(surface: SurfaceTool, direction: Vector2, profile: Vector2, normal: Vector2) -> void:
	surface.set_normal(Vector3(direction.x * normal.x, normal.y, direction.y * normal.x))
	surface.add_vertex(Vector3(direction.x * profile.x, profile.y, direction.y * profile.x))
