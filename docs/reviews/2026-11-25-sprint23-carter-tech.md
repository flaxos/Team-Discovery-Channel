# Sprint 23 — Carter Tech

Carter Tech wears khaki fatigues, dark teal webbing and a compact back-mounted scanner on the shared Airman rig. The eight-mesh, 96-triangle scanner uses solid Godot materials and joins the existing camera proximity fade. Class-specific material overrides reuse the Airman fabric and normal maps. The kit uses the same upper-chest attachment as O’Neill’s radio, tested on the inherited Sprint 22 branch. [Scanner and uniform](sprint23-carter-scanner.webp) · [Sprint 22 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/100).

The MP5SD and Zat use Carter-specific palm targets. The contact points are 4–18 mm from their nearest imported model vertices. Both meshes retain the existing combat emitters. [MP5SD view](sprint23-carter-mp5sd.webp) · [Zat view](sprint23-carter-zat.webp).

At the existing iris servo, Carter’s right palm meets the lever and the left braces on the housing while the station identifies Carter as the repairer. The two targets are presentation markers in the servo scene. The shot and aim states take priority over the reach. The held weapon returns when the repair ends or the hand targets move out of reach. The existing interaction and repair snapshots drive this visual. [Iris repair pose](sprint23-carter-iris-repair.webp) · [Iris servo scene](../../client/scenes/props/IrisServoHousing.tscn).

## Sources

The existing credited model files are reused. The scanner and repair markers were authored natively for this slice. [Airman rig and licences](2026-11-25-sprint19-airman-rig.md) · [MP5SD intake](2026-11-18-sprint7-mp5-intake.md) · [Zat source and fit](2026-11-23-sprint9-zat-visual.md).

| Model | SHA-256 |
|---|---|
| `sgc_airman.glb` | `a6af0b258f34b2c0a1d87339a65228306220a3bc89e5be2fc6d4ae449c0cdeff` |
| `mp5sd.glb` | `96214c25a3f56284af74d5c22acd847f7f81a57fd871f5fd033aa8afb0756b80` |
| `loop_frame_zat.glb` | `97d50315c176f6a0d9dbae076cbb20f4bad762fa1fb40bf9ca719eddec2ec753` |

## Review status

The starter preview covers a first costume and equipment fit in the real SGC scene. The close-range fixture checks both palms within 3.5 cm of their servo targets and verifies that aiming or moving beyond reach restores the held weapon. Six targeted suites passed, including four-player listen and dedicated checks for the class kit across gate travel, late join and retry. The Linux export passed the shared rig, SGC embarkation materials and credits checks. Captures use Godot Forward+ on Mesa llvmpipe.

Offworld and alarm-light captures, continuous motion and health-state review, the full project suite, and owner art acceptance remain open.
