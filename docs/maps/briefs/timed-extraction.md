# Sprint 2 — timed extraction brief

An explicit standalone variant, **Goa'uld Infiltration — Timed Extraction**, reuses the existing compound, objectives, patrols, alarm and generator-controlled command security. Ordinary infiltration and two-world travel remain untimed.

1. Sabotage the generator to release command security, as today.
2. Download the command records. This starts one **180-second extraction window** and the notice “RECORDS ACQUIRED — EXTRACTION WINDOW STARTED”. The duration is configurable mission data and provisional pending human play.
3. Return all standing operatives to the existing extraction marker before the deadline. The existing mission-result path awards success. Expiry uses the same path for failure, with “EXTRACTION WINDOW EXPIRED” in the debrief.

The server owns a monotonic real-time deadline. Pause menus do not extend it. Clients display a locally interpolated estimate, refreshed from the host four times per second; they cannot start, extend or expire the authoritative timer. Late join gets the remaining window, not a new duration. Only live starts show the notice. A final result stops the timer and hides the countdown. Retry creates fresh state; leaving destroys it.

This sprint consumes only objective completion → start timer, alongside the existing door release. One countdown per definition. No new layout, geometry, timer bonuses, alert/room conditions, parallel objectives or travel-specific timed rules are introduced. Tests use private copies with shorter durations; the shipped resource stays at 180 seconds.
