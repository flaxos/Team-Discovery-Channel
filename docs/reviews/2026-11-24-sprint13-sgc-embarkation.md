# Sprint 13 — SGC embarkation

This slice starts from Sprint 12's merge at `bf13f40`. It dresses Level 28's existing 24 × 12 × 30 m gate chamber, both side approaches, the 3.2 × 0.4 × 8.25 m gate ramp and the existing 8 × 2 × 12 m platform. It uses 35 mapped surfaces plus the ramp and platform. Cover dimensions, approach openings, landing, iris, navigation and the gate's centerline still come from the existing authored scene and SGC map.

| Family | Coverage and repeat | Source |
|---|---|---|
| Wall and panel | 19 cast concrete segments across the chamber, both side approaches and the observation sill. The 4 m world-projected tile gives 256 source texels/m and joins across boxes. | [Concrete by Rob Tuytel](https://polyhaven.com/a/concrete) |
| Floor and runner | Three concrete floors with a continuous 2 m world-projected tile at 512 source texels/m. The existing ramp and landing use the tread plate. | [Smooth Concrete Floor by Dimitrios Savva](https://polyhaven.com/a/smooth_concrete_floor) |
| Support and rail | 13 overhead ribs, beams and side-stair rail segments share the ramp's 0.5 m tread plate at 2,048 source texels/m. Local projection follows the slope and supports. | [Metal Plate by Rob Tuytel](https://polyhaven.com/a/metal_plate) |

All three 1K sets were downloaded directly from Poly Haven under CC0. The diffuse JPEGs retain their source bytes. Normal and ORM maps use lossless 8-bit PNG with OpenGL +Y normals and R/G/B for AO, roughness and metallic. Concrete has a zero blue channel. The tread plate keeps its varying metallic channel. Darker, cooler tint and lower normal strength keep surface grain readable in the bunker. [Map hashes and exact sources](../assets/intake/sgc-embarkation.json) · [Credits](../../credits/ATTRIBUTIONS.md) · [Provider licence](https://polyhaven.com/license).

## Material binding and comparison

`SGCAssetSlot.pbr_material` supplies a shared native StandardMaterial3D on the original drawing mesh. A missing or empty assignment uses the legacy single-texture slot when present, then the style palette. The existing player occlusion system fades a per-mesh copy and restores the shared material. Nine imported texture images including their mip chains account for 37,748,727 decoded bytes, about 36 MiB. That is image payload size. GPU residency depends on the renderer.

| Existing scene view | Capture |
|---|---|
| Gate chamber before and after | [Before](sprint13-captures/before.png) · [Dressed](sprint13-captures/normal.png) |
| East approach | [Wall seam and gate-room threshold](sprint13-captures/side-approach.png) |
| Emergency and gate active | [Alarm](sprint13-captures/alarm.png) · [Incoming gate](sprint13-captures/gate-active.png) |
| Same view of the tread plate | [Source metallic map](sprint13-captures/steel-source.png) · [Metallic zero](sprint13-captures/steel-matte.png) · [Source metal with an interior probe](sprint13-captures/steel-bounded-probe.png) |

The delivered lighting adds one cool, shadowless work light aimed down the ramp. At the fixed wide camera, the previous scene measured 1.09 ms median GPU time, the new textures with the previous lighting 1.24 ms, and the textures with the work light 1.26 ms. The original and dressed views each recorded 73 objects and 111,731 rendered primitives. The samples cover 45 settled frames per view at 1440 × 900 on an RTX 3060 using Forward+.

D-015's matte comparison gave the brightest central tread sample. In the same 360 × 170 pixel crop, mean display-space luma was 45.5/255 for the mapped metal and work light, 57.7/255 at metallic zero, and 51.9/255 with the mapped metal and a 22 × 10 × 27 m box-projected interior probe. The probe cost 2.18 ms against 1.10 ms GPU at that camera. The local work light gives the shipped ramp a defined edge and tread while preserving the metal map. The probe remains a diagnostic option for a later lighting review. The accepted Jaffa and held-weapon finishes are unaffected. [D-015](../DECISIONS.md#d-015--jaffa-armour-finish).

## Verification

`test_sgc_embarkation_materials` checks shared resources, exact map channels and mipmaps, the legacy fallback, the actual player camera fade, cover collision, the gate aperture and access from the east approach to the ramp and platform. Footstep audio is unsupported in this checkout. The helper uses the real SGC UAT scene and a diagnostic camera. The gate-active frame uses the existing incoming gate snapshot. Owner art review is open.

The strict local full run passed 126/126 checks. The nine focused checks passed, including import, SGC architecture, camera occlusion, gate travel and return, and the four-operative listen and dedicated regressions. The Linux release pack also passed the material fixture and exported all 16 credits and both licences. [Verification and pack hash](../assets/intake/sgc-embarkation.json).

From the repository root, run the capture helper in a graphical session. PNGs and timings go under `build/asset-review/sprint13/`.

```sh
flock /tmp/tdc-godot-network-tests.lock godot --audio-driver Dummy --path client --script res://tests/support/sgc_embarkation_review.gd
```
