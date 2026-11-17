# Sprint 6 — Goa'uld corridor family (GA-2 part 1)

Extend the GA-1 stone/bronze/gold language to the next room group in
[the visual brief](../goauld-visual-brief.md#42-by-module-which-is-the-order-art-should-follow):
narrow corner, T-junction, wide straight/corner and width adapter. Complete the
same family's X and wide junction variants from the unfinished extension too.
The existing narrow straight and compact chamber retain their art. This gives
pieces to modules `room01`–`room09`; larger chambers, tall rooms, props, textures,
lighting and door leaves remain later chunks. A human has not accepted this art.

Recover the theme generator and theme checks from `e72ff28`, whose navigation and
weapon changes are separate work. Reuse the unfinished corridor junction entries,
without importing its later chamber/tall-room or
mission changes. Record the source checkout's dirty-file hashes before and after;
leave that checkout untouched.

Use the current discovered module scenes and existing theme slots. Keep the
native compound layout, all structural scene bytes, collision, doorway opening,
sockets, markers, navigation and cover unchanged. The generator owns all output.
Relief stays inside slabs; floors stay flat; gold stays above 2.8 m. Floor runners
must follow actual branches and join at the same positions; short slab borders
must have no negative boxes, gaps or doubled faces. Existing R21 header offsets
are structural debt: retain them and finish both lintel faces at joins. Gold may
stand 5 mm proud on either face, above the opening, within the existing slot
tolerance. Do not move gameplay geometry during this visual milestone.

Acceptance: all nine module definitions apply pieces without fallback; the native
compound advances from 8 to 14 pieced rooms (6 remain palette-only); themed versus
neutral structures/navigation match; test rotations and connected narrow/wide
joins; capture every new corridor shape, both lighting-neutral comparison and
Jaffa/marker readability, plus a playable native-compound view. Run targeted and
full strict validation, Python checks and hosted CI. Deliver review evidence and
a draft PR. Owner visual/co-op acceptance stays explicit.
