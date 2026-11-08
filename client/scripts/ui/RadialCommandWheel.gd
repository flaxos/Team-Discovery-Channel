class_name RadialCommandWheel
extends Control
## Radial Squad Command Wheel for Project SGC (Godot 4.4.1).
## Tri-sensory radial interface for commanding allied SGC Airmen.

signal command_selected(command_index: int, target_world_pos: Vector3)
signal wheel_opened()
signal wheel_closed()

const CMD_CANCEL: int = -1
const CMD_MOVE_TO_COVER: int = 0
const CMD_HOLD_CORNER: int = 1
const CMD_SUPPRESS_HALLWAY: int = 2
const CMD_MAN_50_CAL: int = 3
const CMD_REGROUP_ON_ME: int = 4

const SLICE_NAMES: Array[String] = [
	"MOVE TO COVER",
	"HOLD CORNER",
	"SUPPRESS HALLWAY",
	"MAN .50 CAL",
	"REGROUP ON ME"
]

const SLICE_CHEVRONS: Array[String] = [
	"▲",
	"▶",
	"▼",
	"⚙",
	"◀"
]

const SLICE_ANGLES_DEG: Array[float] = [
	90.0,   # 0: North
	18.0,   # 1: North-East
	-54.0,  # 2: South-East
	-126.0, # 3: South-West
	162.0   # 4: North-West
]

const BOUNDARY_ANGLES_DEG: Array[float] = [
	54.0,
	-18.0,
	-90.0,
	-162.0,
	126.0
]

const SLICE_START_ANGLES_DEG: Array[float] = [
	54.0,   # 0: MOVE TO COVER (54° to 126°)
	-18.0,  # 1: HOLD CORNER (-18° to 54°)
	-90.0,  # 2: SUPPRESS HALLWAY (-90° to -18°)
	-162.0, # 3: MAN .50 CAL (-162° to -90°)
	126.0   # 4: REGROUP ON ME (126° to 198° / -162°)
]

const SLICE_SWEEP_DEG: float = 72.0

@export var outer_radius: float = 140.0
@export var deadzone_radius: float = 45.0

var wheel_center: Vector2 = Vector2.ZERO
var locked_target_pos: Vector3 = Vector3.ZERO
var current_mouse_offset: Vector2 = Vector2.ZERO
var selected_command: int = CMD_CANCEL
var is_wheel_active: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func open_wheel(initial_mouse_pos: Vector2, target_pos: Vector3) -> void:
	var vp_rect: Rect2 = get_viewport_rect()
	if vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0 and initial_mouse_pos != Vector2.ZERO:
		wheel_center = initial_mouse_pos.clamp(
			Vector2(outer_radius + 20.0, outer_radius + 20.0),
			vp_rect.size - Vector2(outer_radius + 20.0, outer_radius + 20.0)
		)
	else:
		wheel_center = initial_mouse_pos if initial_mouse_pos != Vector2.ZERO else (vp_rect.size * 0.5 if vp_rect.size.x > 0.0 else Vector2(640.0, 360.0))

	locked_target_pos = target_pos
	current_mouse_offset = Vector2.ZERO
	selected_command = CMD_CANCEL
	is_wheel_active = true
	visible = true
	wheel_opened.emit()
	queue_redraw()


func update_mouse_direction(mouse_rel: Vector2) -> void:
	if not is_wheel_active:
		return
	current_mouse_offset += mouse_rel
	_recompute_selection()


func update_mouse_position(mouse_pos: Vector2) -> void:
	if not is_wheel_active:
		return
	current_mouse_offset = mouse_pos - wheel_center
	_recompute_selection()


func get_selected_command() -> int:
	return selected_command


func close_wheel() -> void:
	is_wheel_active = false
	visible = false
	wheel_closed.emit()
	queue_redraw()


func _recompute_selection() -> void:
	var dist: float = current_mouse_offset.length()
	if dist < deadzone_radius:
		selected_command = CMD_CANCEL
	else:
		# Standard Cartesian angle where North (screen -Y) is 90°
		var deg: float = rad_to_deg(atan2(-current_mouse_offset.y, current_mouse_offset.x))
		selected_command = _angle_to_slice(deg)
	queue_redraw()


func _angle_to_slice(deg: float) -> int:
	if deg >= 54.0 and deg < 126.0:
		return CMD_MOVE_TO_COVER
	elif deg >= -18.0 and deg < 54.0:
		return CMD_HOLD_CORNER
	elif deg >= -90.0 and deg < -18.0:
		return CMD_SUPPRESS_HALLWAY
	elif deg >= -162.0 and deg < -90.0:
		return CMD_MAN_50_CAL
	else:
		return CMD_REGROUP_ON_ME


