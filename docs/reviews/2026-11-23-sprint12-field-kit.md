# Sprint 12 — Field kit

Sprint 12 starts from the merged M2 at `264c7fd`. The four prop exteriors are integrated in the current checkout. Carried gear uses the existing inventory and HUD counts. The close views below use SGC UAT lighting and a diagnostic camera.

| Gear | Supported game states | Art and evidence |
|---|---|---|
| C4 satchel | Remote and timed variants share the shell. The existing light shows arming, then the game plays the effect and removes the prop. | 4,592-triangle exterior by Blender3D. [Placed](sprint12-captures/satchel.png) · [Armed](sprint12-captures/satchel-armed.png) · [Creator listing](https://sketchfab.com/3d-models/simple-old-c4-43d3b6a933b04aea8006d790627f9555) |
| Claymore | Placed, arming, armed, existing effect and removal. Colour follows the current arming state. | Original chamfered shell with an orientation mark and state lens. [Arming](sprint12-captures/claymore.png) · [Armed](sprint12-captures/claymore-armed.png) |
| Smoke canister | Thrown and resting canister. Its visual hides at the existing cloud origin and the cloud dissipates on its existing timer. | 1,394-triangle exterior by Roman Berezyak. [Canister](sprint12-captures/smoke.png) · [Cloud](sprint12-captures/smoke-cloud.png) · [Creator listing](https://sketchfab.com/3d-models/smoke-grenade-d61768fbc7494143bb87852c36d1beaa) |
| Deployable shield | Placed cover, existing damage reaction, collapse and removal. | Original low chamfered slab with rails and an inset sight detail. Its visual children follow the existing hit and collapse animation. [Placed](sprint12-captures/shield.png) |

The underlying scenes retain the same collision, health, interaction and effect anchors. The kit has no pickup or disarm state. Character grip art remains open in the character sprints. [Scene inventory and original visual bounds](../assets/intake/field-kit/baseline.json) · [Six held weapons](2026-11-23-sprint10-held-weapon-audit.md) · [M2 defensive position](2026-11-23-sprint11-m2-intake.md).

Sprint 25 distinguishes the equipped weapons and the M2's two mounted hand contacts from field-kit inventory actions. The satchel, claymore, smoke and shield rows cover placement or throw, the deployed states above, replica delivery, carried stock and retry cleanup. Dedicated per-item hand animations and owner art approval remain open. [Sprint 25 review](2026-11-26-sprint25-sg3-heavy.md).

## Source and fit

The two owner downloads supplied the C4 and smoke exteriors. Each creator listing identifies CC BY 4.0. Neither nested archive adds separate terms. The C4 archive is **Simple Old C4**, a different source from the Tinley candidate recorded at sprint start. The C4 preparation reorients the OBJ and generates tangent space for the normal map. The smoke archive contains explicit OpenGL and DirectX normals and the recipe uses the OpenGL version. Both GLBs use a 1K colour, normal and packed surface map, shared mipmapped mesh and material resources, and the original placeholder as a fallback. [Source comparison](../assets/intake/field-kit/sources.json) · [C4 archive](../assets/intake/field-kit/c4-archive.json) · [Smoke archive](../assets/intake/field-kit/smoke-archive.json) · [Credits](../../credits/ATTRIBUTIONS.md).

The claymore candidate’s provider metadata lists a noncommercial licence. The available vertical hand shield changes the silhouette of the existing low cover slab. The authored shells derive from the existing game bounds and use native materials and markings. Regenerate them with `python3 tools/author_field_kit_shells.py`. [Claymore work order](../assets/intake/field-kit/claymore-work-order.json) · [Shield work order](../assets/intake/field-kit/shield-work-order.json).

## Verification

The focused fixture covers all four visual envelopes, shared satchel and canister resources, arming cues, the C4 and smoke effect origins, and shield destruction releasing cover. Both GLB validators report zero errors and warnings. The normal Linux release pack checks the fitted visual states and 13 packaged credits. A second pack excludes both community GLBs and runs the visual checks with the scene fallbacks. [Checks and pack hashes](../assets/intake/field-kit/verification.json).

The original delayed-join probe reproduced the failure on listen and dedicated. Godot sent the four props before the replacement peer had a `GadgetSpawner`. The world now owns deployments separately from the operative roster and waits for mission readiness before delivering them. The host applies field-kit uses and each owner receives the confirmed stock counts. All four stocks carry through travel, deployments stay in their original world and retry resets both worlds.

The four-operative regression deploys all four items from a remote Recon. It delays a replacement peer's load while Carter travels through the gate, then sends Recon through and verifies the spent stock at the destination. The joining client checks the two armed cues, the live cloud and the shield at 475/600 HP. Every connected client verifies the deployments and then confirms zero deployments in both worlds and default stock after retry.

| Server | Replacement client after joining | Same client after retry |
|---|---|---|
| Listen, host plus three clients | [Four deployed items](sprint12-captures/listen-rejoined.png) | [Cleared deployment area](sprint12-captures/listen-retry.png) |
| Dedicated, four remote clients | [Four deployed items](sprint12-captures/dedicated-rejoined.png) | [Cleared deployment area](sprint12-captures/dedicated-retry.png) |

The images come from the replacement client's viewport after its network assertions. The regression stages the props for a repeatable view, lengthens the cloud lifetime for the fixed-step loading barriers and frames both checkpoints with the same diagnostic camera. The stock game uses its normal positioning and smoke lifetime. Owner art review remains open.

Run the two cases headless with the strict [test runner](../TESTING.md). To also capture the replacement viewport, run the following from a graphical session. The parent remains headless and writes the PNGs alongside the client logs in `build/test-results/roster-<pid>/`.

```sh
godot --headless --fixed-fps 60 --path client --script res://tests/test_field_kit_join_multiplayer.gd -- --capture-field-kit
godot --headless --fixed-fps 60 --path client --script res://tests/test_field_kit_join_dedicated.gd -- --capture-field-kit
```

## Reproduce the prepared meshes

Stage the verified archives in the locations in the [C4 recipe](../assets/intake/field-kit/c4-recipe.json) and [smoke recipe](../assets/intake/field-kit/smoke-recipe.json). The C4 intermediate is the original OBJ reoriented with a proper rotation from source X/Y/Z to game +Y/+X/−Z. Preserve its UVs and name its single mesh node `C4Housing`. The source-to-stage conversion used Trimesh 4.6.8 with mesh processing disabled. The tangent tool writes the intermediate named by the C4 recipe.

```sh
c4_stage=/tmp/tdc-asset-intake/field-kit-c4/decoded
godot --headless --path client --script "$PWD/tools/prepare_field_kit_mesh.gd" -- "$c4_stage/c4-geometry.glb" "$c4_stage/c4-ready.glb"
godot --headless --path client --script res://scripts/assets/pack_model_glb.gd -- docs/assets/intake/field-kit/c4-recipe.json
godot --headless --path client --script res://scripts/assets/pack_model_glb.gd -- docs/assets/intake/field-kit/smoke-recipe.json
```
