# Sprint 24 — Teal’c allied Jaffa

The playable `tealc_jaffa` in `Player.tscn` wears a brown field uniform with bronze chest lamellae and a matching back yoke. Nine native meshes mount on the shared Airman rig’s upper chest and follow the camera proximity fade. The variant shares the Airman cloth and normal maps and uses the generic masked face. The PR includes the Carter Tech checkpoint `4bdc331`, which is based on the merged O’Neill Recon PR. [Armour scene](../../client/scenes/entities/SGCJaffaArmour.tscn) · [Carter Tech review](2026-11-25-sprint23-carter-tech.md) · [Recon merge](https://github.com/flaxos/Team-Discovery-Channel/pull/100).

## Staff and Zat fit

The staff’s two palm targets sit inside the recorded grip sleeve spans. The rig places the shaft 0.260 m to the right of the operative’s centreline while standing and 0.228 m while crouched. It blends between those offsets as the stance changes and fits both palms on that plane. The standing offset lets the rear arm reach the grip when aiming steeply down. The crouched offset stays within the support arm’s reach. The existing authoritative muzzle spawns the plasma bolt, and the visible shot effect uses the fitted model’s emitter. The Zat stays in the right hand during the shared prone and drag poses. Recovery restores the staff. [Staff source and sleeve measurements](2026-11-23-sprint8-staff-intake.md) · [Zat intake](2026-11-23-sprint9-zat-visual.md).

## Sources

The community Teal’c portrait from ptibogvader is labelled CC BY 4.0 and lists 22,282 triangles, with no rig or animation. It was reviewed as a source lead. The 2,056-triangle community Jaffa body from Sprint 20 was already tested and set aside for its sparse clips and flat palette finish. The playable kit uses original add-on geometry over the proven skinned rig and the existing project staff and Zat. [Teal’c portrait](https://sketchfab.com/models/857e5c8f8db1474c99508ed5e2f0c08e/embed) · [Serpent intake](2026-11-25-sprint20-serpent-jaffa.md) · [Airman rig and licences](2026-11-25-sprint19-airman-rig.md).

| Distributed model | SHA-256 |
|---|---|
| `sgc_airman.glb` | `a6af0b258f34b2c0a1d87339a65228306220a3bc89e5be2fc6d4ae449c0cdeff` |
| `tri_vane_staff.glb` | `181a8a01aff016a61e11ade180fee79ad126eb4d1cb56a790e542a848e89696d` |
| `loop_frame_zat.glb` | `97d50315c176f6a0d9dbae076cbb20f4bad762fa1fb40bf9ca719eddec2ec753` |

## Captures and verification

The captures use Godot Forward+ on Mesa llvmpipe. The SGC alarm shot uses the Gate Room’s existing red strobes at peak brightness. The offworld capture uses the lower ring deck in Goa’uld Infiltration. [Standing staff](sprint24-tealc-staff.webp) · [Crouched staff](sprint24-tealc-crouched-staff.webp) · [Offworld ring deck](sprint24-tealc-offworld.webp) · [SGC alarm lights](sprint24-tealc-alarm.webp).

The SGC recovery sequence uses the existing player drag interaction. The rescuer still uses the shared ready stance, and Teal’c uses the shared prone motion during the drag. [Running with the staff](sprint24-tealc-running.webp) · [Downed Zat](sprint24-tealc-downed-zat.webp) · [Zat during drag](sprint24-tealc-drag.webp).

The rig fixture sweeps the full ±45° weapon pitch during running, aimed walking and crouch walking, with a 15 mm maximum distance between each palm and its target. A separate sweep of seven ready and aim clips measured a peak gap of 2.4 mm after each pose settled. The fixture also verifies the fitted shot effect, the original bolt origin and direction, and the transition from downed Zat through drag and recovery back to the staff. Four-player listen and dedicated runs cover delayed loading, gate travel, late joining and retries. The standard Linux pack passed the rig, SGC materials and credits fixtures. A second pack with the shared character GLB excluded passed the procedural fallback fixture.

All 135 Godot suites and 60 Python checks passed across the local runs. The SGC route suite passed on a rerun with an extended timeout, and dedicated modular flanking passed on a separate retry. Full validation also corrected the Defense-result projectile lookup to use `MissionWorld` and restored the live wave manager in the alarm-shutter test. The local Godot report is `build/test-results/sprint24-tealc-resume/summary.json`.

Owner art review remains open.
