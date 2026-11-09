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

For a quiet dedicated server, replace the server mission with `--mission sgc_uat`. Replace `127.0.0.1` with the server's address for another machine. The dedicated server bypasses the lobby; a normal client does not. Keep peers on compatible code. Selecting `--mission` on a joining client does not override the server.

## Default controls

Bindings can be changed in **TACTICAL CONTROLS & FIELD MANUAL** in the lobby or with **F1 / ESC** during a mission. Prompts follow your bindings; the defaults below assume no remapping.

| Action | Default |
| --- | --- |
| Move / sprint / crouch | WASD or arrows / Shift / C or Ctrl |
| Fire / aim down sights / reload | Left mouse / hold right mouse / R |
| Interact; hold for revive or repair | E |
| Primary / secondary | 1 / 2 |
| Claymore / ballistic shield / smoke | 3 / 4 / 5 |
| Class gadget or nearby-body drag / dedicated drag toggle | G / H |
| Cycle C4 timer mode | T |
| Squad wheel / context ping | Hold Q or M4 / tap Q or M4; MMB quick ping |
| Zoom | Mouse wheel |

While holding ADS, hold Q/M4, move the mouse to a squad-wheel slice, then release Q/M4 to issue the order without releasing ADS. The center deadzone cancels. Rebinding conflicts offer Swap, Replace or Cancel. ESC cancels input capture; RESET DEFAULTS restores defaults. Held actions reject mouse-wheel pulses. Settings persist in Godot's `user://keybindings.cfg`.

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
