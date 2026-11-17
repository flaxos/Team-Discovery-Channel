# CO-2 chunk 1: ammunition sharing

Sprint 5 adds a deliberate, rebindable **B — Give ammunition** action. Aim at a
standing human teammate within 3 metres, with a clear torso-to-torso path. The HUD
shows the proposed amount or the reason sharing is unavailable. E retains revive
and station interactions. Successful transfers acknowledge both participants.

Only the two active weapons participate. MP5 and M9 use `9x19`; P90 uses `5.7x28`;
M249 uses `5.56x45`. Staff and Zat weapons have no shareable ammunition. One press
gives up to one recipient magazine from donor reserve, bounded by donor stock and
the recipient's authored reserve capacity. Neither loaded magazine changes.
An already overfilled reserve is left intact and cannot receive more ammunition.
Both operatives must be alive, standing, unstunned and not reloading, frozen or
traveling. Sharing is unavailable during a result or retry. The local action is
also suppressed by menus, lost focus, CCTV and the command wheel.

The server authenticates the donor actor, validates both spawn incarnations and
active weapon IDs, same-world membership, reach, line of sight and inventory. It
chooses the amount and mutates both reserves before emitting any signals. A
monotonic request sequence rejects replays; a 500 ms successful-transfer cooldown
bounds repeated presses. No inventory is predicted on clients. Existing weapon
snapshots replicate the result and existing gate-travel capture carries it.

Acceptance: conservation and capacity boundaries; incompatible/energy weapons;
walls, distance, health, reload, stale IDs and incarnations; forged/replayed remote
requests; four operatives on listen and pawnless dedicated servers; late snapshots,
retry and disconnect; actual HUD/default and remapped input captures. Human co-op
latency and the provisional 3 m/one-magazine/500 ms tuning remain owner review.
