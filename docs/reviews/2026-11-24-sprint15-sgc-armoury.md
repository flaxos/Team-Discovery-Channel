# Sprint 15 — SGC armoury and ready room

`feat/sprint15-sgc-armoury` started from `5932b6e`, which has the same content as Sprint 14's squash merge `04f9b27`. The scope is the authored Level 28 armoury and its west approach. The SGC uses `GateRoom/Level28Complex/ArmorySector` and its five existing stations. [Sprint 14 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/87) · [Sprint 15 scope](../plans/asset-vertical-slices.md#sgc-base).

| Family | Existing target and fit | Acceptance view and interaction |
|---|---|---|
| Weapon racks | `WeaponRackNorth` and `WeaponRackSouth`. Two solid 0.8 × 2.8 × 4.0 m boxes against the east wall. The player approaches from local −X. | Fit a backed enclosure to the cover footprint. Check both approaches, readable prompts, live primary swap and a crouched player behind the cover. |
| Munitions storage | `AmmoCrate1` and `AmmoCrate2`. The collision boxes are 1.6 × 1.0 × 1.2 m. Each shows 33 instances of the same crate mesh at 0.984 scale. | Compare close and wide views under normal and alarm lighting. Exercise resupply, camera fade and restoration, and the original collision face. Measure the optimized stacks from the same wide camera. |
| Re-armour station | One `ArmoryArmorStation` by the north wall. Its cabinet is 1.4 × 2.0 × 0.5 m. Its plates extend to local Z = +0.325 m. The interaction cylinder is 2 m in radius and height. | View the station from inside the room. Check the prompt, existing re-armour interaction and cooldown while a second player uses another station. |

## Community intake

