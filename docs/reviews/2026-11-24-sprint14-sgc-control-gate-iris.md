# Sprint 14 — SGC control, gate and iris

Sprint 14 continues on the local `feat/sprint14-sgc-control-gate-iris` branch from Sprint 13's `c418ad0`. Its tree matches the Sprint 13 squash merge `2e6e01a`. [Sprint 13 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/86).

## Slice brief

| Family | Existing target and limits | Acceptance views |
|---|---|---|
| Control and glazing | `GateRoom/Level28Complex/ControlRoomMezzanine`. The observation pane is 11.8 × 2.4 × 0.1 m. The dialer desk is 2.6 × 0.9 × 1.2 m. The three display mounts each hold a 0.65 × 0.5 × 0.2 m screen. The interactive shutter, window, and dialer controls retain their authored areas and transforms. | Operator's view in standby, midway through dialing, after cancel and during GDO. Clear apron sightline with the shutter raised. Verify closed-shutter and frame alignment. |
| Gate rim | `GateRoom/Stargate`. The gate has a 2.75 m clear radius and a 3.35 m outer envelope, with the AP-1g glyph ring and seven imported chevron inserts. The full community body could not fit both bounds. | Unlit rim, seven orange locks and open horizon. Check existing collision and aperture with and without the fitted art. |
| Iris | `GateRoom/IrisServoHousing`. The housing is 1.0 × 1.2 × 0.8 m with a separate lever, light and interaction area. The servo replicates its repair stage, and StargateRing owns direction and activation state. | Jammed inbound, staged repair and secured inbound, then an authorized outbound gate. Any aperture indication must follow the existing authoritative state and leave the extraction area and horizon intact. |

## Implementation

The console has a cabinet edge, CRT bezels and a central status readout. The readout follows standby, chevron count, GDO, buffer lockout, ROM upload and ready states. Existing dialer signals update it for local and replicated changes, including cancellation. Four cosmetic pieces frame the observation glass. The shutter, collider and switches retain their authored nodes.

Two native rings dress the SGC gate from radius 3.07 m to 3.35 m. Their depth stays within the existing ±0.30 m prop envelope. The casing overlaps the AP-1g ring’s outer shoulder and sits behind the chevron faces. The full stock torus takes over when the imported glyphs are unavailable. The offworld scene continues to use the shared AP-1g gate.

The servo cabinet has a service panel, louvers and a front label. A cosmetic 2.735 m iris face with curved plate seams appears during an active inbound connection after the existing three-stage servo repair completes. The iris reads the servo status and the gate's direction and activation state. The event horizon keeps its own state and the existing extraction area retains its authorization check. The servo's snapshot supplies the repair readout and secured appearance when a peer loads; broadcasts use the existing mission-ready filter.

## Community source assessment

- The existing fitted AP-1g glyph ring and seven inserts already meet the gate aperture contract. The same archive's full housing has a documented fit failure. [AP-1g fit and source record](2026-11-16-ap1g-stargate.md).
- The CC0 Control Button Panel is sized appropriately as a control detail. The downloaded LOD0 remains outside `client/`. The intake check rejected its embedded buffer layout, and the GLB requires mesh optimization, quantization and Basis texture extensions. It needs conversion and in-engine fit verification before use. [Tevy listing and pinned download](https://tevy.dev/models/button-panel).
- Television 02 is a possible source for a CRT shell study. The current console uses three shallow displays and an existing green status surface, so the whole television would need a depth and screen readout fit check. [Poly Haven Television 02](https://polyhaven.com/a/television_02).
- Power Box 01 offers a textured enclosure reference. Its documented movement is the source enclosure rig, while iris state comes from the existing servo and wave scripts. [Poly Haven Power Box 01](https://polyhaven.com/a/power_box_01).

## Verification

The console capture follows three live chevron locks entered through the SGC dialer. The lifecycle fixture checks the rim vertices against the envelope, verifies clear and secured inbound states, and exercises cancel, GDO and authorized outbound travel. The four-operative listen and dedicated fixtures delay a replacement peer through another operative’s gate travel, then complete an inbound repair before releasing that peer’s load. The replacement receives the secured iris and readout from the real snapshots. Every active peer confirms the open, reset iris after retry.

| Checkpoint | View |
|---|---|
| Control at idle and with three locks | [Standby](sprint14-captures/control-standby.png) · [Dialing](sprint14-captures/control-dialing.png) |
| Control shutter | [Sealed observation window](sprint14-captures/control-shutter.png) |
| Gate and iris | [Unlit rim](sprint14-captures/gate-rim.png) · [Jammed inbound](sprint14-captures/iris-jammed.png) · [Secured inbound](sprint14-captures/iris-secured.png) · [Servo close-up](sprint14-captures/iris-drive.png) |

The eight focused lifecycle and travel checks passed, alongside both four-operative iris fixtures and 60 Python tests. The normal Linux pack passed the gate lifecycle fixture and all 16 packaged credits. A second pack excluded AP-1g and verified that the stock torus and iris lifecycle still work.

The full Godot run passed 127 of 128 checks. The dedicated extraction fixture's startup wait expired just before the server reported ready. Its strict rerun passed after the fixture switched to a wall-clock startup deadline.

| Linux x86-64 pack | Bytes | SHA-256 |
|---|---:|---|
| Standard | 60,078,160 | `c9e41a3716d7f29f85d780d2b395b60ed14625a7a07feffdf5e484c8583aa41d` |
| AP-1g excluded | 58,871,792 | `dc3321bee6d61dcb23981c05cdbf24db2c8a695d4b63855a834b3e5b19dcc97e` |

The captures use the Forward+ renderer at 1440 × 900 and a diagnostic camera. The inbound views follow the live seven-lock sequence and normal stabilization. The helper advances the three repair stages through the existing servo method. The new surfaces use native geometry and a procedural seam shader with zero added image maps. Owner art review is open.

```sh
flock /tmp/tdc-godot-network-tests.lock godot --audio-driver Dummy --path client --script res://tests/support/sgc_control_review.gd
```
