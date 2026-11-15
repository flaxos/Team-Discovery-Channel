# Third-Party Asset Attributions & Provenance Manifest

Every external 3D model, texture, material, or animation imported into **Team Discovery Channel** is recorded here in accordance with the 7-point provenance and technical gate in [`docs/plans/asset-import-pipeline.md`](../docs/plans/asset-import-pipeline.md).

---

## 1. Generic Tactical & Architectural Assets

| Asset File | Title & Description | Creator | Source URL | License | Dimensions & Attachment | Difficulty |
|---|---|---|---|---|---|---|
| `client/assets/weapons/p90_smg.glb` | Compact Tactical SMG / PDW (`machinegun.glb` from Kenney Weapon Pack) | **Kenney** (`www.kenney.nl`) | https://kenney.nl/assets/weapon-pack (Mirror: `https://github.com/shorepine/kenney/blob/main/3d/weapon/machinegun.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.057m × 0.264m × 0.597m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.02, -0.30)` and D-015 `metallic = 0.0` | `S` |
| `client/assets/weapons/mp5_silenced.glb` | Suppressed Tactical SMG (`uziLongSilencer.glb` from Kenney Weapon Pack) | **Kenney** (`www.kenney.nl`) | https://kenney.nl/assets/weapon-pack (Mirror: `https://github.com/shorepine/kenney/blob/main/3d/weapon/uziLongSilencer.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.073m × 0.333m × 0.628m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.01, -0.36)` and D-015 `metallic = 0.0` | `S` |
| `client/assets/weapons/m9_pistol.glb` | Beretta M9 9mm Tactical Sidearm (`pistol.glb` from Kenney Weapon Pack) | **Kenney** (`www.kenney.nl`) | https://kenney.nl/assets/weapon-pack (Mirror: `https://github.com/shorepine/kenney/blob/main/3d/weapon/pistol.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.057m × 0.230m × 0.295m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.02, -0.18)` and D-015 `metallic = 0.0` | `S` |
| `client/assets/weapons/m249_saw.glb` | M249 SAW Squad Automatic Weapon (receiver, olive 200-round box drum, heat-shielded barrel, folding bipod, fixed stock) | **Team Discovery Channel** (procedural glTF 2.0 binary `.glb` builder) | Repository-authored (`client/assets/weapons/m249_saw.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.130m × 0.270m × 0.920m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.03, -0.62)` and D-015 `metallic = 0.0` | `S` |
| `client/assets/weapons/zat_sidearm.glb` | Goa'uld Zat'nik'tel Sidearm (serpentine S-curve Naquadah bronze body, dorsal spine crest, glowing cyan arc emitter tip) | **Team Discovery Channel** (procedural glTF 2.0 binary `.glb` builder) | Repository-authored (`client/assets/weapons/zat_sidearm.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.064m × 0.192m × 0.365m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.05, -0.20)` and D-015 `metallic = 0.0` | `S` |
| `client/assets/weapons/staff_weapon.glb` | Goa'uld Ma'Tok Staff Weapon (`1.6m` Naquadah bronze polearm, rear counterweight bulb, 4-petal flared almond head with glowing orange plasma core) | **Team Discovery Channel** (procedural glTF 2.0 binary `.glb` builder) | Repository-authored (`client/assets/weapons/staff_weapon.glb`) | [CC0 1.0 Universal](licenses/CC0-1.0.txt) | `0.128m × 0.128m × 1.600m` (`-Z` forward); attached under `WeaponModel/ImportedGLB` with `MuzzlePoint` at `(0, 0.00, -1.05)` and D-015 `metallic = 0.0` | `S` |

### Provenance & Technical Verification (AP-1a & AP-1b)
- **Uploader Rights Confirmation:** Generic firearm `.glb` files created and distributed directly by Kenney Vleugels (`kenney.nl`) under CC0 1.0 Public Domain dedication; Stargate/heavy weapon `.glb` files authored cleanly as binary glTF 2.0 resources under CC0 1.0.
- **Godot 4.4.1 Compatibility:** Self-contained binary glTF 2.0 (`.glb`) loaded via `GLTFDocument` (`importer="keep"` to avoid Godot 4.4.1 headless dummy-renderer EditorFileSystem thumbnail `texture_2d_get` error).
- **Decision D-015 Compliance:** All imported mesh surfaces enforce `metallic = 0.0` so weapons remain readable in missions without sky or reflection probes.

---

## 2. Community Stargate Props & Faction Assets

*(None imported yet. Future community CC-BY Stargate models from Sketchfab / OpenGameArt must be listed in this section with creator name, canonical URL, CC-BY license version, and modifications.)*
