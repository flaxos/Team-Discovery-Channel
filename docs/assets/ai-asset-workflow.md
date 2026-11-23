# Shared AI asset workflow

Planning baseline **18 November 2026, main `7982e2b` (Sprint 6 / PR #77)**. Updated **23 November 2026** after Sprints 7–9 merged the MP5SD, shared staff and original Zat. [Sprint 10’s six-weapon audit](../reviews/2026-11-23-sprint10-held-weapon-audit.md) records current art and texture costs for owner review. **Sprint 11’s M2 integration is ready for review.** [Sprint 11 review](../reviews/2026-11-23-sprint11-m2-intake.md). This workflow applies to Codex, Claude and Gemini/Antigravity. The owner confirmed **Horus Jaffa** and a **Goa’uld mothership**.

Use the [vertical-slice sprint programme](../plans/asset-vertical-slices.md) to execute one slice at a time. Follow [AGENTS.md](../../AGENTS.md), the [integration playbook](community-asset-playbook.md) and [texture contract](texture-import-contract.md). Work in the supplied checkout. Raw intake goes under `/tmp/tdc-asset-intake/<id>/`; generated captures and reports go under ignored `build/`. Do not create a worktree, clone or project copy. Keep the owner’s downloads intact.

## Learn from the previous imports

An agent’s conversation memory is not the integration specification. Read the repository evidence, reproduce its measurements and carry forward the useful parts of the Claude-era workflow.

| Worked example | Read and reuse | Lesson / limitation |
|---|---|---|
| [M9 review](../reviews/2026-11-16-ap1d-beretta-m9.md), [recipe](intake/beretta_m9/recipe.json), [intake](intake/beretta_m9.json) | Source selection, node filtering, normal-map comparison, measured muzzle alignment, cache timing, export proof | Keep the seated magazine, exclude the spare; a good source may have no bound textures. Align to the actual muzzle, not its thumbnail. Hands are still a later rig dependency. |
| [P90 review](../reviews/2026-11-16-ap1e-p90.md), [intake](intake/p90.json) | Real-world size, wrapper transform, SGC/offworld comparison | Preserve the existing realistic P90; the old Kenney stand-in is not an upgrade. |
| [M249 review](../reviews/2026-11-16-ap1f-m249.md), [intake](intake/m249.json) | Nested COLLADA intake, map rebinding, vertex-colour correction | Fused extended bipod is an explicit remaining art issue. Source format conversion does not justify changing the weapon controller. Historical staging instructions do not authorize new project copies. |
| [Sprint 7 MP5SD review](../reviews/2026-11-18-sprint7-mp5-intake.md), [recipe](intake/mp5sd/recipe.json), [work order](intake/mp5sd/work-order.json), [verification](intake/mp5sd/verification.json) | Actual ready-request intake, source-map pairing, independent crown/bounds, lossless 2K maps, four-player replicas and exported credits | Source +X and material names differ from earlier guns; measure instead of copying. Two sets use 117.33 MiB decoded under a recorded 128 MiB exception. Sprint 10 measured the LOD0 and cache costs. Grips and animation remain later work. |
| [Sprint 8 shared staff review](../reviews/2026-11-23-sprint8-staff-intake.md), [work order](intake/staff/work-order.json) | Evaluate a downloaded STL and record the source rejection, then author distinct mesh and maps from measured fit | Reuse one model cache on the player and both NPC variants. Independently align their existing emitters and exercise each fallback. |
| [Sprint 9 Zat review](../reviews/2026-11-23-sprint9-zat-visual.md), [work order](intake/zat/work-order.json) | Compare creator evidence and author a textured fallback when provenance fails | Verify quiet incapacitation and real sidearm delivery during travel. |
| [Sprint 10 held-weapon audit](../reviews/2026-11-23-sprint10-held-weapon-audit.md) | Measure live surfaces, unique mip chains and shared resources across all six player weapons | Use the real class slots, include the downed view and check the same resources in a clean export. |
| [Crate review](../reviews/2026-11-16-ap1c-plastic-crate.md) | Bounds-checked collision-free dressing; opaque material correction | Repeating a detailed crate adds about 385k triangles across the two armoury stacks. Measure total scene cost, not just one mesh. |
| [Gate review](../reviews/2026-11-16-ap1g-stargate.md) | Adapt selected source subparts to seven live chevrons and the real aperture | Source body/nine-chevron layout was omitted. The owner’s recorded authorship-evidence exception applies to that asset only. |

Inspect `client/scripts/weapons/WeaponBase.gd`, `client/scripts/assets/RuntimeGLB.gd`, `client/scripts/assets/pack_model_glb.gd` and the corresponding `test_imported_*_visual` suites before changing them. Copy the **method**, then measure the new asset; do not copy a transform, licence assertion or passing test result blindly.

The old mixed SW-1 commit `e72ff28cbd11380ad2e15d9509b3eb250fe5fee7` contains committed AP-1b stand-ins and later chamber work. Inspect existing commits/files before rebuilding those pieces. Sprint 6 recovered only the corridor work. Preserve the dirty original checkout and its uncommitted mission/theme work; do not reset, clean or commit it as part of this programme. Stylized AP-1b weapons are recovery candidates, not accepted high-fidelity replacements.

## One sprint, one playable result

At sprint start, read the named entry and its prerequisites, check current Git state, then produce a short slice brief in the existing plans/review locations. Record the exact scene, visible assets, existing interaction, maximum asset count, measured bounds, current defects and acceptance views. Discover live map capabilities with `python3 tools/level_authoring.py catalogue --summary` before selecting modules or slots; follow the [authoring guide](../maps/ai-level-authoring.md). Native `.tres` layouts remain authoritative.

The loop is **source → inspect → prepare → attach → play → export → record**. Each enabling tool or adapter must be consumed by that sprint’s real scene. A model gallery, a source shortlist or an idle-only preview cannot substitute for the specified gameplay slice. If sourcing blocks a required hero asset, complete independent preparation and report the exact blocker; do not silently downgrade fidelity or mark the slice complete.

Start from the preceding merged slice when available; preserve local edits. Do not begin another sprint automatically. At delivery, update the sprint row, evidence and roadmap. When explicitly asked to commit and merge, follow AGENTS.md through the merge and finish on updated `main`; otherwise provide the reviewable change/PR requested by the current task. Human art acceptance remains a separate recorded state even after merge.

## Community-first acquisition

1. Audit existing assets, owner downloads and prior imports before searching. Search exact creator listings and public provider APIs; record at least the strongest candidates and why they fit or fail. Use the [sourcing register](asset-program-sourcing.md) as dated leads, not approvals.
2. Prefer a faithful, well-textured community model over a quick generated approximation. Score silhouette, close-up fidelity, usable PBR maps, topology/UVs, movable subparts, rig and animation compatibility, scene cost and provenance. Keep source quality and runtime optimization as separate questions.
3. Apply the playbook’s licence gate before importing binaries. Confirm creator, exact licence, archive terms, modification and public-source redistribution rights. A marketplace badge or “free download” is insufficient when terms conflict. Retain full required licence text, source links, hashes and modifications. Owner approval of one documented exception is not blanket clearance for other assets.
4. Agents may download permitted public assets through supported authorized routes. Use an available authorized account session if its tools and terms permit it. Never ask for passwords or bypass an account/paywall. If the actual route needs the owner, issue the concrete card below and continue independent work. Do not assume every account download is technically impossible.
5. Paid or custom-commissioned assets are proposals until the owner selects a purchase. Do not buy on the owner’s behalf. Confirm public-repository redistribution before recommending purchase; game-use permission alone may not permit committing raw assets.

### Owner download card

Use one card per actual blocker, in the sprint review:

```text
Asset / sprint / role:
Exact creator listing and creator:
Observed licence + archive/redistribution evidence still needed:
Why selected / rejected alternatives / fidelity limitations:
Download format, texture resolution, required archive components:
Cost / account requirement / supported download route attempted:
Suggested owner location: ~/Downloads/<original archive name>
Agent staging copy: /tmp/tdc-asset-intake/<id>/
Unblocked work to continue:
```

Inspect archive members for unsafe paths before extraction into a new staging folder; do not execute downloaded add-ons/scripts. Preserve the untouched original archive locally. Commit prepared runtime assets and provenance, not owner-download archives.

## Generation fallback with a tight work order

If the community search leaves a documented gap, Gemini/Antigravity can author the missing material, decal, trim or model using a work order conforming to [asset-work-order.schema.json](asset-work-order.schema.json). [Rigid example](asset-work-order-rigid.example.json) and [material example](asset-work-order-material.example.json) are **draft requests**, not shipped assets. The schema constrains requests; it does not certify copyright, image quality, geometry or engine acceptance. Sprint 7 adds `tools/asset_work_order.py` and `asset_intake.py --work-order` for this validation. The acquired MP5SD now consumes a ready request through this path; technical checks and owner art acceptance remain distinct. See the [Sprint 7 review](../reviews/2026-11-18-sprint7-mp5-intake.md).

Record generator/tool/version and the full prompt, reference provenance, output hashes and post-processing. Set the measured target frame, bounds, anchors, maps, resolution, palette, repeat scale, geometry/rig budget and deliverables **before generation**. Do not invent dimensions or a skeleton to satisfy the form. A draft may name unresolved measurements; `ready_for_intake` requires those requests to be resolved and the generation tool identified for a generated gap.

The work order uses metres and the target visual parent’s local frame for bounds and anchors. Schema checks reject unknown fields, incompatible asset kinds, wrong runtime channels/conventions, unresolved ready requests and path traversal. Also verify the real scene/branch exists, bounds min/max and anchor positions are physically correct, LOD limits decrease, texture/triangle budgets fit the scene, profile/rest-pose files resolve and required clips actually play. JSON structure cannot prove those facts. A ready request starts intake; it never approves an asset.

Install the pinned tooling dependency in the existing ignored build area, then use the shared CLI:

```sh
python3 -m venv build/asset-tools-venv
build/asset-tools-venv/bin/python -m pip install -r tools/requirements.txt
build/asset-tools-venv/bin/python tools/asset_work_order.py docs/assets/intake/<id>/work-order.json
build/asset-tools-venv/bin/python tools/asset_work_order.py docs/assets/intake/<id>/work-order.json --require-ready
build/asset-tools-venv/bin/python tools/asset_intake.py <prepared.glb> --work-order docs/assets/intake/<id>/work-order.json --output build/asset-intake/<id>.json
```

Draft validation permits unresolved measurements; actual GLB intake requires a ready request and records its hash. Passing it is still not licence or engine/art acceptance. Runtime triangle counts, material references and measured transforms require their separate checks. Legacy intake without this flag retains its original inspection behavior.

Use Gemini image generation for actual image outputs: concept sheets, masks, decals or albedo candidates. Google documents an [image generation interface](https://ai.google.dev/gemini-api/docs/image-generation); an image response is not a rigged GLB. A generated concept requires a separate modelling/retopology/UV/rig/bake step through tools actually available. If Antigravity authors a Blender script, run it in an isolated data-processing session with the same schema and validate the resulting file. Never claim a generated picture supplies measured normals, roughness or watertight geometry.

Require flat, neutral albedo without baked highlights/shadows; build or bake coherent normal/roughness/AO data from geometry/material work. Test tiling, trim bands, physical scale and readability in-engine. No invented readable insignia, copied creator textures, fake licensing or photoreal celebrity faces as an unreviewed shortcut. Prefer a documented generic operator face and recognizable uniform/gear silhouette unless the owner supplies an appropriate face asset.

## Packaging routes and attachment boundaries

| Asset kind | Route and boundary |
|---|---|
| Opaque rigid weapon/prop | Existing recipe packer or container-only `gltf_to_glb.py`, then self-contained GLB inspection and full validator. Measure final transformed bounds. Preserve root/controller/collision and muzzle/interaction anchors. |
| Alpha, PBR material, trim sheet | Follow the texture contract. Current packer converts maps to RGB8 and can discard alpha; add the needed path inside the first consuming slice before using it for hair, grilles or decals. |
| Rigged character / skeletal animation | **Do not use the current rigid packer**: it rebuilds static mesh nodes and loses skin/skeleton/animation data. Choose and prove a skin-preserving export/import route, rest pose, BoneMap, clips, materials and exported loading in Sprint 19. |
| Articulated gate/weapon prop | Retain named animated parts or use separate rigid subparts under a cosmetic adapter. Flattening cannot retain articulation. Drive visuals from existing state; do not invent an animation API. |
| Modular theme / SGC slot | Discover actual slots, use collision-free visual children, respect measured bounds, sockets/enclosure/navigation and camera-occlusion fading. `SGCAssetSlot.texture` is one Texture2D, not a complete PBR binding interface. |

Keep `CharacterBody3D`, health, camera, synchronizers, weapon stats, fire origins and authority unchanged. Existing typed procedural `BodyMesh`/`ArmorMesh`, crouch/down/death transforms and `StaffMount` cannot simply become skeleton nodes. Put an adapter under the visual branch; disable conflicting procedural transforms only for that branch, retain the fallback and derive animation from replicated state. Cosmetic hand attachments/IK must follow authoritative muzzle aim, not move the gameplay muzzle to hide a bad grip. Locomotion remains in place; root motion never owns network movement.

## Evidence and completion

For each asset, maintain distinct **sourcing**, **technical integration** and **owner art acceptance** fields in its sprint review/coverage ledger. Suggested values: research / download required / intake / integrated / blocked; checks pending / passed with exact command and commit; art pending / changes requested / accepted with date and views. Imported is not synonymous with accepted. Update actual counts only after measuring.

Required review evidence:

- Exact source/archive hashes, licence and attribution, recipe/tool versions, output hash, modifications, original maps and selected nodes. Generated outputs include work order, prompt and generation provenance.
- Bounds/axes/anchor and material/triangle/texture/LOD reports; cold-load and repeated-instance measurements. Budgets are provisional targets from the texture contract until validated on the actual scene.
- Real GPU captures: neutral material proof, actual normal/emergency SGC and offworld lighting, close combat camera and distant view. Include moving/animated evidence for a rig or articulation, not just a still.
- Relevant gameplay checks: aim/fire/reload, NPC combat, interaction prompts, doors/lifts/occlusion or objective route. Check the existing view modes; do not promise a new first-person mode as part of art.
- Four-operative listen and dedicated sessions, late join into the relevant current state, join during gate travel where applicable, after return and after retry. Retain authority/state snapshots and clean strict logs. A cosmetic NPC needs no new gameplay replication if animation is derived locally from existing replicated state.
- Clean exported build proof from this checkout, raw runtime asset inclusion, required credits/licence delivery and visual fallback on missing/failed asset. No dependency on staging paths or the editor import cache.

Use `python3 tools/asset_intake.py <prepared.glb> --output build/asset-intake/<id>.json` for its actual supported inspection; run a full glTF validator as well. Run targeted behavioral checks during work and `python3 tools/run_godot_tests.py --profile full --timeout 240` at slice completion, with the shared `/tmp/tdc-godot-network-tests.lock` for anything that hosts a game. Use the established runner/TESTING.md lock procedure and report hosted checks separately. Do not add tests that only restate a filename or implementation; test alignment, skin preservation, packaging, state transitions or other actual failure risks.

Sprite/image generation success, schema validation and headless passing tests do not establish subjective fidelity. Give the owner concrete views to accept; if art is pending, say so. No slice is called “all weapons finished” until the six held weapons, mounted/deployed kit, full playable grip matrix and accepted visual evidence are accounted for.
