# Community asset handoff

Prepared **16 November 2026**, from gameplay baseline `f45e909`. Three parallel agents covered mission features, static asset sourcing and character/animation sourcing; this handoff is the art track. The sourcing agents inspected creator pages and public metadata, without downloading third-party binaries or signing into services. No new community model is inserted into gameplay by this change.

**AP-1c status (16 November 2026).** The first insertion is the Poly Haven crate, now dressing the SGC armoury ammo crates: [review record](../reviews/2026-11-16-ap1c-plastic-crate.md), [intake record](intake/plastic_crate_02.json). The M9 was not acquired: Sketchfab's download endpoint answered HTTP 401 without an account session, so an authorised account download is the remaining blocker for it.

**AP-1d status (16 November 2026).** With the owner's account download, the Beretta M9 now replaces the procedural sidearm: [review record](../reviews/2026-11-16-ap1d-beretta-m9.md), [intake record](intake/beretta_m9.json). Its FBX was converted in the engine by the recipe-driven packer. The [integration playbook](community-asset-playbook.md) distils both proofs into the fastest safe route for the next asset.

**AP-1e status (16 November 2026).** With the owner's account download, the FN P90 by Rotuma now replaces the stylized Kenney asset: [review record](../reviews/2026-11-16-ap1e-p90.md), [intake record](intake/p90.json). Converted from FBX with `pack_model_glb.gd`, bore aligned to unchanged `MuzzlePoint`, real size (500.5 mm), SGC and offworld captures, and Linux export smoke verified.

Use the [static shortlist](community-static-shortlist.md) for twelve model/material leads and the [character/animation shortlist](community-characters-animation-shortlist.md) for ten rig/motion options. Each records actual evidence, acquisition gates, fidelity limitations and integration effort. The [intake guide](../plans/asset-import-pipeline.md) describes the current code and insertion contracts; copy the [intake record](intake-record.template.json) when selecting a particular archive.

**AP-1f status (16 November 2026).** The owner-downloaded M249 SAW by AK / skaf13 now replaces the procedural heavy weapon. Its nested COLLADA archive is converted through an isolated Godot staging project; the bore, weapon values and fallback are preserved. [Review](../reviews/2026-11-16-ap1f-m249.md), [intake](intake/m249.json). The fused bipod remains extended; owner art review is pending.

**AP-1g integration (owner authorized 17 November 2026).** Imported glyph ring and seven source chevron inserts now fit the existing gate aperture and anchors. The original body/nine-chevron layout is omitted to preserve the current envelope. The owner authorized inclusion with the missing uploader-authorship evidence documented; independent authorship remains unverified. [Review](../reviews/2026-11-16-ap1g-stargate.md), [intake](intake/stargate_sg1.json).

## First insertion queue

