# Third-Party Asset Attributions & Provenance Manifest

Every external 3D model, texture, material, or animation imported into **Team Discovery Channel** is recorded here in accordance with the 7-point provenance and technical gate in [`docs/plans/asset-import-pipeline.md`](../docs/plans/asset-import-pipeline.md).

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
- **Modifications:** Container only. `tools/gltf_to_glb.py` packed the `.gltf`, `.bin` and three JPEG maps into one GLB without re-encoding any data. At runtime the wrapper draws it opaque, replaces the orange colour factor with an olive tint, wires the ARM map's occlusion channel and generates mipmaps; the committed file keeps the source material.
- **Godot 4.4.1:** `importer="keep"` like AP-1a, loaded from `res://` bytes by `RuntimeGLB`; checked in a Linux release export. Khronos glTF-Validator: 0 errors. Review record: [`docs/reviews/2026-11-16-ap1c-plastic-crate.md`](../docs/reviews/2026-11-16-ap1c-plastic-crate.md).

---

## 2. Community Stargate Props & Faction Assets

*(None imported yet. Future community CC-BY Stargate models from Sketchfab / OpenGameArt must be listed in this section with creator name, canonical URL, CC-BY license version, and modifications.)*
