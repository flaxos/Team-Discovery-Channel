# Community asset integration playbook

For any agent (Codex, Gemini/Antigravity, Claude) putting a community 3D asset into the game. Written 16 November 2026 from the first two integrations: the CC0 Poly Haven crate ([AP-1c](../reviews/2026-11-16-ap1c-plastic-crate.md)) and the CC BY 4.0 Beretta M9 ([AP-1d](../reviews/2026-11-16-ap1d-beretta-m9.md)). The [import pipeline guide](../plans/asset-import-pipeline.md) holds the contracts; the [shortlists](README.md) hold the researched candidates. This page is the fast route through both.

**The rule that keeps it fast:** keep each asset in a cosmetic wrapper with its own evidence. Use the existing checkout, following [AGENTS.md](../../AGENTS.md). Group delivery when the owner requests it. Never change gameplay collision, sockets, stats, authority or navigation to fit art; fit the art to them.

For the next asset programme, also read the [shared workflow](ai-asset-workflow.md), [texture contract](texture-import-contract.md) and [sprint sequence](../plans/asset-vertical-slices.md). Historical timing estimates below are examples, not sprint commitments.

**Resume status, 21 November 2026:** Sprint 7's MP5SD and shared intake/exported-credit path are merged to main via #79/#78. [Its review](../reviews/2026-11-18-sprint7-mp5-intake.md) is the latest rigid-weapon worked example: measured +X crown, UV/material pairing, actual work-order intake, lossless maps, memory exception and clean export. Owner art review remains pending. Sprint 8 adds an original textured staff shared by the player and both Jaffa variants after rejecting a geometry-only download. Final animated grips belong to 20/24. **Sprint 9, Zat, is next.** [Sprint 8 evidence](../reviews/2026-11-23-sprint8-staff-intake.md). The queue below includes historical integrations, not a replacement sprint order.

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

Record the exact listing and licence version. If the owner explicitly accepts a documented evidence gap, record the asset, date and decision; this does not establish missing authorship or underlying rights. On 17 November 2026 the owner authorized committing and merging the Stargate SG1 integration with its existing uploader-authorship gap recorded. Sketchfab: `https://api.sketchfab.com/v3/models/<uid>` gives `license.slug`, `isDownloadable` and counts. Licences from modellers never cover manufacturers' trademarks (the M9 carries Beretta's markings); note any and leave the call to the owner.

**Authorized acquisition:** agents may download permitted public assets or use an available authorized account route supported by their tools. An HTTP 401 without a session identifies that route's account requirement, not a universal agent restriction. If owner action is actually needed, provide the [download card](ai-asset-workflow.md#owner-download-card) with the exact asset, format, terms and location. Prefer `~/Downloads` for the original; stage a copy outside `client/`. Do not move, rename, delete or commit the owner's original archive, bypass access controls or purchase without a purchase instruction.

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
| `.dae` (COLLADA), including nested archives | The original [M249 proof](../reviews/2026-11-16-ap1f-m249.md) used a separate staging project. For new work, use a supported converter over external intake data and the existing checkout; do not copy the game project. If an engine import cannot meet those workspace/staging boundaries, report the specific conversion blocker before changing the workflow |
| A clean self-contained `.glb` already | use it; still run the checks below |

Recipe: copy [`intake/beretta_m9/recipe.json`](intake/beretta_m9/recipe.json) to `docs/assets/intake/<id>/recipe.json`. Set `source`, `output` (relative to the recipe), `keep_nodes`, `max_texture_size` (1024 in the original proofs; choose the production resolution using the [texture contract](texture-import-contract.md)), and per-material maps (`"*"` for all). Then:

```sh
godot --headless --path client --import          # refreshes class names in the existing checkout
godot --headless --path client --script res://scripts/assets/pack_model_glb.gd -- docs/assets/intake/<id>/recipe.json
```

**Rigid opaque assets only:** this packer rebuilds static mesh nodes and does not preserve skins, skeletons or animation. Map decoding currently converts to RGB8, so alpha is lost. Add and test a suitable path before skin/hair/cutouts; see the texture contract.

It prints one `PACK_RESULT` line with every kept mesh, its triangles and bounds. Run it first without `keep_nodes` and an output in `/tmp` to see what the source contains. Packing is deterministic, so the same recipe gives the same sha256.

**Normal maps:** Godot uses the OpenGL convention. If unsure, pack with `"normal_convention": "opengl"` and `"directx"`, render both under a light from above, and look at something known to be engraved (stamped text, panel grooves). The right one reads as cut in.

Add `client/assets/<kind>/<id>.glb.import` containing `[remap]`, a blank line and `importer="keep"` (as for every GLB here), so CI's headless editor import does not try to build thumbnails.

## 5. Check it

