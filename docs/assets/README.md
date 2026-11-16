# Community asset handoff

Prepared **16 November 2026**, from gameplay baseline `f45e909`. Three parallel agents covered mission features, static asset sourcing and character/animation sourcing; this handoff is the art track. The sourcing agents inspected creator pages and public metadata, without downloading third-party binaries or signing into services. No new community model is inserted into gameplay by this change.

Use the [static shortlist](community-static-shortlist.md) for twelve model/material leads and the [character/animation shortlist](community-characters-animation-shortlist.md) for ten rig/motion options. Each records actual evidence, acquisition gates, fidelity limitations and integration effort. The [intake guide](../plans/asset-import-pipeline.md) describes the current code and insertion contracts; copy the [intake record](intake-record.template.json) when selecting a particular archive.

## First insertion queue

| Order | Candidate | Why this next | Remaining before repository insertion |
|---|---|---|---|
| 1 | [Beretta M9 — emran.bayati](https://sketchfab.com/3d-models/beretta-m9-d1200d9aa28f466484f7d3fdd7724e76) | Realistic rigid-weapon proof; metadata lists 11,761 triangles and five textures, creator describes separate magazine/bullets | Authorized account download, archive licence/creator evidence, actual formats and measured dimensions, cosmetic wrapper/muzzle alignment, SGC/offworld captures and export smoke |
| 2 | [Plastic Crate 02 — Fabi_G / Poly Haven](https://polyhaven.com/a/plastic_crate_02) | Public CC0 industrial dressing pilot; useful for a measured PBR/material workflow | Actual glTF/map inspection, scale and opacity checks, fit to existing attachment; its open sides do not make solid cover |
| 3 | [P90 — Rotuma](https://sketchfab.com/3d-models/p90-82d8b9f1e02b48f9b012698dcfa3352b), then [M249 — AK](https://sketchfab.com/3d-models/m249-light-machine-gun-75cacc16a52640c7adb100d7294da244) | Larger visible upgrade after the wrapper proof; textured real-weapon forms | Inspect maps/parts, first-person clipping, P90 magazine/optic and M249 barrel/feed geometry; preserve weapon authority and stats |
| 4 | [American Soldier Rigged — RedVeil studio](https://sketchfab.com/3d-models/american-soldier-rigged-5b1967e7f83547be8a1c3ae656ab1ad4) | Best first realistic Airman rig to inspect; metadata lists 9,710 triangles and one clip | Archive/bones/rest pose/maps, redistributable idle/walk clips, measured visual adapter and grip; no complete tactical set is cleared |
| 5 | [Stargate SG1 — rossrobotics](https://sketchfab.com/3d-models/stargate-sg1-e2d6167c932e4c16b293d3bb8b6a3165) | High-visibility faction prop after a simple import succeeds | Archive detail and hierarchy unknown; preserve seven-chevron gameplay, horizon/areas/iris. Articulation is a separate proof |

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

Research-only entries stay here. `credits/ATTRIBUTIONS.md` records binaries actually committed to the game, and remains unchanged by this research milestone.
