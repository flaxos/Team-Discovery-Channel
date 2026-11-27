# Texture and theme import contract

Proposed production contract, 18 November 2026. Use with the [shared workflow](ai-asset-workflow.md) and [slice programme](../plans/asset-vertical-slices.md). Existing AP-1 recipes are proven opaque import examples, not a finished skin/hair/trim pipeline. Preserve source maps and record every conversion.

## Material data

| Input/output | Contract |
|---|---|
| Base colour | sRGB; neutral illumination; no painted specular highlights or AO double-baked into colour. Keep intentional paint, dirt and wear. Preserve alpha when required. |
| Normal | Linear data, tangent-space **OpenGL +Y** at runtime. Record source convention and any green-channel flip. Compare an engraved/cut feature under directional light; never guess from a filename alone. |
| ORM | Linear data; **R = ambient occlusion, G = roughness, B = metallic**. Record source channels and remapping. Smoothness/glossiness needs conversion to roughness, not a rename. Use explicit constant factors for missing maps, with a material proof. |
| Emission | Colour plus documented strength; colour texture in sRGB. Keep emitter details separate from albedo. Ordinary glowing art must not add gameplay lights, triggers or hazard behavior. |
| Opacity | Declare opaque, mask or blend plus cutoff when used. Prefer tested alpha masking for hard cutouts. Check hair/foliage sorting and shadows. No accidental transparency on an opaque crate or metal body. |
| Height/displacement | Optional source/baking input. No new collision, tessellation or displaced navigable surfaces by implication. Record any parallax shader as a separate material feature. |

Use lossless PNG for normal/ORM/masks; choose opaque albedo compression from side-by-side evidence. JPEG has no alpha; Godot supports several image/compression paths with different trade-offs ([image import reference](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_images.html)). Test a one-pixel/channel reference swatch and a normal orientation reference through packing and actual loading. Alpha must survive decoding, packing, runtime and export, not merely exist in the original PNG.

