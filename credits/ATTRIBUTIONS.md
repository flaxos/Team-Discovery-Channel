# Third-Party Asset Attributions & Provenance Manifest

Every external 3D model, texture, material, or animation imported into **Team Discovery Channel** is recorded here in accordance with the 7-point provenance and technical gate in [`docs/plans/asset-import-pipeline.md`](../docs/plans/asset-import-pipeline.md).

The lobby’s **Community Credits & Licences** window displays an exportable resource generated from this manifest and `credits/licenses/`. After a change, run `python3 tools/sync_asset_credits.py`; CI checks it with `--check`. Keep this file and the original licence texts authoritative; do not hand-edit `client/resources/asset_credits.tres`. Sprint 7 restored the complete official [CC0 legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt), including its formerly omitted definitions and limitations.

---

## 1. Generic Tactical & Architectural Assets

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/weapons/p90_smg.glb` | Compact Tactical SMG / PDW (`machinegun.glb` from Kenney Weapon Pack) | **Kenney** (`www.kenney.nl`) | https://kenney.nl/assets/weapon-pack (Mirror: `https://github.com/shorepine/kenney/blob/main/3d/weapon/machinegun.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.057m × 0.264m × 0.597m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.02, -0.32)` and D-015 `metallic = 0.0` | `S` |
| `client/assets/weapons/mp5_silenced.glb` | Suppressed Tactical SMG (`uziLongSilencer.glb` from Kenney Weapon Pack) | **Kenney** (`www.kenney.nl`) | https://kenney.nl/assets/weapon-pack (Mirror: `https://github.com/shorepine/kenney/blob/main/3d/weapon/uziLongSilencer.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.073m × 0.333m × 0.628m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.01, -0.36)` and D-015 `metallic = 0.0` | `S` |

### Provenance & Technical Verification (AP-1a)
- **Uploader Rights Confirmation:** Created and distributed directly by Kenney Vleugels (`kenney.nl`) under CC0 1.0 Public Domain dedication.
- **Godot 4.4.1 Compatibility:** Self-contained binary glTF 2.0 (`.glb`) loaded via `GLTFDocument` (`importer="keep"` to avoid Godot 4.4.1 headless dummy-renderer EditorFileSystem thumbnail `texture_2d_get` error).
- **Decision D-015 Compliance:** All imported mesh surfaces enforce `metallic = 0.0` so weapons remain readable in missions without sky or reflection probes.

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/props/plastic_crate_02_1k.glb` | Plastic Crate 02, 1k glTF: rugged stackable plastic crate with vented sides | **Fabi_G** for **Poly Haven** | https://polyhaven.com/a/plastic_crate_02 | [CC0 1.0 Universal](licenses/CC0-1.0.txt) ([Poly Haven licence](https://polyhaven.com/license)) | `0.506m × 0.254m × 0.406m`, origin bottom centre; a 3 × 3 × 4 stack at scale 0.984 dresses the SGC armoury ammo crates (`CrateStackVisual`, D-018) | `S` |

### Provenance & Technical Verification (AP-1c)
- **Source and rights:** Published by Poly Haven, whose licence page states that every asset is by its staff or an artist who donated or sold it directly to Poly Haven, under CC0. The asset's info record names Fabi_G as sole author (`donated: true`). Checked 16 November 2026.
- **Files:** Downloaded from the public `gltf/1k` listing; each file matched the listing's md5 and size. Hashes and the full intake record: [`docs/assets/intake/plastic_crate_02.json`](../docs/assets/intake/plastic_crate_02.json).
- **Modifications:** `tools/gltf_to_glb.py` packed the `.gltf`, `.bin` and three JPEG maps into one GLB without re-encoding. The wrapper draws it opaque, uses an olive tint, wires the ARM map's occlusion channel and generates mipmaps. Sprint 15 derived two lower-detail index buffers for `plastic_crate_02_lods.res`, using the source geometry and the same runtime material.
- **Godot 4.4.1:** `importer="keep"` like AP-1a, loaded from `res://` bytes by `RuntimeGLB`; checked in a Linux release export. Khronos glTF-Validator: 0 errors. Review record: [`docs/reviews/2026-11-16-ap1c-plastic-crate.md`](../docs/reviews/2026-11-16-ap1c-plastic-crate.md).

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/props/worn_metal_rack.glb` | Worn Metal Rack, painted steel shelving | **Luca B** for **Poly Haven** | https://polyhaven.com/a/worn_metal_rack | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.915 × 1.900 × 0.600 m` before uniform 0.83 scale. Fitted within the SGC Level 28 re-armour station. | `S` |

