# SW-2 — Goa'uld Personal Shield & Countermeasures

## Design Goal

Goa'uld personal shields (canonical velocity-gated kinetic barriers worn by Goa'uld commanders and shock-guard officers) stop high-velocity projectiles and must be overcome through deliberate tactical countermeasures, perception/stealth interaction, and squad coordination (`GDD.md`, `master-development-roadmap.md`).

---

## 1. Velocity-Gated Defence & Suppression Immunity

While `GoauldPersonalShield.is_active()` is true (`enabled and not is_overloaded and energy > 0.0` while the wearer is standing and alive/unstunned/undowned):

- **Fast ballistic fire (`"bullet"`, `"50cal_heavy"`)**:
  - Blocked cleanly (`0` HP damage, `0` shield energy drained).
  - Emits `shield_deflected(source, damage_type, impact_pos)`, increments `deflect_count`, and triggers an amber-gold shell flare + impact spark FX.
- **Gunfire suppression immunity**:
  - `JaffaAI.can_be_suppressed()` returns `false` while `has_active_shield()` is true; near-misses and direct gunfire cannot pin an actively shielded officer behind cover.

---

## 2. Perception & `MissionAlert` Interaction

The personal shield is integrated directly with `JaffaPerception` and `MissionAlert`:

| Event on Shielded Jaffa | Damage / Shield Effect | Sentry Perception (`Profile.SENTRY`) | Compound `MissionAlert` |
|---|---|---|---|
| **Ballistic / .50 cal deflection** (`"bullet"`, `"50cal_heavy"`) | `0` HP damage, deflected | Immediately transitions unaware/suspicious sentry to `ALERTED` at attacker position and spreads 1-hop squad alert | Escalates `CALM` → `SEARCHING` (alarm runner may break for console) |
| **Silent rear stealth takedown** (`"stealth_takedown"`, `[E]`/`[F]` behind unalerted sentry) | Bypasses shield completely; instant lethal | Drops sentry silently before shouting; `awareness_level` stays `UNAWARE`; no 1-hop spread | Remains `CALM` (undetected) |
| **Close-quarters slow flank melee** (`"melee_slow_flank"`) | Bypasses shield; `150.0` HP damage (1-hit lethal on `140 HP` Horus officer) | If lethal on an unalerted sentry, silent bypass with no alert spread; non-lethal flank alerts target & 1-hop | Remains `CALM` on silent lethal kill; `SEARCHING` if survived/alerted |
| **Frontal slow melee** (`"melee_slow"`) | Bypasses shield; `65.0` HP damage | Alerts target (`ALERTED`, 1-hop) and emits `2.5 m` melee noise | Escalates `CALM` → `SEARCHING` |
| **Zat'nik'tel overload** (1st Zat shot on active shield) | Overloads shield immediately (`6.0 s` lockout, `0` HP stun on 1st shot) | Immediately alerts an unaware sentry (`ALERTED`, 1-hop); 2nd Zat shot while overloaded stuns cleanly | Escalates `CALM` → `SEARCHING` (2-beat loud break vs quiet stealth takedown) |
| **Ma'Tok Staff plasma** (`"plasma"`) | `55.0` shield drain/hit (`2` hits overload shield for `6.0 s`, `3rd+` hits deal full HP damage) | Immediately alerts target (`ALERTED`, 1-hop) | Escalates `CALM` → `SEARCHING` |
| **Explosives** (`"c4_explosion"`, `"claymore_shrapnel"`) | Instant shield overload (`6.0 s`) + `50%` concussive HP bleed-through | Alerts surviving target (`ALERTED`, 1-hop) + blast noise radius | Escalates `CALM` → `SEARCHING` |
| **Environmental vortex / ring crush** (`"kawoosh_vortex"`, `"ring_crush"`) | Bypasses shield | Target killed immediately | Unchanged |

---

## 3. Shield Lifecycle, Visuals & Multiplayer Contract

- **Visual signature**: While active, `GoauldPersonalShield` renders a translucent amber-gold Fresnel barrier (`SphereMesh` radius `0.72 m`, height `2.15 m`, `goauld_personal_shield.gdshader`) and warm gold `OmniLight3D`. The aura disappears when overloaded, stunned, downed, dead, or stood down.
- **Overload & recharge**:
  - Full overload sets `energy = 0.0`, `is_overloaded = true`, `overload_timer = 6.0 s`. After `6.0 s` on a live unstunned wearer, the shield restores to `100.0` energy and emits `shield_restored`.
  - Partial drain (1st Staff plasma hit) starts a `3.5 s` recharge delay timer before regenerating at `35.0 / s`.
- **Authority & Late Join**:
  - `GoauldPersonalShield` runs server-authoritative (`set_multiplayer_authority(1)`) and synchronizes `has_personal_shield` + full monotonic-revision snapshots via `SGCNetworkManager.mission_rpc(..., &"sync_shield_state", ...)` and `request_shield_snapshot` (mirroring `HealthComponent.gd`).
- **Stand-down**:
  - `JaffaAI.stand_down()` freezes `PersonalShield` and hides the barrier visuals at mission conclusion.

---

## 4. Operative Close-Quarters Slow Melee

To guarantee every operative class has a direct non-stealth countermeasure against shielded Jaffa even in open alarm combat:

- Action `"melee"` (default `[F]`, rebindable via `KeybindingManager`) executes a server-validated close-quarters slow melee/knife strike (`PlayerController3D.try_melee_strike`, range `2.2 m`, cooldown `0.85 s`, forward arc).
- **Frontal strike**: `65.0` HP (`"melee_slow"`), bypassing the kinetic shield.
- **Side/rear flank strike** (`is_flanking_target()`): `150.0` HP (`"melee_slow_flank"`), bypassing the kinetic shield and dropping an unalerted target cleanly.
- If the target satisfies `can_be_taken_down_by(self)`, pressing `[F]` (or `[E]`) performs the canonical silent rear stealth takedown.

---

## 5. Mission & Wave Placement

- `MissionPatrol`: `@export var shock_guard := false`, `@export var personal_shield := false` (applied to rank `0` patrol lead in `ModularMission`).
- `MissionReinforcement`: `@export var personal_shield := false` (applied to reinforcement group lead in `MissionAlert`).
- Authored deployments:
  - `goauld_mothership_objective.tres`: `patrol_bridge` uses a shielded Horus Bridge Commander (`shock_guard = true`, `personal_shield = true`).
  - `goauld_infiltration.tres` & `goauld_alarm_escape.tres`: `reinforce_second` Horus shock squad lead deploys with `personal_shield = true`.
  - `WaveManager` (SGC Gate Room): on Medium/Hard difficulty, wave 3+ lead Shock Guard deploys with a personal shield.