For Sprint 7 onward, validate the [work order](ai-asset-workflow.md#generation-fallback-with-a-tight-work-order) and pass `--work-order docs/assets/intake/<id>/work-order.json` to `asset_intake.py`. It requires ready measurements/references, records the request/schema hashes and enforces declared mesh/material budgets. Install `tools/requirements.txt` in an environment under ignored `build/` as documented in the shared workflow. Historical imports remain historical; a draft request cannot authorize a new GLB intake.

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
2. **Captures** (display needed, Forward+): `weapon_visual_review.gd -- --mission sgc_uat --weapon <id>` and `--mission goauld_infiltration`, or `crate_visual_review.gd` for props. Capture the original too: use the helper’s fallback/original-view mode in the same checkout; do not create another worktree. Commit 4–5 PNGs to `docs/reviews/<milestone>-captures/`.
3. **Cost.** Print the first-load and repeat-load time, and the triangles added in a typical view (`CRATE_COST` shows how). Do not try runtime `ImporterMesh.generate_lods`; it did not finish on a 5,840-triangle mesh in 4.4.1.
4. **Exported build.** Work in the existing checkout; do not make another project copy. Save any existing `client/export_presets.cfg`, temporarily install the preset below and a small `client/tests/support/export_smoke.gd` that builds your wrapper and checks the result. Write outputs under ignored `build/asset-review/export-smoke/`. Restore the exact previous preset (or remove only the temporary one) and remove the temporary smoke script in a `finally` block. Never commit either temporary file. Then:

   ```sh
   godot --headless --path client --import
   godot --headless --path client --export-pack LinuxSmoke ../build/asset-review/export-smoke/x.pck
   cp ~/.local/share/godot/export_templates/4.4.1.stable/linux_release.x86_64 build/asset-review/export-smoke/x.x86_64
   build/asset-review/export-smoke/x.x86_64 --headless --main-pack build/asset-review/export-smoke/x.pck -s res://tests/support/export_smoke.gd
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
   export_path="../build/asset-review/export-smoke/x.x86_64"

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
- Open a draft PR when review is requested. When the owner explicitly asks to commit and merge, finish the merge after checks without another confirmation, then update the existing checkout to `main`. Report local and hosted results separately (`gh pr checks <n>`).

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
| Hosted `Godot full` or `Godot multiplayer` fails in `test_gate_*_multiplayer` after the suite printed PASS, on `Node not found: "…/Players/<peer>/MultiplayerSynchronizer"` | Pre-existing teardown race on `main` (hosted runs 43819943281 on #61 and 43818024196 on CO-1, 16 November 2026), not caused by asset work. Re-run the job once, say so in the PR, and do not chase it inside an asset PR |
| A stacked PR shows as merged but its work is not on `main` | A PR merges into its base branch. GitHub retargets it to `main` only after the base PR merges **and** its branch is deleted. Merge the base PR, check the stacked PR's base says `main` (or change it), then merge. This happened to #64 |
| Work vanishes after a conflict was resolved on GitHub | The #63 merge on top of CO-1 dropped the crate hook from `ArmoryResupplyStation.gd`. After any merge that needed conflict resolution, run the asset's suite on the new `main` |
| CC BY credit missing from a shipped build | Sprint 7 adds generated `client/resources/asset_credits.tres` and the lobby credit/licence reader. Run `python3 tools/sync_asset_credits.py` after changing the maintained manifest/licences and `--check` before export; repeat the clean PCK credit test. Model acquisition/art acceptance is separate |

## 10. Workspace and concurrent work

Use the user's existing checkout. Do not create additional worktrees, clones, sibling project directories or project copies without an explicit request. Keep per-asset code and evidence separate inside the repository; stage raw intake under the established `/tmp/tdc-asset-intake/<id>/` area. Reuse ignored `build/` for generated review artifacts. Share `/tmp/tdc-godot-network-tests.lock` for full runs and anything that hosts a game. Preserve the owner's downloads and unrelated existing edits. [AGENTS.md](../../AGENTS.md) governs delivery and overrides older worktree/draft-only handoff text.

## 11. Next in the queue

| Asset | Route | Needs from the owner | Notes |
|---|---|---|---|
| [P90 — Rotuma](https://sketchfab.com/3d-models/p90-82d8b9f1e02b48f9b012698dcfa3352b) | Weapon, replaces the Kenney `p90_smg.glb` | **Integrated in AP-1e** | 38,083 triangles, 1024² maps, bore aligned to `(0, 0.02, -0.30)`, opaque magazine ([record](../reviews/2026-11-16-ap1e-p90.md)) |
| [M249 — AK](https://sketchfab.com/3d-models/m249-light-machine-gun-75cacc16a52640c7adb100d7294da244) | Weapon `m249` (procedural today) | **Integrated in AP-1f** | 13,328 triangles; nested COLLADA route; fused extended bipod retained; measured bore aligned ([record](../reviews/2026-11-16-ap1f-m249.md)) |
| [Metal Plate — Poly Haven](https://polyhaven.com/a/metal_plate) | Material on SGC map slots | none (CC0, public) | Texture route of `SGCMap` slots; measure repeat scale |
| [Stargate SG1 — rossrobotics](https://sketchfab.com/3d-models/stargate-sg1-e2d6167c932e4c16b293d3bb8b6a3165) | Rigid shell over `StargateRing` | **Integrated AP-1g; owner authorized 17 November 2026** | Imported glyph ring/seven anchored inserts; source body cannot fit aperture and envelope together. [Record](../reviews/2026-11-16-ap1g-stargate.md). Articulation remains separate |