| Order | Candidate | Why this next | Remaining before repository insertion |
|---|---|---|---|
| 1 | [Beretta M9 — emran.bayati](https://sketchfab.com/3d-models/beretta-m9-d1200d9aa28f466484f7d3fdd7724e76) | Realistic rigid-weapon proof; metadata lists 11,761 triangles and five textures, creator describes separate magazine/bullets | **Integrated in AP-1d, owner art review pending.** Owner-downloaded archive, CC BY 4.0, converted from FBX with `pack_model_glb.gd`, bore aligned to the unchanged `MuzzlePoint`, SGC and offworld captures, exported build checked ([record](../reviews/2026-11-16-ap1d-beretta-m9.md)) |
| 2 | [Plastic Crate 02 — Fabi_G / Poly Haven](https://polyhaven.com/a/plastic_crate_02) | Public CC0 industrial dressing pilot; useful for a measured PBR/material workflow | **Integrated in AP-1c, owner art review pending.** Measured, validated and dressing the two SGC armoury ammo crates as a 3 × 3 × 4 stack inside their unchanged collision boxes ([record](../reviews/2026-11-16-ap1c-plastic-crate.md)). No LODs yet: two stacks add about 385,000 triangles in the armoury |
| 3 | [P90 — Rotuma](https://sketchfab.com/3d-models/p90-82d8b9f1e02b48f9b012698dcfa3352b) | Primary tactical weapon upgrade; textured real-weapon form | **Integrated in AP-1e, owner art review pending.** Owner-downloaded archive, CC BY 4.0, 38,083 triangles, bore aligned to unchanged `MuzzlePoint`, SGC and offworld captures, exported build checked ([record](../reviews/2026-11-16-ap1e-p90.md)) |
| 3b | [M249 — AK](https://sketchfab.com/3d-models/m249-light-machine-gun-75cacc16a52640c7adb100d7294da244) | Heavy machine gun upgrade (currently procedural) | **Integrated in AP-1f, owner art review pending.** 13,328 triangles, 1024² maps, measured bore aligned to unchanged muzzle; extended fused bipod ([record](../reviews/2026-11-16-ap1f-m249.md)) |
| 4 | [American Soldier Rigged — RedVeil studio](https://sketchfab.com/3d-models/american-soldier-rigged-5b1967e7f83547be8a1c3ae656ab1ad4) | Best first realistic Airman rig to inspect; metadata lists 9,710 triangles and one clip | Archive/bones/rest pose/maps, redistributable idle/walk clips, measured visual adapter and grip; no complete tactical set is cleared |
| 5 | [Stargate SG1 — rossrobotics](https://sketchfab.com/3d-models/stargate-sg1-e2d6167c932e4c16b293d3bb8b6a3165) | High-visibility faction prop after a simple import succeeds | **Integrated AP-1g; owner authorized 17 November 2026 with the authorship-evidence gap documented.** Measured glyph ring and seven copied chevron inserts fit existing anchors; source body/nine-chevron arrangement omitted. Gameplay, horizon/areas/iris preserved. [Record](../reviews/2026-11-16-ap1g-stargate.md) |

These are ranked research recommendations, not assets approved by an import or human visual test. Source/license evidence and current details are in the companion documents.

## Known gaps

No complete high-fidelity Jaffa body/rig, high-fidelity Zat, verified retracting SG-1 iris, detailed DHD or Goa'uld trim-sheet set was established. Some fallback candidates exist but should not be described as a hi-fi solution.

Raw Mixamo redistribution and contradictory Quaternius archive/website licences need explicit acquisition-level evidence. A source may permit game use while preventing raw public-repository distribution. The shortlists state the exact evidence and uncertainty; do not replace those findings with a blanket “royalty-free” claim.

The current checked-in Kenney weapons are stylized, textureless stand-ins: the inspector reports **486** and **838** declared unique-mesh triangles for the game-labelled P90 and MP5 respectively, with no embedded images. The former SW-1 branch's additional stylized weapon models are a separate recovery item. Preserve their actual attribution instead of renaming them as faithful high-fidelity firearms.

## Ready-to-run handoff

1. Pick **one** candidate and copy `intake-record.template.json`. Fill the exact source, creator and licence evidence from its row. Obtain the archive through its normal authorized route and keep the original outside `client/`.
2. Run `python3 tools/asset_intake.py /tmp/tdc-asset-intake/<candidate>/model.glb --output build/asset-intake/<candidate>.json`. Record its hash. The report identifies declarations and self-contained data, not legal or engine acceptance.
3. Run full format validation and measure the model in Godot 4.4.1. Complete the target-specific wrapper contract in the guide. Record what was changed and which source files/maps were used.
4. Commit one cosmetic proof, its credits/licence and evidence together. Verify unchanged gameplay collision, sockets and authority, clean exported loading, mission lighting, multiplayer/late join and the required test profile. Open a draft PR for owner art review.

Research-only entries stay here. `credits/ATTRIBUTIONS.md` records binaries actually committed to the game; the crate is its first community-sourced entry after the AP-1a Kenney weapons.

A Poly Haven or other `.gltf` download with separate files can be packed for intake without re-encoding: `python3 tools/gltf_to_glb.py <staged>.gltf <staged>.glb`.
