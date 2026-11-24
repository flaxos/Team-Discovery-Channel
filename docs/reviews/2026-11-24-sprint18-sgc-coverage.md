# Sprint 18 — SGC coverage

Sprint 18 dresses the three-floor route in `client/resources/maps/sgc.tres` and the security console in `client/scenes/world/Level27Complex.tscn`. The authored SGC has support, staging, storage and service rooms. Barracks are outside the live layout. [Sprint 17 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/90) · [Sprint 18 scope](../plans/asset-vertical-slices.md#sgc-base) · [SGC authoring contract](../maps/sgc.md).

| Floor and live slots | State | Fit and evidence |
|---|---|---|
| 26 storage · `SupplyRack1`–`3` | Integrated; art review open | The adjacent 1.4 × 1.8 × 1.5 m racks share the prepared medical transport cases. `SupplyRack2` retains its original cover at `(8.2, 11.9, 33.2)`. |
| 26 service · `ServiceCabinet` | Integrated; art review open | Reuses the embarkation steel maps with a matte finish on the original 1.2 × 2 × 1.2 m cabinet at `(28, 12, 28.5)`. |
| 26 storage · `SupplyRack0`, `STORAGECover` | Integrated; art review open | The two cover boxes overlap at the entrance. The lower cabinet supports two shortened tiers of cases within the upper rack. Both original colliders still provide cover. |
| 26 staging · `STAGINGCover`, `StagingBench0`, `StagingBench1` | Integrated; art review open | The Sprint 16 cabinet now has two nearby workbenches with full-width tops and lower shelves. Both fit the original 3.5 × 0.7 × 0.6 m slots. |
| 27 security · `CCTVMonitorBank` | Integrated; art review open | Four CRTs and their bank fit inside the original 0.6 × 1.6 × 4 m hull. The operative's camera shows the selected live feed. The matching label on the bank lights up. |
| 28 return approaches · `EAST_CORRIDORCover`, `WEST_SERVICECover`, `WEST_FALLBACKCover` | Integrated; art review open | The 1.6 × 1 × 1 m slots reuse the closed cabinet visual. |
| Wall and floor surfaces | Integrated; art review open | 69 wall segments and 11 floor sections in security, the upper lift lobby, support, staging, storage, service and the west return approaches reuse the Sprint 13 concrete finishes. |
| Ceiling assemblies, lights and conduits | Deferred to architectural polish | The nine route rooms above retain their functional ceilings, beams, lights and conduits. Use the existing regional slot IDs for a separate finish pass. |
| Service stair shell | Deferred to architectural polish | Keep `SERVICE_STAIRWELL__SERVICE_ROOM` walk surface, rails, treads and enclosure paired with the rest of the stair architecture. The texture and trim pass is separate from support props. |

## Security monitor intake

Benny Weimer's CC0 Television 02 came from Poly Haven's canonical 1K glTF source. The five source files matched the provider sizes and MD5s. The production GLB has one surface, 2,310 triangles and a native envelope of 0.400 × 0.411 × 0.350 m in X/Y/Z. All four monitors share the mesh and mipmapped material, with a uniform 1.25 scale and the glass facing +X. The four copies draw 9,240 CRT triangles. The cyan console remains available if the model is missing. [Creator listing](https://polyhaven.com/a/television_02) · [Poly Haven licence](https://polyhaven.com/license) · [Source and prepared hashes](../assets/intake/sprint18-television/source.json) · [Khronos validator](../assets/intake/sprint18-television/gltf-validator.json).

## Play and export evidence

- Project import, SGC map contract, lift routes, camera occlusion, CCTV interaction and the 21-entry credits check passed. The map contract checks every fitted support prop and cover ray. The CCTV fixture validates shared geometry, original collision, physical fit and all four feeds including wraparound and exit.
- The 28→27→26→28 lift loop and both directions of the full SGC walk and stair matrix passed under normal and alarm lighting. The walk and stair matrix uses the production operative, Airman and Jaffa capsules. Four-player listen and dedicated fixtures passed delayed loading, a replacement join during gate travel and retry.
- Production friendly lift navigation and the seeded three-floor hostile overrun passed under normal and alarm lighting. Use `-- --alarm` with `test_sgc_lift_routes.gd`, `test_sgc_map_routes.gd` or `test_sgc_ai_wayfinding.gd` in a direct Godot run to repeat the alarm cases.
- The Linux standard pack (76,653,552 bytes, SHA-256 `0bcd659a7f00e3d4c5ed27f5771e0dcf30a793a7b656995a1e482ec20d76a769`) passed CCTV, the SGC map contract and the credits UI. A second 74,298,224-byte pack excluded the CRT and passed the original-bank fallback with all four feeds.

The Forward+ views use the actual rooms and current lighting. [Security normal](sprint18-captures/security-normal.png) · [Security alarm](sprint18-captures/security-alarm.png) · [Storage entrance](sprint18-captures/storage-entrance-normal.png) · [Storage normal](sprint18-captures/storage-normal.png) · [Storage alarm](sprint18-captures/storage-alarm.png) · [Staging bench](sprint18-captures/staging-bench-normal.png) · [Staging alarm](sprint18-captures/staging-bench-alarm.png) · [Service normal](sprint18-captures/service-normal.png) · [Service alarm](sprint18-captures/service-alarm.png).

Owner art review remains open.
