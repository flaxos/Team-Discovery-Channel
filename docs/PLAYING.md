# Playing and local UAT

Use Godot **4.4.1**. Run commands from the repository root unless using an absolute `--path`.

## Start the updated map

```sh
godot --path client -- --mission sgc_uat
```

1. Enter your callsign and choose a specialization/loadout.
2. Click **ESTABLISH SGC BASE (HOST PORT 7777)**.
3. In **LEVEL / MISSION**, choose **SGC UAT Base — No Hostile Activation** for quiet exploration, or **SGC Defense — Levels 28/27/26** for combat.
4. For Defense, choose difficulty. Click **LAUNCH SELECTED MISSION**.

A fourth entry, **Goa'uld Infiltration — Greybox** (`--mission goauld_infiltration`), is a stealth mission in a two-deck compound; see [its guide](maps/goauld-infiltration-mission.md). A fifth entry, **Operation Infiltration — SGC to Offworld** (`--mission travel_infiltration`), runs both the SGC and the Goa'uld compound together: gear up in SGC Sublevel 28, dial out on the control-room dialing computer, step through the event horizon into the compound with your health and loadout preserved, complete the offworld objectives to open the offworld Stargate for home, and return to the SGC ramp for debrief (interacting with the SGC dialing computer while the outbound gate is open aborts the mission). A third entry, **Modular Extraction UAT — Development**, runs a short objective mission on a modular test facility instead of the SGC; preselect it with `--mission modular_extraction_uat`. Its objectives, extraction rule and limitations are in the [mission guide](maps/modular-extraction-mission.md). The floor, lift, shutter and Defense sections below apply to the SGC missions only.

A sixth entry, **Goa'uld Infiltration — Timed Extraction** (`--mission goauld_timed_extraction`), adds a countdown to the standalone compound mission. Sabotage the generator, then download the command records to start a three-minute extraction window. All standing operatives must reach the Stargate extraction marker before it expires. The top-right clock turns red at 30 seconds and continues while menus are open. Expiry shows **EXTRACTION WINDOW EXPIRED**; retry resets the mission and timer. The three-minute duration is provisional pending playtesting. The ordinary infiltration and SGC travel missions remain untimed. See the [brief](maps/briefs/timed-extraction.md).

A seventh entry, **Goa'uld Infiltration — Alarm Escape** (`--mission goauld_alarm_escape`), starts its three-minute clock when a guard actually raises the alarm. Finish generator sabotage and the command-record download, then return all standing operatives to the Stargate before expiry. Searching does not start it; preventing the alarm through console disables or stopping runners preserves an untimed run. Records download alone does not start a clock in this variant. The duration is provisional. See the [brief](maps/briefs/alarm-escape.md).

Modular-mission Jaffa can now send a trailing guard around another entrance while an earlier rank engages you. Locked security doors can stop that route; ordinary closed doors can still be opened by guards. If there is no usable alternate, they keep their ordinary combat/cover behavior. [Behavior and limits](maps/modular-flanking.md).

The Goa'uld corridor kit now covers corners, junctions, wide passages and width
adapters: 14 of the compound's 20 rooms have built pieces. Floor runners continue
through branches; physical room sizes, doors and routes retain their existing
rules. See the [visual review and gallery](reviews/2026-11-18-sprint6-goauld-corridors.md).

A hidden development mission, **Two worlds** (`--mission two_worlds_dev`), loads the quiet SGC and the Goa'uld compound side by side without gate travel for coexistence tests and frame-cost measurement ([architecture](ARCHITECTURE.md#worlds-and-the-session)).

UAT inherits the Defense map, including props, friendly personnel, stairs and the lift. It disables automatic hostile gate activations and enemy waves; it is an exploration/test mode rather than an extraction run. Difficulty is disabled. The host owns mission/difficulty selection; clients receive it, including on joining and retry.

The base game on the development machine is `/home/flax/games/Team-Discovery-Channel/client`. To ensure that copy is loaded:

```sh
godot --path /home/flax/games/Team-Discovery-Channel/client -- --mission sgc_uat
```

An Orca worktree is a separate checkout. Updating either copy does not update the other, and changing files does not refresh an already running game. Restart after installing fixes. If you see the old flat control room or cannot select missions, check the launch path and branch/commit first.

## Multiplayer

The default ENet port is **7777/UDP**. A joining player enters the host address in the lobby and clicks **DIAL IN / CONNECT**. The host launches the selected mission.

For a dedicated server and client, use separate terminals:

```sh
godot --headless --path client -- --server --port 7777 --mission sgc_defense --difficulty medium
godot --path client -- --connect 127.0.0.1 --port 7777 --name Carter --class carter_tech
```

