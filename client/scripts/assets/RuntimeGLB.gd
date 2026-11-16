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
