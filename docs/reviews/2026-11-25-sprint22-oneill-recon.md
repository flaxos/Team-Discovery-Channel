# Sprint 22 — O’Neill Recon

O’Neill Recon wears slate-blue fatigues, tan webbing and a left-back radio with a whip antenna. The radio is an original Godot scene with eight meshes and 156 triangles, mounted to the upper-chest bone. The kit’s top sampled 1.75 m above the root while ready and 1.25 m while crouched. Per-operative material overrides use the existing fabric and armour maps with a different colour palette. The face uses the Sprint 19 masked skin. [Recon and SG-3 Heavy in the SGC](sprint22-recon-uniforms.webp) · [Radio fit](sprint22-recon-radio.webp) · [Goa’uld Infiltration](sprint22-recon-offworld.webp).

The P90 and M9 use separate right and support palm targets sampled against their existing model geometry. The targets sit 11–16 mm from the nearest model vertices, allowing space for the glove. The standing weapon visual recoils with the right palm and pitches down as the replicated reload begins. It returns to its aim position as the reload completes. The M9 follows the right palm when downed so the support arm can follow the downed and crawl clips. The existing capsule, camera, callsign, weapon stats and authoritative muzzle supply gameplay. [P90 aim](sprint22-recon-p90-aim.webp) · [P90 during reload](sprint22-recon-p90-reload.webp) · [Downed with M9](sprint22-recon-m9-downed.webp).

## Sources

The same distributed files and recorded licences support this slice. The radio uses Godot geometry and solid materials. It has no texture downloads and joins the existing camera proximity fade with the rest of the kit. [Airman rig and licences](2026-11-25-sprint19-airman-rig.md) · [Weapon fit and attribution](2026-11-23-sprint10-held-weapon-audit.md).

| Distributed model | SHA-256 |
|---|---|
| `sgc_airman.glb` | `a6af0b258f34b2c0a1d87339a65228306220a3bc89e5be2fc6d4ae449c0cdeff` |
| `p90.glb` | `926ab64ee651ee9b433bebed1a93566646fdb5152b8a9aabb14879e4354b4af4` |
| `beretta_m9.glb` | `17ce228acc90eb3a25dd43158c44db7a3b08ead5ef9dab3f1c865cf7be97436a` |

## Review status

Sourcing is complete for the reused assets and native radio. Eleven targeted Godot 4.4.1 suites passed on baseline `c95ab6e` with the local Recon changes. They cover role isolation, camera and aim, weapon handling, downed M9, dragging, recovery, and the SGC Defense mission-result transition. Four-player listen and dedicated sessions checked the Recon radio across gate travel, late join and retry. The exported Linux pack passed the rig and credits fixtures. A second pack with the character GLB excluded passed the procedural fallback fixture. [Local test report](../../build/test-results/sprint22-on-current-main/summary.json).

The captures use Godot Forward+ on Mesa llvmpipe. The SGC alarm sequence uses the existing Gate Room strobes, with a staged walk, crouched aim, shot and reload. The close ADS camera fades the shoulder and radio while aiming. [Alarm still](sprint22-recon-alarm.webp) · [Five-second motion clip](sprint22-recon-alarm-motion.mp4) · [Shoulder view](../../build/sprint22-recon-review/alarm-shoulder.png) · [Close ADS view](../../build/sprint22-recon-review/alarm-ads.png).

Owner art review and the full project test suite remain open.
