# Sprint 11 — M2 defensive position

The community M2 by **emran.bayati** replaces the procedural gun and base on the east and west SGC positions, the SG‑3 Heavy deployment, and the general’s automated sentry. The imported gun turns on the existing head and the tripod remains fixed. The shield uses two original panels and a bracket around the barrel path. Owner art review is open. [Creator listing](https://sketchfab.com/3d-models/browning-m2-381c0f1939e843ceae232500e24e7231).

| View | Baseline | Imported M2 |
|---|---|---|
| Deployed in SGC | [Diagnostic camera](sprint11-captures/deployed-baseline.png) | [Diagnostic camera](sprint11-captures/deployed-m2.png) |
| Mounted in SGC | [Player camera](sprint11-captures/mounted-baseline.png) | [Player camera](sprint11-captures/mounted-m2.png) |

## Intake and fit

The owner supplied the original `browning-m2.zip`. The archive contains an FBX and 16 image files. The creator’s listing and metadata identify CC BY 4.0. The downloaded files contain no separate terms. The original is retained in Downloads and the prepared model is included in the distributed credits. [Archive evidence](../assets/intake/m2/archive-evidence.json) · [Attribution](../../credits/ATTRIBUTIONS.md).

The source puts the tripod and some gun fittings in the same material primitive. The preparation script splits connected parts and preserves their UVs, normals and materials. It drops the showroom plinth and loose ammunition props. The two surfaces use 1K colour, normal and packed ORM sets. Intake flips the normal green channel for the Godot convention, and the renderer uses the project’s matte weapon finish. The tripod is fitted vertically to support the existing head height. [Packing recipe](../assets/intake/m2/recipe.json) · [Preparation tool](../../tools/prepare_m2_visual.mjs) · [Ready work order](../assets/intake/m2/work-order.json).

| Runtime evidence | Result |
|---|---|
| Triangles | 42,313 moving gun and fittings, 7,276 fixed tripod |
| Unique materials and textures | Two materials share six mipmapped images across every turret instance |
| Decoded mip-chain data | 29.33 MiB per process |
| Construction timing samples | 159.3 ms cold and 0.068 ms cached in the headless checkout |
| Rest fit in turret coordinates | Approximately 0.92 × 1.12 × 1.95 m |
| Existing game alignment | Bore within 3 mm of the shot marker at rest and when aimed. Fixed base, 1.8 m interaction cylinder and 2.4 m mount search reach |
| glTF validation | Zero errors or warnings |

The captured stock player camera and the existing procedural operative can obscure parts of the deployed model. The deployed diagnostic view shows the fitted gun, tripod and shield under the same mission lights. [Original baseline measurements](../assets/intake/m2/baseline.json) · [Fitted measurements and pack hash](../assets/intake/m2/fit.json) · [Validator report](../assets/intake/m2/gltf-validator.json).

## Session behavior

Before the change, late joiners saw the authored west turret at rest while the server showed an occupant and aim. The turret scene now replicates the occupant path and aim from the server. SG‑3 deployment uses a mission-owned spawner and the existing ready-peer filter. Player mount and aim requests resolve against the server’s operative and current turret. Hits run on the server through the existing shot marker. Shot effects travel through the ready mission world so a loading player can join even if a deployed turret is firing. Retry creates a fresh deployment container.

The local SGC fixture uses the existing deployment and interact actions, aims, fires from the live shot marker and dismounts. The Airman and general’s sentry cases use existing fixtures. The new four-player listen and dedicated cases deploy and mount from a remote SG‑3 player, fire on the server, let a replacement join during gate travel, and check that the new peer sees the mounted M2 and that retry clears it. Strict full verification is tracked on the delivery PR.

The clean 39,071,616-byte Linux release pack passed the fitted visual test and credits check for eleven models and both full licences. A second release export excluded the M2 file and passed the placeholder fallback check. [Intake report](../assets/intake/m2/intake-report.json).

## Reproduce the prepared model

Stage the checked archive under `/tmp/tdc-asset-intake/m2/extracted` as recorded in the recipe. Run the tools from this checkout.

```sh
npm install --prefix build/sprint11-node-tools --no-audit --no-fund @gltf-transform/core@4.3.0 @gltf-transform/functions@4.3.0
godot --headless --path client --script res://scripts/assets/pack_model_glb.gd -- docs/assets/intake/m2/recipe.json
node tools/prepare_m2_visual.mjs /tmp/tdc-asset-intake/m2/inspect-materials.glb build/browning_m2.glb build/sprint11-node-tools
godot --headless --path client --script res://tests/test_imported_m2_visual.gd
```

Sprint 12 covers the existing C4, claymore, smoke and shield field kit. [Sprint programme](../plans/asset-vertical-slices.md).