func _get_wedge_points(center: Vector2, start_deg: float, sweep_deg: float, r_in: float, r_out: float, steps: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Outer arc: start_deg -> start_deg + sweep_deg
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var d: float = start_deg + sweep_deg * t
		var rad: float = deg_to_rad(d)
		pts.append(center + Vector2(cos(rad), -sin(rad)) * r_out)

	# Inner arc: start_deg + sweep_deg -> start_deg
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var d: float = (start_deg + sweep_deg) - sweep_deg * t
		var rad: float = deg_to_rad(d)
		pts.append(center + Vector2(cos(rad), -sin(rad)) * r_in)

	return pts


func _draw() -> void:
	if not visible and not is_wheel_active:
		return

	var c: Vector2 = wheel_center
	if c == Vector2.ZERO:
		var vp: Rect2 = get_viewport_rect()
		c = vp.size * 0.5 if vp.size.x > 0.0 else Vector2(640.0, 360.0)

	# 1. Outer dark translucent circular background ring
	var bg_color := Color(0.04, 0.07, 0.10, 0.85)
	draw_circle(c, outer_radius, bg_color)

	# Outer subtle glow border
	draw_arc(c, outer_radius, 0.0, TAU, 64, Color(0.2, 0.8, 0.6, 0.7), 2.0, true)
	draw_arc(c, outer_radius + 2.0, 0.0, TAU, 64, Color(0.1, 0.4, 0.3, 0.35), 1.0, true)

	# 2. Highlighted wedge in glowing SGC green/cyan when hovered
	if selected_command >= 0 and selected_command < 5:
		var start_d: float = SLICE_START_ANGLES_DEG[selected_command]
		var wedge_pts: PackedVector2Array = _get_wedge_points(c, start_d, SLICE_SWEEP_DEG, deadzone_radius, outer_radius)
		var fill_color := Color(0.2, 0.9, 0.5, 0.4)
		draw_colored_polygon(wedge_pts, fill_color)

		# Brighter glowing border
		var border_pts: PackedVector2Array = wedge_pts.duplicate()
		border_pts.append(wedge_pts[0])
		draw_polyline(border_pts, Color(0.3, 1.0, 0.6, 0.95), 2.5, true)

	# 3. 5 Segment dividers in SGC cyan / amber
	var divider_color := Color(0.2, 0.8, 0.6, 0.6)
	for i: int in range(BOUNDARY_ANGLES_DEG.size()):
		var d: float = BOUNDARY_ANGLES_DEG[i]
		var rad: float = deg_to_rad(d)
		var p_in: Vector2 = c + Vector2(cos(rad), -sin(rad)) * deadzone_radius
		var p_out: Vector2 = c + Vector2(cos(rad), -sin(rad)) * outer_radius
		draw_line(p_in, p_out, divider_color, 2.0, true)

	# 4. Center deadzone circle (< 45px radius) with CANCEL
	var cancel_hovered: bool = (selected_command == CMD_CANCEL)
	var deadzone_bg: Color = Color(0.7, 0.2, 0.15, 0.45) if cancel_hovered else Color(0.02, 0.04, 0.07, 0.92)
	var deadzone_border: Color = Color(1.0, 0.4, 0.3, 0.95) if cancel_hovered else Color(0.25, 0.55, 0.5, 0.65)
	draw_circle(c, deadzone_radius, deadzone_bg)
	draw_arc(c, deadzone_radius, 0.0, TAU, 48, deadzone_border, 2.0, true)

	var font: Font = get_theme_default_font()
	var cancel_text: String = "[ CANCEL ]"
	var cancel_color: Color = Color(1.0, 0.4, 0.3, 1.0) if cancel_hovered else Color(0.55, 0.7, 0.75, 0.85)
	var cancel_size: Vector2 = font.get_string_size(cancel_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2(c.x - cancel_size.x * 0.5, c.y + cancel_size.y * 0.35), cancel_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cancel_color)

	# 5. Slice labels and icons / chevrons for each order
	for i: int in range(5):
		var is_hovered: bool = (selected_command == i)
		var center_deg: float = SLICE_ANGLES_DEG[i]
		var rad: float = deg_to_rad(center_deg)
		var label_r: float = (deadzone_radius + outer_radius) * 0.5
		var label_pos: Vector2 = c + Vector2(cos(rad), -sin(rad)) * label_r

		var text_color: Color = Color(0.35, 1.0, 0.75, 1.0) if is_hovered else Color(0.85, 0.92, 0.95, 0.85)

		var chev_text: String = SLICE_CHEVRONS[i]
		var chev_size: Vector2 = font.get_string_size(chev_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, Vector2(label_pos.x - chev_size.x * 0.5, label_pos.y - 4.0), chev_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)

		var name_text: String = SLICE_NAMES[i]
		var name_size: Vector2 = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
		draw_string(font, Vector2(label_pos.x - name_size.x * 0.5, label_pos.y + 11.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, text_color)

	# 6. Cursor direction pointer if outside deadzone
	if current_mouse_offset.length() >= deadzone_radius:
		var dir_norm: Vector2 = current_mouse_offset.normalized()
		var p_start: Vector2 = c + dir_norm * (deadzone_radius + 2.0)
		var p_end: Vector2 = c + dir_norm * (outer_radius - 8.0)
		draw_line(p_start, p_end, Color(0.3, 1.0, 0.7, 0.75), 2.0, true)
		draw_circle(p_end, 3.5, Color(0.4, 1.0, 0.8, 0.95))
