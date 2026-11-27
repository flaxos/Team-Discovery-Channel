class_name RuntimeGLB
extends RefCounted
## Loads a self-contained .glb kept raw in the project (`importer="keep"`) at runtime.
##
## The bytes are read from the res:// path itself, so the same call works from the source
## folder and from inside an exported .pck (checked with the 4.4.1 Linux release template).
## It does not depend on ProjectSettings.globalize_path(), which returns a relative path in
## an exported build that only resolves because FileAccess also searches the pack.

const TEXTURE_SLOTS: Array[StringName] = [
	&"albedo_texture", &"normal_texture", &"roughness_texture", &"metallic_texture",
	&"ao_texture", &"emission_texture",
]


static func load_scene(res_path: String) -> Node3D:
	if not FileAccess.file_exists(res_path):
		return null
	var bytes := FileAccess.get_file_as_bytes(res_path)
	if bytes.is_empty():
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_buffer(bytes, res_path.get_base_dir(), state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


## Runtime glTF images arrive without mipmaps, so they shimmer at range. Replaces each texture
## slot of `material` with a mipmapped copy in place; slots that shared a texture still share.
static func add_mipmaps(material: BaseMaterial3D) -> BaseMaterial3D:
	var done := {}
	for property in TEXTURE_SLOTS:
		var texture := material.get(property) as Texture2D
		if texture == null:
			continue
		if not done.has(texture):
			var image := texture.get_image()
			if image != null and not image.is_compressed() and not image.has_mipmaps():
				image.generate_mipmaps()
				done[texture] = ImageTexture.create_from_image(image)
			else:
				done[texture] = texture
		material.set(property, done[texture])
	return material


## Generates native hardware LOD index levels via ImporterMesh on heavy meshes
## while preserving exact LOD0 vertices/triangles, bounds, materials and skin bindings.
static func apply_mesh_lods(scene: Node, min_triangles: int = 2000) -> int:
	if scene == null:
		return 0
	var generated_total := 0
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or not (mi.mesh is ArrayMesh):
			continue
		var src := mi.mesh as ArrayMesh
		var surf_count := src.get_surface_count()
		if surf_count == 0:
			continue
		var first_rs: Dictionary = RenderingServer.mesh_get_surface(src.get_rid(), 0)
		if not (first_rs.get("lods", []) as Array).is_empty():
			continue
		var src_tris := 0
		var src_surface_tris: Array[int] = []
		for s in range(surf_count):
			var idx := src.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array
			var tris := idx.size() / 3
			src_tris += tris
			src_surface_tris.append(tris)
		if src_tris < min_triangles:
			continue
		var imp := ImporterMesh.new()
		var custom_mask: int = (
			Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
			| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
			| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
		)
		for s in range(surf_count):
			var arr := src.surface_get_arrays(s)
			var flags := src.surface_get_format(s) & custom_mask
			imp.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, src.surface_get_material(s), src.surface_get_name(s), flags)
		imp.generate_lods(deg_to_rad(60.0), deg_to_rad(25.0), [])
		var lods_here := 0
		for s in range(imp.get_surface_count()):
			lods_here += imp.get_surface_lod_count(s)
		if lods_here == 0:
			continue
		var baked := imp.get_mesh()
		if baked == null or baked.get_surface_count() != surf_count:
			continue
		if not baked.get_aabb().is_equal_approx(src.get_aabb()):
			continue
		var lod0_preserved := true
		for s in range(surf_count):
			var b_idx := baked.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array
			if b_idx.size() / 3 != src_surface_tris[s]:
				lod0_preserved = false
				break
		if not lod0_preserved:
			continue
		mi.mesh = baked
		generated_total += lods_here
	return generated_total
