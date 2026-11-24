class_name CrateStackVisual
extends Node3D
## AP-1c cosmetic proof: dresses a gameplay box with a stack of Poly Haven "Plastic Crate 02"
## (CC0, see credits/ATTRIBUTIONS.md). Visual only: it adds no collision or navigation and
## changes no gameplay state. The dressed box keeps its size, collision, interaction and
## authority; it only stops drawing itself. If the model cannot be loaded or does not fit,
## nothing changes and the original box stays visible.

const MODEL_PATH := "res://assets/props/plastic_crate_02_1k.glb"
const LOD_MESH_PATH := "res://assets/props/plastic_crate_02_lods.res"
## Olive drab in place of the source's orange colour factor, to sit with the SGC armoury.
const DEFAULT_TINT := Color(0.36, 0.42, 0.26)
## Same allowance as SGCMap.replace_asset_visual().
const ENVELOPE_TOLERANCE := 0.02
## A crate may be scaled uniformly by at most this much to fill a box.
const MIN_SCALE := 0.9
const MAX_SCALE := 1.1
const CACHE_META := &"crate_stack_visual_cache"

## Crates drawn (hidden interior crates are skipped) and the uniform scale applied to each.
var crate_count := 0
var crate_scale := 1.0
## Union of the drawn crates in the dressed box's local space.
var bounds := AABB()


static func dress_box(
	box: CSGBox3D, tint: Color = DEFAULT_TINT, model_path: String = MODEL_PATH
) -> CrateStackVisual:
	var mesh := crate_mesh(box, model_path, tint)
	if mesh == null:
		return null
	var visual := CrateStackVisual.new()
	if not visual.build(mesh, AABB(-box.size / 2.0, box.size)):
		visual.free()
		return null
	visual.name = "ReplacementVisual"
	box.add_child(visual)
	# The box stays as the collision and interaction body; it just stops being drawn.
	box.transparency = 1.0
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


## Loads the crate once per tint while any stack that uses it is alive.
static func crate_mesh(anchor: Node, model_path: String, tint: Color) -> ArrayMesh:
	var key := "%s|%s" % [model_path, tint.to_html()]
	var root: Node = anchor.get_tree().root if anchor.is_inside_tree() else null
	var cache: Dictionary = root.get_meta(CACHE_META, {}) if root != null else {}
	var cached := cache.get(key) as WeakRef
	if cached != null and cached.get_ref() != null:
		return cached.get_ref() as ArrayMesh
	var scene := RuntimeGLB.load_scene(model_path)
	if scene == null:
		return null
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var source := meshes[0] as MeshInstance3D if meshes.size() == 1 else null
	var mesh := source.mesh as ArrayMesh if source != null else null
	# The measured asset is one surface at the scene origin; refuse anything else.
	var placed := source != null and source.transform.is_equal_approx(Transform3D.IDENTITY)
	scene.free()
	if mesh == null or not placed or mesh.get_surface_count() != 1:
		return null
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return null
	if model_path == MODEL_PATH and ResourceLoader.exists(LOD_MESH_PATH):
		var lod_mesh := ResourceLoader.load(LOD_MESH_PATH, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if lod_mesh != null and lod_mesh.get_surface_count() == 1 and lod_mesh.get_aabb().is_equal_approx(mesh.get_aabb()):
			mesh = lod_mesh
	mesh.surface_set_material(0, prepared_material(material, tint))
	if root != null:
		cache[key] = weakref(mesh)
		root.set_meta(CACHE_META, cache)
	return mesh


## Runtime-only adjustments; the committed GLB keeps the source material unchanged.
static func prepared_material(source: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	# The glTF asks for BLEND, but its JPEG base colour has no alpha channel; the vents are
	# painted dark. Drawing it opaque avoids transparent sorting and keeps depth and shadows.
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color = tint
	# Poly Haven's ARM map carries occlusion in red; the source glTF only wires G/B.
	material.ao_enabled = true
	material.ao_texture = material.roughness_texture
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	RuntimeGLB.add_mipmaps(material)
	return material


## Fills `envelope` (dressed box local space) with whole crates, bottoms on its floor.
func build(mesh: Mesh, envelope: AABB) -> bool:
	var unit := mesh.get_aabb()
	if unit.size.x <= 0.0 or unit.size.y <= 0.0 or unit.size.z <= 0.0:
		return false
	var counts := Vector3i(
		maxi(1, roundi(envelope.size.x / unit.size.x)),
		maxi(1, roundi(envelope.size.y / unit.size.y)),
		maxi(1, roundi(envelope.size.z / unit.size.z))
	)
	var fit := envelope.size / (Vector3(counts) * unit.size)
	crate_scale = minf(fit.x, minf(fit.y, fit.z))
	if crate_scale < MIN_SCALE or crate_scale > MAX_SCALE:
		return false
	var pitch := unit.size * crate_scale
	var start := Vector3(
		envelope.get_center().x - pitch.x * (counts.x - 1) / 2.0,
		envelope.position.y,
		envelope.get_center().z - pitch.z * (counts.z - 1) / 2.0
	)
	var pivot := Vector3(unit.get_center().x, unit.position.y, unit.get_center().z)
	var transforms: Array[Transform3D] = []
	var merged := AABB()
	for iy in range(counts.y):
		for ix in range(counts.x):
			for iz in range(counts.z):
				var hidden := (
					iy < counts.y - 1
					and ix > 0 and ix < counts.x - 1
					and iz > 0 and iz < counts.z - 1
				)
				if hidden:
					continue
				# Alternate 180 degree turns so the same scuffs do not line up.
				var basis := Basis(Vector3.UP, PI * ((ix + iy + iz) % 2)).scaled(
					Vector3.ONE * crate_scale
				)
				var at := start + Vector3(ix * pitch.x, iy * pitch.y, iz * pitch.z)
				var placed := Transform3D(basis, at - basis * pivot)
				merged = merged.merge(placed * unit) if not transforms.is_empty() else placed * unit
				transforms.append(placed)
	if not envelope.grow(ENVELOPE_TOLERANCE).encloses(merged):
		return false
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var crates := MultiMeshInstance3D.new()
	crates.name = "Crates"
	crates.multimesh = multimesh
	# Give the camera a per-stack override so fading never changes the shared material.
	crates.material_override = mesh.surface_get_material(0)
	add_child(crates)
	crate_count = transforms.size()
	bounds = merged
	return true
