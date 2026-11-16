extends SceneTree
## Packs a staged community model (FBX, glTF or GLB) into one self-contained GLB for the game,
## driven by a JSON recipe kept with the intake record. Run headless from the client project:
##
##   godot --headless --path client --script res://scripts/assets/pack_model_glb.gd -- <recipe.json>
##
## Keep the staged source outside client/ and never run anything that ships inside it. The
## recipe and the PACK_RESULT line belong in docs/assets/intake/<asset>/; see
## docs/assets/community-asset-playbook.md.
##
## What it may change, and only what the recipe asks for: which source nodes are kept, which
## texture maps feed each material (maps the source file does not bind), the texture size
## (downscaled, never upscaled), a DirectX normal map's green channel, and the packing of
## occlusion/roughness/metallic into one ORM image as glTF expects. Geometry, node transforms,
## units and UVs are kept as the source defines them; orient and scale in the game wrapper.
## It prints one PACK_RESULT JSON line describing the output for the intake record.
##
## Recipe keys (paths are relative to the recipe's folder unless absolute):
##   source            model file (.fbx, .gltf, .glb)
##   output            output .glb (relative paths resolve against the recipe folder)
##   root_name         name of the output scene root
##   keep_nodes        source mesh node names to keep (all mesh nodes when omitted)
##   max_texture_size  longest side for every map, e.g. 1024
##   image_format      "JPEG" or "PNG" for the embedded images
##   lossy_quality     0..1 for JPEG
##   materials         {"<source material name or *>": {"albedo", "normal", "normal_convention"
##                     ("opengl" | "directx"), "roughness", "metallic", "ao"}}; single-channel
##                     maps are read from their red channel


func _init() -> void:
	call_deferred("run")


func fail(message: String) -> void:
	printerr("pack_model_glb: " + message)
	quit(1)


func resolve(base: String, path: String) -> String:
	return path if path.is_absolute_path() else base.path_join(path).simplify_path()


func load_map(base: String, path: String, max_size: int) -> Image:
	var image := Image.load_from_file(resolve(base, path))
	if image == null or image.is_empty():
		return null
	image.decompress()
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	var longest := maxi(image.get_width(), image.get_height())
	if max_size > 0 and longest > max_size:
		var scale := float(max_size) / longest
		image.resize(
			maxi(1, roundi(image.get_width() * scale)),
			maxi(1, roundi(image.get_height() * scale)),
			Image.INTERPOLATE_LANCZOS
		)
	return image


## R = occlusion, G = roughness, B = metallic; a missing map becomes white (no effect).
func pack_orm(base: String, spec: Dictionary, max_size: int) -> Image:
	var maps: Array[Image] = []
	var size := Vector2i.ZERO
	for key: String in ["ao", "roughness", "metallic"]:
		var image: Image = load_map(base, spec[key], max_size) if spec.has(key) else null
		maps.append(image)
		if image != null:
			size = image.get_size()
	if size == Vector2i.ZERO:
		return null
	var orm := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for i in range(maps.size()):
		if maps[i] != null and maps[i].get_size() != size:
			maps[i].resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in range(size.y):
		for x in range(size.x):
			orm.set_pixel(x, y, Color(
				maps[0].get_pixel(x, y).r if maps[0] != null else 1.0,
				maps[1].get_pixel(x, y).r if maps[1] != null else 1.0,
				maps[2].get_pixel(x, y).r if maps[2] != null else 1.0
			))
	return orm


