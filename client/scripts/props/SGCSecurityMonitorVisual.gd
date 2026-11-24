extends MeshInstance3D
## Replaces the console render after all four CRTs fit inside its collision hull.

const CRT_PATH := "res://assets/props/sprint18_television.glb"
const SPACING := 0.91
const INACTIVE := Color(0.53, 0.67, 0.68)
const SELECTED := Color(0.52, 1, 0.88)

var feed_labels: Array[Label3D] = []


func _ready() -> void:
	var box := get_parent() as CSGBox3D
	var console := get_parent() as SecurityMonitorConsole
	if box == null or console == null:
		return
	var model := RuntimeGLB.load_scene(CRT_PATH)
	if model == null:
		return
	var source := model.find_child("television_02", true, false) as MeshInstance3D
	if source == null or source.mesh == null:
		model.free()
		return
	var crt := source.mesh
	var finish := source.get_active_material(0) as StandardMaterial3D
	model.free()
	if finish == null:
		return
	var crt_finish := finish.duplicate() as StandardMaterial3D
	crt_finish.metallic = 0.0
	crt_finish.cull_mode = BaseMaterial3D.CULL_BACK
	RuntimeGLB.add_mipmaps(crt_finish)

	var envelope := AABB(-box.size / 2, box.size).grow(0.002)
	var cabinet := BoxMesh.new()
	cabinet.size = Vector3(0.57, 1.0, 3.94)
	if not envelope.encloses(transform * cabinet.get_aabb()):
		return
	var placements: Array[Transform3D] = []
	var facing := Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * 1.25)
	for index in range(SecurityMonitorConsole.FEEDS.size()):
		var z := (1.5 - float(index)) * SPACING
		var placement := Transform3D(facing, Vector3(0.055, 0.50, z))
		if not envelope.encloses((transform * placement) * crt.get_aabb()):
			return
		placements.append(placement)

	mesh = cabinet
	var cabinet_finish := StandardMaterial3D.new()
	cabinet_finish.albedo_color = Color(0.21, 0.27, 0.29)
	cabinet_finish.roughness = 0.72
	material_override = cabinet_finish
	for index in range(placements.size()):
		var monitor := MeshInstance3D.new()
		monitor.name = "Monitor%d" % (index + 1)
		monitor.mesh = crt
		monitor.material_override = crt_finish
		monitor.transform = placements[index]
		add_child(monitor)
		var label := Label3D.new()
		label.name = "Feed%d" % (index + 1)
		label.text = "CAM %02d" % (index + 1)
		label.font_size = 24
		label.pixel_size = 0.0024
		label.outline_size = 3
		label.rotation.y = PI / 2
		label.position = Vector3(0.289, 0.40, monitor.position.z)
		feed_labels.append(label)
		add_child(label)

	set_selected_feed(-1)
	console.cctv_cycled.connect(func(index: int, _feed_name: String) -> void:
		set_selected_feed(index)
	)
	console.cctv_exited.connect(func(_player: PlayerController3D) -> void:
		set_selected_feed(-1)
	)
	box.transparency = 1.0
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_selected_feed(index: int) -> void:
	for label_index in range(feed_labels.size()):
		feed_labels[label_index].modulate = SELECTED if label_index == index else INACTIVE
