# Sprint 30 — Goa’uld vertical chambers

Sprint 30 starts from the command-room PR head `701920e` on `feat/sprint30-goauld-vertical-chambers`. The three target rooms use authored Goa’uld pieces on their native shells. The native layout and equipment clearance volumes define the art fit. [Sprint 29 review](2026-11-26-sprint29-goauld-command-room.md) · [Native layout](../../client/resources/levels/goauld_infiltration_01.tres) · [Vertical kit](../maps/modular-vertical-kit.md).

| Instance | Native shell | Placement and route |
|---|---|---|
| `ramp` | `room14`, 8 × 16 m | Lower deck at `(-8, 0, 56)`, quarter-turn 3. The lower socket meets `inner` and the upper socket meets `up_hall`. |
| `ring_lower` | `room15`, 8 × 8 m | Lower deck at `(24, 0, 48)`, quarter-turn 1. The north portal meets `stores`. |
| `ring_upper` | `room15`, 8 × 8 m | Upper deck at `(-24, 4, 64)`, quarter-turn 0. The north portal meets `up_hall`. |

The ramp has a 4 m rise over a 12 m run and a 2 m landing at each end. The kickoff probe used the stock operative’s movement input to walk both ways while checking continuous floor contact and rise. The smallest vertical distance from the walking operative’s feet to the sampled ceiling was 3.34 m. Both live ring pads accepted Interact and transported the operative to the other level while preserving horizontal rider spacing. Each pad reserves a 5 × 10.2 × 5 m operating volume about the transport anchor. [Ramp catalogue](../../build/sprint30/ramp-catalogue.json) · [Rings catalogue](../../build/sprint30/rings-catalogue.json) · [Baseline movement and transport log](../../build/sprint30/vertical-headless.log).

## Art integration

The ring chambers share the tall basalt walls, bronze ribs, short door cartouches and recessed ceiling treatment. A flush bronze frame sits 2.56–2.72 m from the pad centre along the floor axes, clear of the 2.5 m half-width of the reserve. Its top is level with the native floor. The ramp has stepped wall panels, two-tone rails and a continuous floor runner through the pitched slab and both landings. The visual pieces inherit the native slab transforms. [Theme generator](../../tools/theme_kit.py) · [Theme data](../../client/resources/level_themes/goauld.tres).

**Sourcing.** The generated scenes use the existing Goa’uld materials and add no textures. The screened CC Attribution hallway by Seesha is a 687.1k-triangle architectural kit that the creator describes as unsuitable for direct game use. The modular wall panels from Shawn Moore 3D Solutions would require reworking the native relief and portal seams. The existing kit already supplies the palette, dimensions and fitted wall profiles. [Sci Fi Hallway FREE](https://sketchfab.com/3d-models/sci-fi-hallway-free-44fd25310d2240908027390a078368e1) · [Sci-Fi Wall Panels](https://sketchfab.com/3d-models/sci-fi-wall-panels-c49641fafe59469cb60bb32bc8dec1e6).

## Technical verification

- Native validation passed with zero warnings and authored pieces in all 20 compound rooms. The Goa’uld theme suite matched neutral collision, navigation, sockets and markers. It checked the top of each ramp floor piece in the native pitched frame and the ring frame against the operating footprint. All 60 Python tests passed. [Native validation](../../build/sprint30/final-native-validation.json) · [Python results](../../build/sprint30/python-final.log).
- The live route probe walked from `inner` across both ramp seams into `up_hall` and back in three lanes. The lowest sampled ceiling clearance over the ramp was 3.376 m. Interact transported the stock operative in both directions and kept their horizontal offset. [Dressed route and ring results](../../build/sprint30/final-routes.log).
- Six focused Godot suites passed. Four-operative listen and dedicated sessions exercised both pads, occupied-arrival protection, a late join during the live cycle, return and retry. Quiet and alarm Infiltration also passed. The full Godot profile was started on the same source. [Focused summary](../../build/sprint30/focused/summary.json) · [Full runner log](../../build/sprint30/full.log).
- Standard and procedural-gate-fallback Linux packages booted and passed the gate route. The standard package also passed the packaged theme and collision-parity fixture. [Linux export log](../../build/sprint30/linux-export.log).

## Owner art review

Check the approach to the ring pad, the tall recesses during the active cycle and the pitch of the floor and rail at each landing. Owner art review is open. [Lower landing](../../build/sprint30/final-ramp-lower.png) · [Upper landing](../../build/sprint30/final-ramp-upper.png) · [Lower chamber](../../build/sprint30/final-ring-lower.png) · [Upper chamber](../../build/sprint30/final-ring-upper.png) · [Lower active cycle](../../build/sprint30/final-cycle-ring_lower.png) · [Upper active cycle](../../build/sprint30/final-cycle-ring_upper.png).
