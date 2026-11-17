extends SceneTree
## A real rigid packing round trip: lossless PNG, DirectX conversion and ORM channel binding.


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var folder := OS.get_user_data_dir().path_join("packer-map-test-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var source := Node3D.new()
	source.name = "Reference"
	var mesh := MeshInstance3D.new()
	mesh.name = "ReferenceBox"
	mesh.mesh = BoxMesh.new()
	source.add_child(mesh)
	mesh.owner = source
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(source, state) == OK)
	assert(document.write_to_filesystem(state, folder.path_join("source.glb")) == OK)
	source.free()
	var colours := {"albedo": Color(0.6, 0.3, 0.2), "normal": Color(0.3, 0.8, 1.0),
		"ao": Color(0.2, 0.2, 0.2), "roughness": Color(0.4, 0.4, 0.4), "metallic": Color(0.7, 0.7, 0.7)}
	var maps := {"normal_convention": "directx"}
	for key: String in colours:
		var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
		image.fill(colours[key])
		assert(image.save_png(folder.path_join(key + ".png")) == OK)
		maps[key] = key + ".png"
	var recipe := {"source": "source.glb", "output": "packed.glb", "image_format": "PNG",
		"max_texture_size": 4, "materials": {"*": maps}}
	var file := FileAccess.open(folder.path_join("recipe.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(recipe))
	file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://scripts/assets/pack_model_glb.gd",
		"--", folder.path_join("recipe.json")]), output, true)
	assert(code == 0 and not str(output).contains("ERROR:"), "Packer subprocess: " + str(output))
	var packed_state := GLTFState.new()
	assert(document.append_from_file(folder.path_join("packed.glb"), packed_state) == OK)
	for image: Dictionary in packed_state.json.get("images", []):
		assert(image.get("mimeType") == "image/png", "Data maps encoded losslessly")
	var loaded := document.generate_scene(packed_state)
	var loaded_mesh := loaded.find_child("ReferenceBox", true, false) as MeshInstance3D
	assert(loaded_mesh != null, "Real rigid mesh survived packaging")
	var material := loaded_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.normal_enabled and material.ao_enabled)
	var normal := material.normal_texture.get_image().get_pixel(0, 0)
	assert(absf(normal.r - 0.3) < 0.006 and absf(normal.g - 0.2) < 0.006, "DX green flipped once")
	var orm := material.roughness_texture.get_image().get_pixel(0, 0)
	assert(absf(orm.r - 0.2) < 0.006 and absf(orm.g - 0.4) < 0.006 and absf(orm.b - 0.7) < 0.006,
		"ORM reference pixels: R=AO G=roughness B=metallic: " + str(orm))
	assert(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
	assert(material.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
	assert(material.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED)
	loaded.free()
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	print("test_asset_packer_maps: PASS opaque PNG/normal/ORM round trip")
	await preload("res://tests/support/finish.gd").success(self)