- **Source and rights:** Poly Haven lists Luca B as sole author and records the asset as donated. Its public listing and licence cover modification and redistribution. [Provider licence](https://polyhaven.com/license) · [Source and hashes](../docs/assets/intake/worn_metal_rack/source.json).
- **Modifications:** Repacked the geometry and the 1K colour, OpenGL normal and ORM maps into a self-contained GLB. The prepared maps encode the decoded provider inputs as PNG. The SGC station centres and uniformly scales the shelf, generates mipmaps and reduces the metallic factor for the existing indoor lighting. [Recipe](../docs/assets/intake/worn_metal_rack/recipe.json).

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/weapons/beretta_m9.glb` | "Beretta M9" — textured handgun with a separate magazine | **emran.bayati** (https://sketchfab.com/emran.bayati) | https://sketchfab.com/3d-models/beretta-m9-d1200d9aa28f466484f7d3fdd7724e76 | [CC BY 4.0](licenses/CC-BY-4.0.txt) (https://creativecommons.org/licenses/by/4.0/) | `0.217m × 0.142m × 0.032m`, real size; turned from model `-X` to `-Z` under `WeaponModel/ImportedGLB` so its bore sits on the unchanged `MuzzlePoint` `(0, 0.02, -0.18)`; D-015 `metallic = 0.0` at runtime | `S` |

### Provenance & Technical Verification (AP-1d)
- **Attribution (CC BY 4.0):** "Beretta M9" by emran.bayati, https://sketchfab.com/3d-models/beretta-m9-d1200d9aa28f466484f7d3fdd7724e76, licensed under CC BY 4.0. Modified as described below.
- **Source and rights:** The creator's description says they modelled and textured it and shares it as a free download; the Sketchfab API reported `license.slug = "by"` (CC BY 4.0) and `isDownloadable: true` on 16 November 2026. The archive (`beretta-m9.zip`, sha256 `17c2fc99…04b1ee`) was downloaded by the owner through a Sketchfab account and contains the creator's original-format files (an FBX and five 4096² maps) dated 23 April 2020, the publication date. It contains no licence file; the listing is the licence evidence. Intake record: [`docs/assets/intake/beretta_m9.json`](../docs/assets/intake/beretta_m9.json).
- **Modifications:** Converted from FBX to GLB with `client/scripts/assets/pack_model_glb.gd` and the recipe in `docs/assets/intake/beretta_m9/`. Kept the gun and its seated magazine, dropped the spare magazine laid beside it and the empty animation take. Bound the five maps (the FBX names none), downscaled them from 4096² to 1024², packed occlusion, roughness and metallic into one ORM image, and stored all three images as JPEG (quality 0.9). Geometry, UVs and units are the creator's. At runtime the game sets metallic to 0 (D-015) and generates mipmaps.
- **Trademarks:** The model reproduces Beretta's grip medallion and slide markings. The CC BY grant covers the modeller's copyright, not the manufacturer's trademarks.

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/weapons/p90.glb` | "P90" — realistic textured FN P90 bullpup personal defense weapon | **Rotuma** (https://sketchfab.com/Rotuma) | https://sketchfab.com/3d-models/p90-82d8b9f1e02b48f9b012698dcfa3352b | [CC BY 4.0](licenses/CC-BY-4.0.txt) (https://creativecommons.org/licenses/by/4.0/) | `0.068m × 0.212m × 0.500m`, real size; faces `-Z` under `WeaponModel/ImportedGLB` with bore aligned to unchanged `MuzzlePoint` `(0, 0.02, -0.30)`; D-015 `metallic = 0.0` at runtime | `S` |

### Provenance & Technical Verification (AP-1e)
- **Attribution (CC BY 4.0):** "P90" by Rotuma, https://sketchfab.com/3d-models/p90-82d8b9f1e02b48f9b012698dcfa3352b, licensed under CC BY 4.0. Modified as described below.
- **Source and rights:** The creator's description details Maya modeling, Substance Painter texturing, and Krita graphics; the Sketchfab API confirmed `license.slug = "by"` (CC BY 4.0), `isDownloadable: true`, and 38,083 triangles on 16 November 2026. The archive (`p90.zip`, sha256 `4f80c77614e744e57c6fde9d5dcc06fa23aeed673979ada7855d43002aea96a9`) was downloaded by the owner through their Sketchfab account and contains `source/P90.fbx` and five 4096² maps plus opacity map. Intake record: [`docs/assets/intake/p90.json`](../docs/assets/intake/p90.json).
- **Modifications:** Converted from FBX to GLB with `client/scripts/assets/pack_model_glb.gd` and the recipe in `docs/assets/intake/p90/`. Kept the single `P90` mesh (38,083 triangles), bound albedo, normal (OpenGL), roughness, and metallic maps downscaled to 1024², packed roughness and metallic into glTF ORM, and exported as JPEG (quality 0.9). Kept the magazine opaque at runtime as instructed. Scaled by 0.02847984 in the game wrapper to match real-world dimensions (500.5 mm length). At runtime the game sets metallic to 0 (D-015) and generates mipmaps.
- **Trademarks:** The model reproduces FN Herstal P90 form factor and weapon markings. The CC BY grant covers the modeller's copyright, not the manufacturer's trademarks.

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/weapons/m249.glb` | "M249 light machine gun" — textured SAW with optic and extended bipod | **AK / skaf13** | https://sketchfab.com/3d-models/m249-light-machine-gun-75cacc16a52640c7adb100d7294da244 | [CC BY 4.0](licenses/CC-BY-4.0.txt) | `0.467m × 0.501m × 0.963m`; measured bore aligned to unchanged `MuzzlePoint` `(0, 0.03, -0.62)`; D-015 at runtime | `S` |

### Provenance & Technical Verification (AP-1f)
- **Attribution:** "M249 light machine gun" by AK (skaf13), https://sketchfab.com/3d-models/m249-light-machine-gun-75cacc16a52640c7adb100d7294da244, CC BY 4.0. Modified as below.
- **Source and rights:** The creator states they modelled it in Blender and textured it in Substance Painter following Darrin Lile's course. The Sketchfab API confirms CC BY 4.0 and downloadable status. Owner download `~/Downloads/m249-light-machine-gun.zip`, preserved in place; the archive contains `source/model.zip`, a COLLADA scene and textures, with no separate licence. Listing and hashes: [intake record](../docs/assets/intake/m249.json).
- **Modifications:** Imported COLLADA in an isolated Godot staging project, then recipe-packed `M249_low` to GLB. Bound albedo, OpenGL normal, roughness, metallic and AO; downscaled to 1024², packed ORM, JPEG quality 0.9. Geometry and UVs retained, including fused extended bipod. Runtime wrapper rotates -X to -Z, scales by 0.001, aligns the measured crown, ignores source part-ID vertex colours, generates mipmaps and applies metallic 0 (D-015). No reload or bipod animation added.
- **Trademarks:** The licence covers the artist's model, not manufacturer trademarks.

---

### MP5SD — Sprint 7

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/weapons/mp5sd.glb` | MP5SD (Silenced MP5), iron-sight gun body | **WillyG99** | https://sketchfab.com/3d-models/mp5sd-silenced-mp5-2b96ccb2dc51496e93f41734663bcadf | [CC BY 4.0](licenses/CC-BY-4.0.txt) | Measured visual size about `0.051 × 0.245 × 0.692 m`; source +X rotated to game -Z, crown on unchanged `MuzzlePoint (0, 0.01, -0.36)` | `S` |

- **Attribution:** "MP5SD (Silenced MP5)" by WillyG99, source above, CC BY 4.0.
- **Source and rights:** Creator describes their Blender/Gimp/Substance modelling and texturing workflow. Sketchfab metadata confirms CC BY 4.0 and downloadable status. Owner supplied `mp5sd-silenced-mp5.zip`; original retained in Downloads. Archive contains FBX and maps, no separate licence or contradictory terms. [Source hashes and intake](../docs/assets/intake/mp5sd/source-hashes.json).
- **Modifications:** Recipe-packed the 10,669-triangle gun body from FBX, omitting the separate optional red-dot sight (1,416 triangles). Rebound the two source material sets by inspected UV/render correspondence, reduced 4K maps to 2K, converted labelled DirectX normals to OpenGL, and packed AO/roughness/metallic into ORM. All embedded maps use lossless PNG; unused opaque alpha discarded. Geometry and UVs retained. Runtime wrapper uses measured scale/orientation/crown alignment, mipmaps and the existing D-015 metallic-zero override. No reload or optic animation added. The older Kenney file remains packaged and credited.
- **Trademarks:** The artist’s licence covers the model; manufacturer markings are retained as source art.

### Deployable Browning M2

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/weapons/browning_m2.glb` | Browning M2 | **emran.bayati** | https://sketchfab.com/3d-models/browning-m2-381c0f1939e843ceae232500e24e7231 | [CC BY 4.0](licenses/CC-BY-4.0.txt) | Gun and stationary tripod fitted to DeployableTurret | M |

- **Modifications:** Excluded the presentation plinth and loose ammo props. Separated the tripod by connected mesh parts, fitted both visual branches to the game scene, downsized maps to 1K, flipped normal green, and packed AO, roughness and metallic. The game applies its matte treatment. The split shield is original project art.
- **Source evidence:** [Archive hashes and creator licence evidence](../docs/assets/intake/m2/archive-evidence.json).

### Smoke canister

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/props/field_kit_smoke.glb` | Smoke Grenade | **Roman Berezyak** | https://sketchfab.com/3d-models/smoke-grenade-d61768fbc7494143bb87852c36d1beaa | [CC BY 4.0](licenses/CC-BY-4.0.txt) | Canister visual fitted to the existing smoke prop | S |

- **Modifications:** Packed the exterior FBX with reduced 1K colour and OpenGL normal maps and a packed AO, roughness and metallic image. Fitted the exterior to the original visual anchor and applied the game’s matte finish.
- **Source evidence:** [Archive and licence evidence](../docs/assets/intake/field-kit/smoke-archive.json).

### C4 satchel exterior

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/props/field_kit_c4.glb` | Simple Old C4 | **Blender3D** | https://sketchfab.com/3d-models/simple-old-c4-43d3b6a933b04aea8006d790627f9555 | [CC BY 4.0](licenses/CC-BY-4.0.txt) | Exterior mesh fitted inside the existing satchel silhouette | S |

- **Modifications:** Reoriented the OBJ exterior and packed the baked 1K colour, normal and AO/roughness maps. The game uses its existing light and anchor. The source specular and emissive maps were omitted.
- **Source evidence:** [Archive and licence evidence](../docs/assets/intake/field-kit/c4-archive.json).

## 2. Community Stargate Props & Faction Assets

| Asset file | Title | Uploader | Source | Licence | Use |
|---|---|---|---|---|---|
| `client/assets/props/stargate_sg1.glb` | Stargate SG1 | **rossrobotics** | https://sketchfab.com/3d-models/stargate-sg1-e2d6167c932e4c16b293d3bb8b6a3165 | [CC BY 4.0](licenses/CC-BY-4.0.txt), per listing | Imported glyph ring plus seven chevron inserts on existing anchors |

### Provenance and owner-authorized integration (AP-1g)
- **Attribution:** "Stargate SG1" uploaded by rossrobotics, source above, listed under CC BY 4.0. Modified as below. The listing has no authorship description and the archive has no licence/readme; uploader authorship is **not established**. On 17 November 2026 the owner authorized committing and merging this integration with the gap documented. That authorization does not independently establish uploader authorship.
- **Acquisition:** Existing owner download `~/Downloads/stargate.zip`, copied to staging outside `client/`, original preserved. Full hashes and listing evidence: [intake](../docs/assets/intake/stargate_sg1.json).
- **Changes:** Recipe-packed FBX into a GLB with the glyph ring and one front/back chevron/light insert. Albedo and metallic maps downscaled 4096² to 1024², chevron roughness bound, ORM packed, JPEG quality 0.9. Bump maps are height maps, not verified tangent-space normals, and are omitted. The runtime wrapper fits the ring to the existing 2.75 m opening, repeats the insert at the seven existing anchors, uses unlit albedo for housings, drives front/back emissive inserts from existing replicated chevron count, generates mipmaps and draws opaque with metallic 0. Source body, frames and nine-chevron arrangement are omitted because they cannot fit both existing aperture and envelope unchanged. No ring spinning, chevron movement or iris art added.
- **Underlying rights:** This is a community fan model; the listing licence does not grant Stargate franchise rights.

### Tri-vane plasma staff — Sprint 8

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/weapons/tri_vane_staff.glb` | Tri-vane plasma staff | Team Discovery Channel project | [Staff visual authoring tool](https://github.com/flaxos/Team-Discovery-Channel/blob/main/tools/author_staff_visual.py) | Original project asset | Shared by Teal’c, Jaffa Guard and Jaffa Shock Guard using the existing muzzle anchors | M |

- **Changes:** Original geometry and four baked maps authored from the project's runtime envelope, with no downloaded model or texture inputs. Cached copies use the existing weapon finish and mipmap handling.

### Loop-frame ion sidearm — Sprint 9

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/weapons/loop_frame_zat.glb` | Loop-frame ion sidearm | Team Discovery Channel project | [Sidearm visual authoring tool](https://github.com/flaxos/Team-Discovery-Channel/blob/main/tools/author_zat_visual.py) | Original project asset | Zat visual for Carter and Teal’c, aligned to the existing emitter and effects | M |

- **Changes:** Original swept frame, paired dielectric rails and four lossless maps. The game uses its existing material finish, mipmapped textures and shared visual cache.

### SGC embarkation materials — Sprint 13

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/resources/materials/sgc/embarkation_wall.tres` | Concrete | Rob Tuytel for Poly Haven | https://polyhaven.com/a/concrete | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | Cast wall and panel surfaces with a 4 m repeat | S |
| `client/resources/materials/sgc/embarkation_floor.tres` | Smooth Concrete Floor | Dimitrios Savva for Poly Haven | https://polyhaven.com/a/smooth_concrete_floor | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | Gate chamber and approach floors with a 2 m repeat | S |
| `client/resources/materials/sgc/embarkation_steel.tres` | Metal Plate | Rob Tuytel for Poly Haven | https://polyhaven.com/a/metal_plate | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | Ramp, platform, overhead supports and side stair rails with a 0.5 m repeat | S |

- **Source and rights:** Poly Haven lists the three artist-contributed sets under [CC0](https://polyhaven.com/license). The official file manifest provided the map URLs and checksums. [Source and prepared map hashes](../docs/assets/intake/sgc-embarkation.json).
- **Changes:** The 1K diffuse JPEGs retain their source bytes. The OpenGL normal and packed AO, roughness and metallic maps use 8-bit lossless PNGs. Native Godot materials add colour tint, normal strength, mipmaps and measured repeat scales.

### SGC lab equipment — Sprint 16

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/props/industrial_microscope.glb` | Industrial Microscope | Lukas Walzer for Poly Haven | https://polyhaven.com/a/industrial_microscope | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | East research bench, Level 28 SGC laboratory | S |

- **Source and rights:** Poly Haven records Lukas Walzer as the sole creator and identifies the work as donated under [CC0](https://polyhaven.com/license). The public 1K glTF components matched the provider's sizes and checksums. [Intake source manifest](../docs/assets/intake/industrial_microscope/source.json).
- **Changes:** Omitted the loose cable and recipe-packed the body with PNG colour, OpenGL normal and ORM maps. The runtime wrapper rotates and centres the unchanged instrument geometry, generates mipmaps and lowers the metallic factor for the SGC lighting. [Preparation recipe](../docs/assets/intake/industrial_microscope/recipe.json).

### SGC briefing and command wood — Sprint 17

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/resources/materials/sgc/briefing_wood.tres` | Wood Table 001 | Dimitrios Savva and Rico Cilliers for Poly Haven | https://polyhaven.com/a/wood_table_001 | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | Shared varnished wood finish on the briefing table and command desk | S |

- **Changes:** Preserved the provider’s 1K diffuse JPEG and converted the 16-bit OpenGL normal and packed ARM maps to 8-bit RGB PNG. The standard material uses a 1.5 m triplanar repeat, mipmaps and a restrained tint. [Source and prepared hashes](../docs/assets/intake/sprint17-briefing-wood.json).

### SGC service cabinet steel — Sprint 18

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/resources/materials/sgc/service_cabinet_steel.tres` | Metal Plate, matte cabinet finish | Rob Tuytel for Poly Haven | https://polyhaven.com/a/metal_plate | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | Existing Level 26 service cabinet mesh | S |

- **Changes:** Reuses Sprint 13's colour, normal and packed surface maps. The cabinet material uses a cooler tint, lower reflectivity and constant matte roughness. [Source and prepared map hashes](../docs/assets/intake/sgc-embarkation.json).

### SGC security CRTs — Sprint 18

| Asset file | Title | Creator | Source | Licence | Integration | Effort |
|---|---|---|---|---|---|---|
| `client/assets/props/sprint18_television.glb` | Television 02 | Benny Weimer for Poly Haven | https://polyhaven.com/a/television_02 | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | Four displays in the existing Level 27 CCTV bank | S |

- **Changes:** Packed 1K colour, OpenGL normal and ARM channels as RGB PNGs. Godot shares the mipmapped material and mesh across four CRTs, scales them uniformly and turns the glass toward the aisle. The existing console drives the local selected-feed label. [Source and prepared hashes](../docs/assets/intake/sprint18-television/source.json).