For a quiet dedicated server, replace the server mission with `--mission sgc_uat`; for the modular mission, use `--mission modular_extraction_uat`; for Timed Extraction, use `--mission goauld_timed_extraction`; for Alarm Escape, use `--mission goauld_alarm_escape`. A dedicated server has no host operative, so on the modular mission any connected operative's **Retry mission** restarts it for everyone. If the server stops, clients return to the lobby. Replace `127.0.0.1` with the server's address for another machine. The dedicated server bypasses the lobby; a normal client does not. Keep peers on compatible code. Selecting `--mission` on a joining client does not override the server.

## Default controls

Bindings can be changed in **TACTICAL CONTROLS & FIELD MANUAL** in the lobby or with **F1 / ESC** during a mission. Prompts follow your bindings; the defaults below assume no remapping.

| Action | Default |
| --- | --- |
| Move / sprint / crouch | WASD or arrows / Shift / C or Ctrl |
| Fire / aim down sights / reload | Left mouse / hold right mouse / R |
| Interact; hold for revive or repair | E |
| Give reserve ammunition to aimed teammate | B |
| Primary / secondary | 1 / 2 |
| Claymore / ballistic shield / smoke | 3 / 4 / 5 |
| Class gadget or nearby-body drag / dedicated drag toggle | G / H |
| Cycle C4 timer mode | T |
| Squad wheel / context ping | Hold Q or M4 / tap Q or M4; MMB quick ping |
| Zoom | Mouse wheel |

While holding ADS, hold Q/M4, move the mouse to a squad-wheel slice, then release Q/M4 to issue the order without releasing ADS. The center deadzone cancels. Rebinding conflicts offer Swap, Replace or Cancel. ESC cancels input capture; RESET DEFAULTS restores defaults. Held actions reject mouse-wheel pulses. Settings persist in Godot's `user://keybindings.cfg`.

To share ammunition, aim at a standing teammate within **3 metres** and press **B**.
Both active weapons must use the same ammunition: MP5/M9 share 9×19 mm, P90 uses
5.7×28 mm, and M249 uses 5.56×45 mm. Staff and Zat energy weapons cannot share.
Each press gives up to one recipient magazine from your reserve, capped by your
stock and their reserve capacity; loaded magazines stay intact. The aimed prompt
shows the amount or a reason such as incompatible ammunition, full reserve or a
reload. Walls block transfers. Both participants receive confirmation after the
server accepts it. Sharing is unavailable while incapacitated, traveling or after
the mission result. The binding follows remapping in the field manual.

## Floors, stairs and shutters

The main floors are Level 28 at 0 m, Level 27 at 5.5 m, and Level 26 at 11 m. The Level 28 control room has a 1.5 m raised floor, with sealed glass overlooking embarkation. Reach it by the side/rear stairs; there is no direct embarkation-to-control-room doorway. The corner spiral connects operations to briefing. Service stairs provide other vertical routes. Level 25 is not playable.

Inside the lift, press **E** away from a specific control to open the floor picker. Select Level 28, 27 or 26. Alternatively, aim at the individual cabin button and press **E**. Travel takes about three seconds per floor, plus door operation. The current/moving picker choices are disabled; calls made during transit can queue. The rider should remain on the cabin floor, including the full Level 26→28 descent.

The control-room window and briefing-room window have separate shutter consoles. Toggle the console in the room whose window you want to seal. Side blast doors use their own consoles. These operations are server controlled and replicated.

## Defense and the buffer-lockout objective

| Difficulty | Requirements before outbound dialing |
| --- | --- |
| Easy | At least three cleared incursions. |
| Medium | Three cleared incursions and the lab-ROM computer upgrade. |
| Hard | Medium requirements plus iris repair during an active incoming breach. |

Incoming windows last 38 seconds by default, with 20-second recharge periods. Pressure continues while objectives remain incomplete. A valid outbound dial reserves the gate against a competing incoming sequence. Complete seven chevrons and the four-beat GDO authorization, then extract through the authorized outbound gate.

**DIALING BUFFER LOCKED** means retrieve the clean ROM from the Level 28 laboratory, return to the control-room dialing computer and hold interact for the upload. It is a mission objective, not a system error. Its notice and upload progress appear in the objective HUD. They must not open a permanent dialing overlay. An approved dialing session opens its own panel; cancelling the interaction closes it.

If the old undismissable lockout panel is still on screen after updating, restart the running game to load the fix. Report the mission, difficulty, floor, exact message and action that triggered any recurrence. For map gaps, include the two connecting rooms, direction of travel and a screenshot if available; the [enclosure rule](maps/sgc.md#indoor-enclosure-rule) covers structural closure, while visual review covers rendering.
