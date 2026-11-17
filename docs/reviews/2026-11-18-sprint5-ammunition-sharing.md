# Sprint 5 — ammunition sharing

18 November 2026. Baseline main `5b0a8f1` after merged #75; branch
`feat/sprint5-ammunition-sharing`, supplied checkout. [Contract and brief](../plans/ammunition-sharing.md).

## Result

Aim at a standing human teammate within 3 m and press rebindable **B** to give
compatible ammunition from the two active weapons. One press transfers up to one
recipient magazine, limited by donor reserve and recipient reserve capacity.
MP5/M9 share 9×19 mm; P90 uses 5.7×28 mm; M249 uses 5.56×45 mm. Energy weapons
cannot share. Loaded magazines and inactive weapons retain their state. Existing
overfilled reserves are left intact and cannot receive additional rounds.

The prompt explains the proposed amount or rejection reason; both participants
receive confirmation after host acceptance. E retains its existing revive and
station behavior. Health, reload, wall, distance, mission result, retry and pending
gate handoff checks prevent unavailable exchanges.

## Ownership and lifecycle

`PlayerController3D` authenticates the donor connection and validates recipient
identity, same-world membership, both active weapon IDs, live actor state and
torso line of sight. The host chooses the amount and writes both reserves before
emitting signals, so competing donors cannot exceed capacity or create rounds.
A monotonic sequence rejects duplicate intent; a host-owned spawn incarnation on
`SpawnVisibility` rejects retired retry/handoff requests. Each successful donor
has a 500 ms cooldown. Clients do not predict transfers. Existing weapon snapshots
and `MissionSession` inventory capture carry the accepted result. No new inventory
manager, map, gameplay geometry or external asset was introduced.

Key-event input explicitly consults the existing NetworkManager transfer pause on
both owner and host. Stopping physics alone leaves key handlers active, so this
guard prevents a post-ack request from the pawn being retired. The final targeted
run also exercises the existing listen/dedicated session lifecycle contracts.

## Verification

- `test_ammunition_sharing`: genuine weapon instances and aimed/remapped input
  handler; atomic conservation at notification time, magazine/capacity/last-round
  boundaries, all finite calibres, energy/mismatch, reload/health/frozen state,
  distance, actual wall physics, stale weapon IDs/incarnations, replay, capture and
  result/retry/handoff guards.
- `test_ammunition_sharing_multiplayer` and `test_ammunition_sharing_dedicated`:
  four operatives over real ENet on listen and pawnless hosts; remote intent,
  forged donor and weapon state, duplicate intent, targeted acknowledgements,
  late snapshots after a transfer, competing donors filling a near-full reserve,
  full-team retry with retired requests, recipient disconnect and clean shutdown.
  Server assertions wait for owner movement delivery, rather than treating a file
  barrier as a received movement packet.
- `test_ammunition_sharing_travel`: give and receive before actual gate travel;
  carried reserve after the handoff, split-world rejection, retired incarnation
  and a valid exchange with a new destination teammate.
- The four new suites passed targeted strict checks. The Python tooling suite
  passed **47 tests**. The pull request records the final local full run and
  hosted checks; detailed logs stay in ignored `build/test-results/`.

## HUD evidence

Reproduce with `DISPLAY=:0 godot --path client --script res://tests/support/ammunition_sharing_review.gd`.
Godot 4.4.1 Forward+, 1440×1000, native compound. This controlled fixture parks
hostiles and two operatives, selects an M9/MP5 pair and an initial recipient
reserve of 110. It uses the production aiming/input handler and server exchange;
the first transfer moves 30 rounds, then the remaining capacity admits 10. These
are functional HUD captures, not human co-op or art acceptance.

| Evidence | Artifact |
| --- | --- |
| Default B offer | [Default](sprint5-ammunition-sharing/1-default.png) |
| Remapped J offer | [Remapped](sprint5-ammunition-sharing/2-remapped.png) |
| Accepted 30-round transfer and updated donor reserve | [Given](sprint5-ammunition-sharing/3-given.png) |
| Final 10 rounds fill the recipient | [Full](sprint5-ammunition-sharing/4-full.png) |
| Switching to an incompatible active weapon | [Incompatible](sprint5-ammunition-sharing/5-incompatible.png) |

Human checks remain: four-person firefight usability, WAN presentation, aim/reach
comfort and the provisional 3 m/one-magazine/500 ms tuning. Sprint 6 is GA-2 part 1
visual expansion, beginning with inspection/recovery of unfinished work.
