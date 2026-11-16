class_name RuntimeGLB
extends RefCounted
## Loads a self-contained .glb kept raw in the project (`importer="keep"`) at runtime.
##
## The bytes are read from the res:// path itself, so the same call works from the source
## folder and from inside an exported .pck (checked with the 4.4.1 Linux release template).
## It does not depend on ProjectSettings.globalize_path(), which returns a relative path in
## an exported build that only resolves because FileAccess also searches the pack.


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
