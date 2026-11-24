extends Node3D
## The instrument sits on the east bench and has no collider or interaction.

const MODEL_PATH := "res://assets/props/industrial_microscope.glb"
const ENVELOPE := AABB(Vector3(-0.46, 0, -0.42), Vector3(0.92, 0.54, 0.84))


func _ready() -> void:
	var instrument := RuntimeGLB.load_scene(MODEL_PATH)
	if instrument == null:
		return
	var body := instrument.get_node_or_null(^"industrial_microscope") as MeshInstance3D
	if body == null or body.mesh == null or body.mesh.get_surface_count() != 1:
		instrument.free()
		return
	var material := body.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		instrument.free()
		return
	var fit := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3.ZERO) * instrument.transform
	var bounds := fit * body.transform * body.get_aabb()
	var floor_center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	bounds.position -= floor_center
	if not ENVELOPE.grow(0.001).encloses(bounds):
		instrument.free()
		return
	material.metallic *= 0.35
	RuntimeGLB.add_mipmaps(material)
	fit.origin -= floor_center
	instrument.transform = fit
	instrument.name = "ImportedInstrument"
	add_child(instrument)