- **Worn Metal Rack**, Luca B, published by Poly Haven under CC0. The 1K glTF, buffer and three maps matched the provider's sizes and MD5 hashes. The runtime GLB has 6,372 triangles, one material and three 1024² PNG maps. Its 0.915 × 1.900 × 0.600 m source fits the re-armour cabinet after uniform scaling by 0.83. The prepared GLB is 4,365,636 bytes, with SHA-256 `dcbf963a17c170eeff0d5978f0e56f020874ff2b5458e82c3eced9d8a035d9e4`. Khronos validation returned zero errors and warnings. [Creator listing](https://polyhaven.com/a/worn_metal_rack) · [Provider licence](https://polyhaven.com/license) · [Intake and recipe](../assets/intake/worn_metal_rack/).
- **Metal Toolbox** is a candidate for a small maintenance accent. Its short silhouette fits equipment dressing, while the chipped finish needs an in-room comparison under the existing light. [Poly Haven listing](https://polyhaven.com/a/metal_toolbox).
- **Gun Locker, Open and Empty** is a dimensional reference. Its posed door and keypad do not suit the backed SGC rack and would imply another interaction. [Creator listing](https://3dassets.dev/assets/cyberpunk-apartment-and-neon-block-gun-locker-f7a750d5).

The raw rack files remain staged under `/tmp/tdc-asset-intake/sprint15-worn-metal-rack/`. Its original depth and width limit it to a shelf inside the armour station. The weapon rack cover boxes use an original native cabinet mesh. [Crate provenance and prior measurements](2026-11-16-ap1c-plastic-crate.md).

## Fitted room and cost

Both loadout stations share one backed cabinet mesh and material. The authored CSG boxes still provide collision and stop rays at the same faces. The re-armour station places the imported shelf inside the existing cabinet envelope and seats the spare plates on the measured middle shelf. It uses a lower status-light intensity for readability. The existing prompt, cooldown and interaction volume apply, and the stock cabinet takes over when the import is absent.

The third-person camera fades the drawn crate stack or cabinet when its ray hits the authored CSG collider. Crouch occlusion follows the lowered torso. The camera applies a temporary material to the occluding instance and restores the shared opaque material when the ray clears. The real-room regression uses the normal shoulder camera behind a crouched operative, verifies the other stack stays opaque, then turns the camera clear of the cover.

The crates keep 33 instances per stack and one shared material. The offline bake preserves the detailed vertex data and adds two index levels with 2,600 and 1,500 triangles per crate. The source GLB continues to provide the maps and the detailed mesh fallback.

| Crate detail | Triangles per crate | Both 33-crate stacks |
|---|---:|---:|
| Original close detail | 5,840 | 385,440 |
| First LOD observed at the wide comparison camera | 2,600 | 171,600 |
| Second LOD | 1,500 | 99,000 |

At 1440 × 900 on the RTX 3060, the wide view selected the first LOD for both stacks, a 55.5% reduction in crate triangles. Forward+ kept 4,706 draw calls in the comparison. Godot 4.4.1's LOD render counter counts indices once per surface in this path, while its detailed path multiplies by the MultiMesh instance count. The table accounts for all 66 instances. The GPU timing samples did not establish a speedup. [Godot LOD guide](https://docs.godotengine.org/en/4.4/tutorials/3d/mesh_lod.html#using-mesh-lod-with-multimesh-and-particles) · [Forward+ render counter source](https://github.com/godotengine/godot/blob/4.4.1-stable/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L969-L992).

## M2 operator positioning follow-up

The player stood on the tripod's original rear axis even when the receiver turned past them. The turret now places the operator one metre behind the yaw of the live head. The operative's body faces the receiver and the mouse can still turn the camera independently. The personal weapon is stowed while mounted and returns on dismount. The same occupied seat follows replicated yaw on the owner and other clients. Airmen use the same rear position. [Sprint 11 fit and original behaviour](2026-11-23-sprint11-m2-intake.md).

The four-player listen and dedicated regressions turn a remote SG-3 player's M2 past 90°, verify its original shot marker and check that the replacement peer sees the operator behind the receiver. The solo tactical fixture verifies that dismount restores the personal weapon and walking orientation. A physics probe found the operative capsule clear with 5 cm of floor clearance at 24 equally spaced yaw samples on each fixed SGC position. The diagnostic comparison reconstructs the former fixed placement and shows the corrected seat at the same turn angle.

## Captures and verification

| View | Evidence |
|---|---|
| M2 aimed past 90° | [Former seating](sprint15-captures/m2-before.png) · [Operator behind the receiver](sprint15-captures/m2-turned.png) |
| Armoury stations | [Loadout cabinets](sprint15-captures/rack.png) · [Re-armour shelf](sprint15-captures/shelf.png) · [Alarm lighting](sprint15-captures/alarm.png) |
| Both ammo stacks in the same wide view | [Full detail](sprint15-captures/full-wide.png) · [Automatic LOD](sprint15-captures/lod-wide.png) |

Project import, the focused armoury and M2 tests, and all 60 Python tests passed. The native ENet station fixture had two simultaneous visitors use re-armour and resupply. The separate late-join fixture confirmed the three armoury families when loading and again after retry. Four-player listen and dedicated ammunition-sharing checks passed.

The strict Godot coverage passed all 128 checks across two runs. The initial process stopped after 126 passing checks, and the two remaining world-coexistence cases passed in a separate strict run. The crate fit and fade, wall occlusion and ADS alignment checks were also rerun after the final crouch camera adjustment.

The standard Linux release pack passed the armoury fit and M2 visual checks and contained all 17 credited assets and both licences. The fallback pack excludes the shelf and crate LOD resource. It verified the stock re-armour cabinet and retained the detailed crate stacks. The standard fit test rejected that same fallback pack, confirming that the test detects the missing assets. Owner art review remains open.

| Linux x86-64 PCK | Bytes | SHA-256 |
|---|---:|---|
| Standard | 64,648,496 | `6a41aa8a93e622583e77391ce7b2ce948b1d52645af25d3a7f6870dff26cbb4d` |
| Fallback | 60,089,520 | `9ff3329506907b6e453f60a04e243b035c411144ee871aa76b7d1d4a7c6a586b` |

## Reproduce the crate bake and view comparison

```sh
mkdir -p build/asset-review/sprint15-crate-lods
npm install --prefix build/sprint15-node-tools --no-audit --no-fund meshoptimizer@0.23.0
godot --headless --path client --script "$PWD/tools/prepare_sgc_crate_lods.gd" -- dump "$PWD/build/asset-review/sprint15-crate-lods"
node tools/prepare_sgc_crate_lods.mjs build/asset-review/sprint15-crate-lods build/sprint15-node-tools
godot --headless --path client --script "$PWD/tools/prepare_sgc_crate_lods.gd" -- bake "$PWD/build/asset-review/sprint15-crate-lods"
flock /tmp/tdc-godot-network-tests.lock godot --audio-driver Dummy --path client --script res://tests/support/crate_visual_review.gd -- --compare-lods
```