func build_material(base: String, spec: Dictionary, max_size: int, name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	if spec.has("albedo"):
		material.albedo_texture = ImageTexture.create_from_image(load_map(base, spec.albedo, max_size))
	if spec.has("normal"):
		var normal := load_map(base, spec.normal, max_size)
		if str(spec.get("normal_convention", "opengl")) == "directx":
			for y in range(normal.get_height()):
				for x in range(normal.get_width()):
					var c := normal.get_pixel(x, y)
					normal.set_pixel(x, y, Color(c.r, 1.0 - c.g, c.b))
		material.normal_enabled = true
		material.normal_texture = ImageTexture.create_from_image(normal)
	var orm := pack_orm(base, spec, max_size)
	if orm != null:
		var texture := ImageTexture.create_from_image(orm)
		material.roughness = 1.0
		material.roughness_texture = texture
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.metallic = 1.0 if spec.has("metallic") else 0.0
		material.metallic_texture = texture
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		if spec.has("ao"):
			material.ao_enabled = true
			material.ao_texture = texture
			material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return material


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		fail("usage: -- <recipe.json>")
		return
	# A relative recipe path is taken from the shell's working directory, not the project.
	var recipe_path := ProjectSettings.globalize_path(arguments[0])
	if recipe_path.is_relative_path():
		recipe_path = OS.get_environment("PWD").path_join(recipe_path).simplify_path()
	var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	if not recipe is Dictionary:
		fail("cannot read recipe " + recipe_path)
		return
	var base := recipe_path.get_base_dir()
	var source := resolve(base, str(recipe.source))
	var output := resolve(base, str(recipe.output))
	var max_size := int(recipe.get("max_texture_size", 1024))
	var state: GLTFState
	var scene: Node
	if source.get_extension().to_lower() == "fbx":
		var fbx := FBXDocument.new()
		state = FBXState.new()
		if fbx.append_from_file(source, state) != OK:
			fail("cannot parse " + source)
			return
		scene = fbx.generate_scene(state)
	else:
		var gltf := GLTFDocument.new()
		state = GLTFState.new()
		if gltf.append_from_file(source, state) != OK:
			fail("cannot parse " + source)
			return
		scene = gltf.generate_scene(state)
	var keep: Array = recipe.get("keep_nodes", [])
	var materials: Dictionary = recipe.get("materials", {})
	var root := Node3D.new()
	root.name = str(recipe.get("root_name", "Model"))
	var kept: Array[Dictionary] = []
	var built := {}
	for node: Node in scene.find_children("*", "", true, false):
		var mesh: ArrayMesh = null
		if node is ImporterMeshInstance3D:
			mesh = (node as ImporterMeshInstance3D).mesh.get_mesh()
		elif node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh as ArrayMesh
		if mesh == null or (not keep.is_empty() and not keep.has(str(node.name))):
			continue
		var placed := Transform3D.IDENTITY
		var walk: Node = node
		while walk != scene and walk is Node3D:
			placed = (walk as Node3D).transform * placed
			walk = walk.get_parent()
		var instance := MeshInstance3D.new()
		instance.name = node.name
		instance.mesh = mesh
		instance.transform = placed
		var triangles := 0
		for s in range(mesh.get_surface_count()):
			var source_name := mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) else ""
			var spec: Dictionary = materials.get(source_name, materials.get("*", {}))
			if not spec.is_empty():
				var key := source_name if materials.has(source_name) else "*"
				if not built.has(key):
					built[key] = build_material(base, spec, max_size, source_name)
				mesh.surface_set_material(s, built[key])
			triangles += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		root.add_child(instance)
		instance.owner = root
		kept.append({"name": str(node.name), "triangles": triangles,
			"bounds": str(placed * mesh.get_aabb())})
	scene.free()
	if kept.is_empty():
		root.free()
		fail("no mesh nodes kept")
		return
	var out_doc := GLTFDocument.new()
	out_doc.image_format = str(recipe.get("image_format", "JPEG"))
	out_doc.lossy_quality = float(recipe.get("lossy_quality", 0.9))
	var out_state := GLTFState.new()
	var result := out_doc.append_from_scene(root, out_state)
	if result == OK:
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		result = out_doc.write_to_filesystem(out_state, output)
	root.free()
	if result != OK:
		fail("cannot write " + output)
		return
	print("PACK_RESULT ", JSON.stringify({"output": output, "bytes": FileAccess.get_file_as_bytes(output).size(),
		"sha256": FileAccess.get_sha256(output), "meshes": kept, "max_texture_size": max_size,
		"image_format": out_doc.image_format, "lossy_quality": out_doc.lossy_quality}))
	quit(0)
