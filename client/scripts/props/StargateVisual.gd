class_name StargateVisual
extends Node3D
## Rigid community glyph ring and seven visual chevrons on the existing gameplay anchors.
## No collision, authority, dialing, iris, horizon or travel state lives in this wrapper.

const MODEL_PATH := "res://assets/props/stargate_sg1.glb"
const CACHE_META := &"stargate_visual_cache"
## Source X is depth, -Z is up; match the existing 2.75 m clear aperture.
const RING_SCALE := 40.97343
const RING_BASIS := Basis(
	Vector3(0, 0, RING_SCALE), Vector3(-RING_SCALE, 0, 0), Vector3(0, -RING_SCALE, 0)
)
## Fit the source's top-chevron insert inside each unchanged 0.5 x 0.7 x 0.4 m anchor.
const CHEVRON_SCALE := 27.7
const CHEVRON_CENTRE := Vector3(0, 0, -0.0778175)
const CHEVRON_BASIS := Basis(
	Vector3(0, 0, CHEVRON_SCALE), Vector3(-CHEVRON_SCALE, 0, 0), Vector3(0, -CHEVRON_SCALE, 0)
)
const PARTS: Array[String] = ["chevron", "chevron_back", "chevron_light", "chevron_light_back"]
const ENVELOPE := AABB(Vector3(-3.35, -3.35, -0.3), Vector3(6.7, 6.7, 0.6))

var controller: Node3D
var lights: Array[MeshInstance3D] = []
var unlit: StandardMaterial3D
var lit: StandardMaterial3D
var last_locked := -1
var bounds := AABB()


static func attach(gate: Node3D, model_path: String = MODEL_PATH) -> StargateVisual:
	var ring := gate.get_node_or_null("GateRingMesh") as MeshInstance3D
	var anchors := gate.get_node_or_null("Chevrons") as Node3D
	if ring == null or anchors == null or anchors.get_child_count() != 7 or gate.has_node("CommunityVisual"):
		return null
	var template := model_template(gate, model_path)
	if template == null:
		return null
	var source := template.instantiate() as Node3D
	var visual := StargateVisual.new()
	visual.name = "CommunityVisual"
	visual.controller = gate
	var valid := visual.build(source, anchors)
	source.free()
	if not valid:
		visual.free()
		return null
	gate.add_child(visual)
	# All validation precedes hiding placeholders. The original nodes remain authoritative.
	ring.hide()
	for node: Node in anchors.get_children():
		var box := node as CSGBox3D
		box.transparency = 1.0
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.update_chevrons()
	return visual


static func model_template(anchor: Node, model_path: String) -> PackedScene:
	var cache: Dictionary = anchor.get_tree().root.get_meta(CACHE_META, {})
	if cache.has(model_path):
		return cache[model_path] as PackedScene
	var source := RuntimeGLB.load_scene(model_path)
	if source == null:
		return null
	var materials := {}
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var original := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if original == null:
				source.free()
				return null
			if not materials.has(original):
				var material := original.duplicate() as StandardMaterial3D
				material.metallic = 0.0
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				RuntimeGLB.add_mipmaps(material)
				materials[original] = material
			mi.set_surface_override_material(s, materials[original])
	for node: Node in source.find_children("*", "", true, false):
		node.owner = source
	var packed := PackedScene.new()
	var result := packed.pack(source)
	source.free()
	if result != OK:
		return null
	cache[model_path] = packed
	anchor.get_tree().root.set_meta(CACHE_META, cache)
	return packed


func build(source: Node3D, anchors: Node3D) -> bool:
	var ring := source.get_node_or_null("gate_ring") as MeshInstance3D
	if ring == null:
		return false
	for part in PARTS:
		if not source.get_node_or_null(part) is MeshInstance3D:
			return false
	for node: Node in anchors.get_children():
		if not node is CSGBox3D:
			return false
	var drawn_ring := ring.duplicate() as MeshInstance3D
	drawn_ring.transform = Transform3D(RING_BASIS, Vector3.ZERO) * ring.transform
	add_child(drawn_ring)
	bounds = drawn_ring.transform * drawn_ring.get_aabb()
	var light_source := source.get_node("chevron_light") as MeshInstance3D
	unlit = (light_source.get_surface_override_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	lit = unlit.duplicate() as StandardMaterial3D
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.45, 0.05)
	lit.emission_energy_multiplier = 4.0
	var placed := Transform3D(CHEVRON_BASIS, -(CHEVRON_BASIS * CHEVRON_CENTRE))
	for i in range(7):
		var anchor := anchors.get_child(i) as CSGBox3D
		var chevron := Node3D.new()
		chevron.name = "Chevron%d" % (i + 1)
		chevron.transform = anchor.transform
		add_child(chevron)
		for part in PARTS:
			var mi := (source.get_node(part) as MeshInstance3D).duplicate() as MeshInstance3D
			mi.transform = placed * mi.transform
			var local_bounds := mi.transform * mi.get_aabb()
			if not AABB(-anchor.size / 2.0, anchor.size).grow(0.02).encloses(local_bounds):
				mi.free()
				return false
			chevron.add_child(mi)
			bounds = bounds.merge(chevron.transform * local_bounds)
			if part.begins_with("chevron_light"):
				lights.append(mi)
	return ENVELOPE.grow(0.02).encloses(bounds)


func _process(_delta: float) -> void:
	update_chevrons()


func update_chevrons() -> void:
	var count := clampi(int(controller.get("locked_chevrons_count")), 0, 7)
	if count == last_locked:
		return
	last_locked = count
	# Includes snapshot/late join and reset paths, which do not all emit chevron_locked.
	for i in range(lights.size()):
		lights[i].set_surface_override_material(0, lit if i / 2 < count else unlit)
