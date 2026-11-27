extends SceneTree
## Automated test suite for Sprint 34: Ha'tak Mothership Exterior Silhouette and Vista Dressing.
## Verifies:
## 1. MothershipExteriorSilhouette instantiation, hierarchy, and dimensions.
## 2. Zero physics colliders or gameplay bodies (verifying hull is strictly background scenery).
## 3. Material sharing with Goa'uld theme palette (basalt, bronze, gold) and emissive glows.
## 4. Bridge observation viewport vista integration and camera occlusion preservation.
## 5. Hangar bay aperture space vista integration.
## 6. Triangle budget and performance compliance for background scenery.

const SILHOUETTE_SCENE := "res://scenes/props/MothershipExteriorSilhouette.tscn"
const VIEWPORT_SCENE := "res://scenes/props/MothershipViewportFrame.tscn"
const HANGAR_VISTA_SCENE := "res://scenes/props/MothershipHangarVista.tscn"


func _init() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	print("Running Sprint 34 Mothership Exterior test suite...")
	test_silhouette_scenery()
	test_viewport_vista_integration()
	test_hangar_vista_integration()
	print("PASS Sprint 34 Mothership exterior: hero silhouette, pure scenery verification, bridge viewport & hangar vista integration")
	quit(0)


func test_silhouette_scenery() -> void:
	var scn: PackedScene = load(SILHOUETTE_SCENE)
	assert(scn != null, "MothershipExteriorSilhouette.tscn must exist and load")

	var ship := scn.instantiate() as Node3D
	assert(ship != null, "MothershipExteriorSilhouette must instantiate as Node3D")
	root.add_child(ship)

	# 1. Scenery verification: NO collision shapes or bodies
	var bodies := ship.find_children("*", "CollisionObject3D", true, false)
	assert(bodies.is_empty(), "Exterior silhouette must have 0 CollisionObject3D nodes (scenery only)")
	var colliders := ship.find_children("*", "CollisionShape3D", true, false)
	assert(colliders.is_empty(), "Exterior silhouette must have 0 CollisionShape3D nodes (scenery only)")

	# 2. Key structural groups
	var pyramid := ship.get_node_or_null("PyramidCore") as Node3D
	assert(pyramid != null, "Must contain PyramidCore group")
	assert(pyramid.has_node("GoldApex"), "PyramidCore must contain GoldApex")
	assert(pyramid.has_node("Capstone"), "PyramidCore must contain glowing Capstone")
	assert(pyramid.has_node("ApexSpire"), "PyramidCore must contain ApexSpire")

	var superstructure := ship.get_node_or_null("OuterSuperstructure") as Node3D
	assert(superstructure != null, "Must contain OuterSuperstructure group")
	assert(superstructure.has_node("ArmForward"), "Must contain ArmForward outrigger")
	assert(superstructure.has_node("ArmPort"), "Must contain ArmPort outrigger")
	assert(superstructure.has_node("ArmStarboard"), "Must contain ArmStarboard outrigger")
	assert(superstructure.has_node("Collars"), "Must contain connecting Collars")
	assert(superstructure.has_node("GliderBays"), "Must contain GliderBays")

	var propulsion := ship.get_node_or_null("Propulsion") as Node3D
	assert(propulsion != null, "Must contain Propulsion group")
	assert(propulsion.has_node("EngineCenter"), "Must contain EngineCenter thruster")
	assert(propulsion.has_node("EnginePort"), "Must contain EnginePort thruster")
	assert(propulsion.has_node("EngineStarboard"), "Must contain EngineStarboard thruster")

	# 3. Material sharing and visual properties
	var meshes := ship.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= 15, "Hero silhouette must contain rich detailed visual elements")

	var triangle_count := 0
	var used_materials: Array[String] = []
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh:
			triangle_count += mi.mesh.get_faces().size() / 3
			var mat: Material = mi.mesh.material
			if mat == null:
				mat = mi.material_override
			if mat:
				var path := mat.resource_path
				if not path.is_empty() and not used_materials.has(path):
					used_materials.append(path)

	print("  Mothership silhouette total triangles: ", triangle_count)
	print("  Shared external materials: ", used_materials)
	assert(triangle_count > 100, "Must have valid mesh geometry")
	assert(triangle_count < 10000, "Background scenery triangle budget must be under 10k triangles")

	# Check material sharing with basalt, bronze, gold
	var shares_palette := false
	for p in used_materials:
		if p.contains("basalt") or p.contains("bronze") or p.contains("gold"):
			shares_palette = true
			break
	assert(shares_palette, "Mothership silhouette must share Goa'uld basalt/bronze/gold theme materials")

	ship.queue_free()


func test_viewport_vista_integration() -> void:
	var vp_scn: PackedScene = load(VIEWPORT_SCENE)
	assert(vp_scn != null, "MothershipViewportFrame.tscn must load")

	var vp := vp_scn.instantiate() as Node3D
	root.add_child(vp)

	# Verify solid occlusion boundary
	var body := vp.get_node_or_null("Structure/Body") as StaticBody3D
	assert(body != null, "Viewport frame must retain solid StaticBody3D boundary")
	assert(body.collision_layer == 1, "Viewport frame must block layer 1 to preserve camera occlusion fade")

	# Verify SpaceVista presence
	var vista := vp.get_node_or_null("SpaceVista") as Node3D
	assert(vista != null, "Viewport frame must contain SpaceVista node")
	assert(vista.has_node("SpaceBackdrop"), "SpaceVista must contain SpaceBackdrop")
	assert(vista.has_node("Nebula"), "SpaceVista must contain Nebula")

	# Check mothership silhouette integration into viewport vista
	var ship_lead := vista.get_node_or_null("EscortMothership") as Node3D
	assert(ship_lead != null, "SpaceVista must contain EscortMothership silhouette framing")

	vp.queue_free()


func test_hangar_vista_integration() -> void:
	var hangar_scn: PackedScene = load(HANGAR_VISTA_SCENE)
	assert(hangar_scn != null, "MothershipHangarVista.tscn must load")

	var hangar_vista := hangar_scn.instantiate() as Node3D
	root.add_child(hangar_vista)

	assert(hangar_vista.has_node("ForceFieldThreshold"), "Hangar vista must contain ForceFieldThreshold")
	assert(hangar_vista.has_node("SpaceBackdrop"), "Hangar vista must contain SpaceBackdrop")
	assert(hangar_vista.has_node("FleetFormation"), "Hangar vista must contain FleetFormation with mothership silhouettes")

	hangar_vista.queue_free()