Record shader/material settings as well as images. Packed channels alone do not ensure the loader samples those channels or applies their factors. Refer to Godot’s [standard/ORM materials](https://docs.godotengine.org/en/4.4/tutorials/3d/standard_material_3d.html) for binding and transparency behavior. This project’s overrides require a rendered proof after loading.

## Theme-specific use

| Theme | Intended treatment | Slice evidence |
|---|---|---|
| SGC | Painted industrial panels, concrete, rubber floor/runner, brushed steel, glass and restrained signage; consistent wear at human contact points | Colour and real scale under normal/emergency lighting, gate/control sightline, stairs/lifts, opaque glass frames and camera fade |
| Goa’uld / mothership | Layered stone/metal, patterned gold trim, readable relief, emissive inserts and fabric; separate surface response rather than one yellow shiny material | Existing corridor joins, corners, lintels, large chamber walls, upper/lower ring decks and long-distance trim repeat |
| Uniforms / civilians | Cloth, webbing, skin, hair and boot response separated; role/variant palettes readable in mission darkness | Moving joints, face/hand close-ups, weapon grip, down/revive/drag; no opaque hair-card rectangles |
| Exterior vista | Silhouette and material readability at its actual distance; shared lower-resolution distant surfaces and selective hero detail | View from playable interior at real exposure; no huge unseen texture allocation |

Determine repeat size from a measured slot/UV layout, not from image resolution. Write metres per tile and intended texel density for each material family. Start with a **provisional** 256 px/m background surface and 512 px/m near hero surfaces, then compare at the game camera. Use trims/atlases on bounded UV bands; verify all edges in a tiled wall, a 90° corner, door opening and ceiling/floor join. Respect the Sprint 6 runner, lintel and corner fixes.

No baked symbols/text whose orientation or scale changes across joins. Use separate decals or authored glyph bands for localized details, with controlled depth bias and a measured camera test. Keep imported textures/material presets reusable; do not duplicate a full set per module, room, faction variant or player.

SGC slots can bind a shared `StandardMaterial3D` through `SGCAssetSlot.pbr_material` on the original mesh. Empty assignments fall back to the legacy `texture` property or the style palette. This path preserves the visible mesh bounds and the camera fade. [Sprint 13 material proof](../reviews/2026-11-24-sprint13-sgc-embarkation.md). D-010 modular themes remain cosmetic: materials/visuals cannot change collision, navigation, footprints, sockets or native layout ownership. Do not paint over an enclosure defect or move a wall to fit a trim.

## Provisional runtime budgets

These are starting work-order limits, **not existing engine-enforced thresholds or measured performance guarantees**. Revisit after the first comparable GPU scene on recorded hardware. Source assets can exceed them if a high-quality optimized runtime version is delivered.

| Runtime class | Starting LOD/material target | Texture allocation target |
|---|---|---|
| Held hero weapon | LOD0 ≤60k triangles; ≤4 materials; explicit distant LOD/proxy where useful | Usually 2K set; ≤64 MiB unique decoded textures including mipmaps |
| Humanoid | LOD0 ≤80k, LOD1 ≤30k, LOD2 ≤10k triangles; ≤4 materials; proposed ≤4 weights per vertex | Usually 2K shared body/gear sets; ≤128 MiB unique decoded textures per archetype |
| Prop | Hero ≤20k, repeated background ≤5k LOD0 triangles; usually 1–2 materials | Usually 1K; shared atlases/sets; measure repeated visible instances |
| Architectural surface | Shared trim/tile material; no per-room texture clone | 2K shared sets; explicit repeat scale and scene totals |
| Mothership exterior | Camera-distance LODs/impostor as appropriate; budget from visible silhouette, not fictional ship size | Shared distant sets; 4K only on demonstrably visible hero detail |

A 2K RGBA8 texture with a full mip chain is about 21.3 MiB **before GPU compression**; a small JPEG on disk is not small decoded memory. Capture actual VRAM/CPU memory where available, resident unique maps, draw calls, visible triangles, load hitches and frame time for a repeatable camera path. Compare against the unchanged scene on the same hardware. Nominate target hardware, resolution and frame-time budget in the first slice instead of inventing universal FPS claims. Log exceptions and trade-offs explicitly.

Keep high-resolution originals in local intake. Do not upscale poor sources and call them high fidelity. Allow justified 4K near-camera hero maps after measurements; the old 1024 recipe setting is not a permanent fidelity ceiling. Prefer LODs, correct UV density and sharing before destroying visible detail. The current runtime GLB route bypasses editor-generated LOD/compression settings, so validate the **delivered** LODs and memory in the exported game ([Godot scene formats/import routes](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)).

**Milestone 2 VRAM reduction (retiring the Sprint 7 2K exception):** the MP5SD's two shared texture sets were downscaled from 2K (**117.33 MiB** decoded) to 1K (**29.33 MiB** decoded including mipmaps), bringing all six held weapons down to ~109.33 MiB combined while retaining the 10,669-triangle geometry, D-015 matte treatment, and mipmaps. Original 2K intake records remain archived at [measurements](intake/mp5sd/measurements.json) and [review](../reviews/2026-11-18-sprint7-mp5-intake.md); [Sprint 10 measurements](../reviews/2026-11-23-sprint10-held-weapon-audit.md) document the prior 2K baseline (415 ms cold load; 0.038 ms cached).

## Current gaps and consuming slices

| Gap at baseline `7982e2b` | Required resolution |
|---|---|
| Packer rebuilds rigid MeshInstance3D nodes; skin/animation lost | Sprint 19 adds and proves a separate rig-preserving path. Do not send characters through the opaque rigid recipe. |
| `load_map` converts images to RGB8; recipe can use lossy encoding for data | Sprint 7 proves lossless opaque PNG/normal/ORM delivery and reference channel checks. Alpha preservation remains unresolved and must be added/proved before hair/cards, cutout decals or foliage. MP5SD source alpha was uniformly opaque; it does not prove alpha support. |
| Weapon loader uses the D-015 `metallic = 0` workaround | Sprint 7 records the current appearance; Sprint 13 tests proper light/reflection treatment in a bounded SGC area. Keep source PBR, compare old/new, then adopt reviewed overrides deliberately. Never flatten all source metallic maps to compensate for darkness. |
| Runtime load has a cache/mipmap solution, but no general LOD authoring contract | Sprint 10 confirmed that all six held weapons use LOD0, with shared meshes/materials and full texture mips. Sprint 15 checks the shared resources and total scene cost of repeated armoury props. |
| No complete PBR material-set binding in SGC’s single-texture slot | Resolved in Sprint 13. Mapped walls, floors and supports consume native materials. The original mesh bounds, camera fade and legacy fallback still apply. |
| Credits live outside `client/` | **Resolved in Sprint 7:** generated `asset_credits.tres` and the lobby reader deliver attribution and both full required licences. Clean release export verifies eight model files and exact legal texts. Maintain source/credit synchronization and repeat export proof after relevant changes. |

## Material acceptance checklist

Before calling a material technically integrated: source/licence and map hashes recorded; UV scale and repeat seams measured; channel/normal/alpha reference checks passed; materials shared; mipmaps verified; normal and alarm lighting captured; actual camera fade works on replacement children; clean export loads identical maps; memory/cost recorded. For generated textures also retain the work order, prompt/references and processing record. Owner art acceptance names the viewed captures and remaining defects separately.
