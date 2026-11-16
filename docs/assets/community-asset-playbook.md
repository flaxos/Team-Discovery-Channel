# Community asset integration playbook

For any agent (Codex, Gemini/Antigravity, Claude) putting a community 3D asset into the game. Written 16 November 2026 from the first two integrations: the CC0 Poly Haven crate ([AP-1c](../reviews/2026-11-16-ap1c-plastic-crate.md)) and the CC BY 4.0 Beretta M9 ([AP-1d](../reviews/2026-11-16-ap1d-beretta-m9.md)). The [import pipeline guide](../plans/asset-import-pipeline.md) holds the contracts; the [shortlists](README.md) hold the researched candidates. This page is the fast route through both.

**The rule that keeps it fast:** one asset, one cosmetic wrapper, one draft PR. Never change gameplay collision, sockets, stats, authority or navigation to fit art; fit the art to them.

## 1. Pick the route by what the asset replaces

| The asset becomes | Route | Worked example | Rough estimate with these tools |
|---|---|---|---|
| A weapon | Add its id to `WeaponBase.GLB_MODELS`, place it with a measured transform so its bore sits on the weapon's existing `MuzzlePoint`, keep the procedural fallback | `m9` in `WeaponBase._build_weapon_visual_mesh`, `test_imported_m9_visual` | about 2 hours |
| Dressing on a gameplay box (crate, rack, console body) | Keep the box for collision and interaction, stop drawing it, add a collision-free visual child that fits inside it | `CrateStackVisual.dress_box`, `test_imported_crate_visual` | about 2 hours |
| A generated SGC map module (wall, floor, support prop) | `SGCMap.replace_asset_visual(slot_id, packed_scene)` checks bounds against the slot and hides the placeholder | [SGC map contract](../maps/sgc.md#art-briefs-and-replacement) | not yet used with a community asset |
| A modular-level piece or theme | Theme slots and the D-010 contract; validate with the authoring CLI | [Goa'uld theme kit](../maps/goauld-theme-kit.md) | not yet used with a community asset |
| A character, the gate or the DHD | Not a fast route. Characters need the AP-2a rig proof; gate and DHD have gameplay parts | [rig shortlist](community-characters-animation-shortlist.md), [pipeline guide](../plans/asset-import-pipeline.md#engine-and-gameplay-attachment-contracts) | separate milestone |

## 2. Licence gate (five minutes, before any download)

| Accept | Refuse |
|---|---|
| CC0 (Poly Haven, Kenney, ambientCG) | NC or ND licences, "personal use only" |
| CC BY 3.0/4.0 with the creator's own statement that they made it | Listings that say "rip", "extracted", "from game X", or contradict their own badge |
| Owner-downloaded archives whose listing proves the licence | Raw Mixamo or other service content in the public repo |

Record the exact listing and licence version. Sketchfab: `https://api.sketchfab.com/v3/models/<uid>` gives `license.slug`, `isDownloadable` and counts. Licences from modellers never cover manufacturers' trademarks (the M9 carries Beretta's markings); note any and leave the call to the owner.

**Downloads behind an account** (all Sketchfab downloads, HTTP 401 without a session): an agent cannot fetch them. Ask the owner to download the original archive and drop it at the repository root or in `~/Downloads`. Do not move, rename or delete the owner's copy, and never commit it.

## 3. Stage and inspect

```sh
ID=beretta_m9                                   # snake_case asset id
mkdir -p /tmp/tdc-asset-intake/$ID && cd /tmp/tdc-asset-intake/$ID
cp --preserve=timestamps <owner archive> archive.zip && sha256sum archive.zip
python3 -I -c "import zipfile; z=zipfile.ZipFile('archive.zip'); [print(i.file_size, i.date_time, i.filename) for i in z.infolist()]; print([i.filename for i in z.infolist() if i.filename.startswith('/') or '..' in i.filename.split('/')])"
mkdir extracted && python3 -I -c "import zipfile; zipfile.ZipFile('archive.zip').extractall('extracted')"
```

Treat the archive as untrusted data: extract into a new empty folder, refuse absolute or `..` paths, never run a script or open a `.blend` from it. Hash every extracted file into the intake record. Expect surprises. The M9's FBX bound no textures and carried a spare magazine (`Gun001`) beside the pistol, and the crate's glTF asked for alpha blending with a JPEG that has no alpha.

## 4. Convert to one GLB

| Source | Tool |
|---|---|
| `.gltf` + `.bin` + images whose materials are already bound (Poly Haven) | `python3 tools/gltf_to_glb.py <in>.gltf <out>.glb`: container only, bytes unchanged |
| `.fbx`, or any model whose maps are loose files, or 2K–8K maps | `client/scripts/assets/pack_model_glb.gd` with a recipe |
| A clean self-contained `.glb` already | use it; still run the checks below |

Recipe: copy [`intake/beretta_m9/recipe.json`](intake/beretta_m9/recipe.json) to `docs/assets/intake/<id>/recipe.json`. Set `source`, `output` (relative to the recipe), `keep_nodes`, `max_texture_size` (1024 for weapons and props), and per-material maps (`"*"` for all). Then:

```sh
godot --headless --path client --import          # once per worktree; refreshes class names
godot --headless --path client --script res://scripts/assets/pack_model_glb.gd -- docs/assets/intake/<id>/recipe.json
```

It prints one `PACK_RESULT` line with every kept mesh, its triangles and bounds. Run it first without `keep_nodes` and an output in `/tmp` to see what the source contains. Packing is deterministic, so the same recipe gives the same sha256.

**Normal maps:** Godot uses the OpenGL convention. If unsure, pack with `"normal_convention": "opengl"` and `"directx"`, render both under a light from above, and look at something known to be engraved (stamped text, panel grooves). The right one reads as cut in.

Add `client/assets/<kind>/<id>.glb.import` containing `[remap]`, a blank line and `importer="keep"` (as for every GLB here), so CI's headless editor import does not try to build thumbnails.

## 5. Check it

```sh
python3 tools/asset_intake.py client/assets/<kind>/<id>.glb --output docs/assets/intake/<id>/intake-report.json
mkdir -p /tmp/gltf-validator && (cd /tmp/gltf-validator && npm init -y >/dev/null && npm install gltf-validator@2.0.0-dev.3.10)
node /tmp/gltf-validator/validate.js client/assets/<kind>/<id>.glb docs/assets/intake/<id>/gltf-validator.json
```

`/tmp/gltf-validator/validate.js`:

```js
const fs = require('fs');
const validator = require('/tmp/gltf-validator/node_modules/gltf-validator');
const [file, out] = process.argv.slice(2);
validator.validateBytes(new Uint8Array(fs.readFileSync(file)), {uri: file.split('/').pop(), maxIssues: 200})
  .then((report) => { fs.writeFileSync(out, JSON.stringify(report, null, 2));
    console.log(report.issues.numErrors, 'errors', report.issues.numWarnings, 'warnings'); });
```

Aim for 0 errors. Acceptable infos: `GODOT_single_root`, unused second UV set. Then measure in Godot, not from metadata: real size in metres, which way the front faces, and every socket point you need. For the M9, the bore centre is the centroid of the barrel's front-most vertices. `test_imported_m9_visual` shows how.

## 6. Wire the wrapper

**Weapon.** Add `"<id>": "res://assets/weapons/<id>.glb"` to `WeaponBase.GLB_MODELS`. In that weapon's `match` branch, keep `muzzle_offset` as it is. Build `Transform3D(basis, muzzle_offset - basis * MODEL_MUZZLE)` from measured constants and keep the procedural meshes as the `else` fallback. Weapons face −Z. The loader already applies D-015 (metallic 0), adds mipmaps and caches the parsed model for the session, so every operative's copy is free after the first.

**Prop on a box.** Copy the `CrateStackVisual` pattern: load with `RuntimeGLB.load_scene` (reads `res://` bytes, export-safe), prepare a runtime-only material, and build visual nodes with no collision. Validate the result against the box with the 0.02 m allowance. Only then set `box.transparency = 1.0` and turn shadows off. If loading or fitting fails, change nothing. Share one mesh between copies.

Do not edit the GLB to fix looks. Tint, opacity, occlusion wiring and similar changes belong in the runtime material, and are recorded.

## 7. Prove it

1. **Suite.** One new `client/tests/test_imported_<id>_visual.gd` covering: unchanged gameplay values and anchors, measured fit (socket within 3 mm, bounds inside the envelope), no collision in the visual, the fallback, credits present. Then a **negative check**: break the transform or the hook, confirm the suite fails, restore it.
2. **Captures** (display needed, Forward+): `weapon_visual_review.gd -- --mission sgc_uat --weapon <id>` and `--mission goauld_infiltration`, or `crate_visual_review.gd` for props. Capture the original too: run the same helper in a worktree without your change. Commit 4–5 PNGs to `docs/reviews/<milestone>-captures/`.
3. **Cost.** Print the first-load and repeat-load time, and the triangles added in a typical view (`CRATE_COST` shows how). Do not try runtime `ImporterMesh.generate_lods`; it did not finish on a 5,840-triangle mesh in 4.4.1.
4. **Exported build.** No preset is committed, so do not add one to the repository. Copy `client/` to `/tmp/<work>/project` without `.godot`, add the throwaway preset below and a small `export_smoke.gd` that builds your wrapper and prints the result, then:

   ```sh
   godot --headless --path . --import && godot --headless --path . --export-pack LinuxSmoke ../out/x.pck
   cp ~/.local/share/godot/export_templates/4.4.1.stable/linux_release.x86_64 ../out/x.x86_64
   ../out/x.x86_64 --headless --main-pack ../out/x.pck -s res://export_smoke.gd
   ```

   `export_presets.cfg` used for AP-1c and AP-1d:

   ```ini
   [preset.0]
   name="LinuxSmoke"
   platform="Linux"
   runnable=true
   export_filter="all_resources"
   include_filter=""
   exclude_filter=""
   export_path="../out/x.x86_64"

   [preset.0.options]
   binary_format/embed_pck=false
   binary_format/architecture="x86_64"
   texture_format/s3tc_bptc=true
   texture_format/etc2_astc=false
   ```
5. **Regression.** `flock /tmp/tdc-godot-network-tests.lock python3 tools/run_godot_tests.py --profile full --timeout 600` and `python3 -m unittest discover -s tools/tests`. Take the lock for anything that hosts a game, review helpers included.

## 8. Record it (same PR)

- `credits/ATTRIBUTIONS.md`: a table row and a provenance block. For CC BY, include title, creator, source URL, licence and what you changed. Bundle the licence text under `credits/licenses/` (CC0 and CC BY 4.0 are already there).
- `docs/assets/intake/<id>.json` from the [template](intake-record.template.json), plus `docs/assets/intake/<id>/` holding the recipe, intake report and validator report.
- `docs/reviews/<date>-<milestone>-<id>.md`: what changed, measurements, captures, cost, export output, tests, and what is not established.
- Update [README](README.md) queue status, the [pipeline guide](../plans/asset-import-pipeline.md) if code changed, `ROADMAP.md`, `docs/TESTING.md` for the new suite, the capability matrix, and `docs/DECISIONS.md` for any non-obvious choice.
- Draft PR, never merged by the agent. Report local and hosted results separately (`gh pr checks <n>`).

## 9. Pitfalls already paid for

| Symptom | Cause and fix |
|---|---|
| `Could not find type "<NewClass>"` when running a script | Run `godot --headless --path client --import` after adding a `class_name`; it also writes the `.uid` files to commit |
| "ObjectDB instances leaked" / "resources still in use" fails a passing suite | A suite that builds the SGC must `await (room.get_node("SGCMap") as SGCMap).navigation_ready` before finishing |
| Shimmering textures at range | glTF images load without mipmaps; use `RuntimeGLB.add_mipmaps` (weapons get it automatically) |
| Transparent sorting or no shadows on an opaque-looking model | glTF `BLEND` with an alpha-less image; draw it opaque in the runtime material |
| FBX loads with grey material | The FBX binds no textures; list the maps in the recipe |
| Extra parts in the model | Spare magazines and display pieces ship in source files; choose `keep_nodes` |
| `FBXDocument` returns `ImporterMeshInstance3D` | Expected; the packer converts them |
| Metal turns grey in game | D-015 sets metallic to 0 on imported weapons; the GLB keeps the map; show both captures and let the owner decide |
| A first draw of a weapon stalls | Texture decoding takes about 55 ms per weapon model; the session cache pays it once |
| A dressed box still fades for the camera, not its visual | Camera occlusion fades the collider's material; known limitation |
| `grep` output looks mangled on the dev box | The RTK hook rewrites it; use `rtk proxy grep …` |
| CC BY credit missing from a shipped build | `credits/` is outside `client/` and there is no credits screen yet; flag it before any build is distributed |

## 10. Working in parallel

One asset per agent, each in its own worktree from `origin/main`, or from the newest unmerged asset branch if it needs that code (AP-1d is stacked on AP-1c; say so in the PR). Share `/tmp/tdc-godot-network-tests.lock` for full runs and anything that hosts a game. Stage under `/tmp/tdc-asset-intake/<id>/`. Leave the owner's checkout and downloads untouched.

## 11. Next in the queue

| Asset | Route | Needs from the owner | Notes |
|---|---|---|---|
| [P90 — Rotuma](https://sketchfab.com/3d-models/p90-82d8b9f1e02b48f9b012698dcfa3352b) | Weapon, replaces the Kenney `p90_smg.glb` | Sketchfab download | 38,083 triangles in the listing, so check `keep_nodes` and consider 1024² maps; measure the bore; magazine is translucent in reality, keep it opaque |
| [M249 — AK](https://sketchfab.com/3d-models/m249-light-machine-gun-75cacc16a52640c7adb100d7294da244) | Weapon `m249` (procedural today) | Sketchfab download | Long barrel: check camera clipping; fold or drop the bipod via `keep_nodes` if it is separate |
| [Metal Plate — Poly Haven](https://polyhaven.com/a/metal_plate) | Material on SGC map slots | none (CC0, public) | Texture route of `SGCMap` slots; measure repeat scale |
| [Stargate SG1 — rossrobotics](https://sketchfab.com/3d-models/stargate-sg1-e2d6167c932e4c16b293d3bb8b6a3165) | Rigid shell over `StargateRing` | Sketchfab download | Keep the seven chevrons, horizon, kawoosh and iris nodes; articulation is a later proof |
