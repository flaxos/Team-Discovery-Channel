# SW-3 — Canonical Specialised Enemies & Goa'uld System Lord Boss

## Design Goal

Introduce distinct, Stargate SG-1–canonical Goa'uld and Jaffa combat roles that meaningfully change how squads approach rooms, cover, alarms, and firefights across modular compounds, the Ha'tak mothership, outdoor gate sites, and SGC Defense — culminating in a **Goa'uld System Lord Boss** equipped with a **Personal Shield (`GoauldPersonalShield`)** and **Kara Kesh (Ribbon / Hand Device)** (`ROADMAP.md` Workstream I, `master-development-roadmap.md` SW-3, `GDD.md`).

All specialist roles stay strictly in-canon (no scoped human-style snipers). Placeholder visuals are used for the boss and role trims so models can be swapped later without touching combat logic, collision, or navigation.

---

## 1. Canonical Combat Roles (`JaffaAI.combat_role`)

`combat_role: String` is replicated on `JaffaAI` via `MultiplayerSynchronizer` (default `"trooper"`).

| Role ID | Canon Archetype | Base HP | Speed (Walk / Run) | Tactical Behaviour | Counterplay |
|---|---|---:|---|---|---|
| `"trooper"` | **Jaffa Guard / Shock Guard** | `90` / `140` | `4.2` / `5.5` (`4.8` / `5.8` Shock) | Baseline Serpent/Horus guard (unchanged). | Standard stealth, cover, suppression. |
| `"officer"` | **First Prime / Jaffa Officer** | `135` (`160` Shock) | `4.5` / `5.8` | **Squad Command & Alarm Coordination**: 1) Expanded squad alert radius (`30 m` vs `22 m`). 2) **Rally Command** (`7.5 s` cooldown in combat): clears gunfire suppression on nearby allied Jaffa within `12 m`, grants `2.5 s` rally resolve, and relays target position to nearby comrades. 3) **Priority Alarm Caller**: prioritized by `MissionAlert` to reach alarm consoles and raises the alarm `25%` faster (`0.75x` console raise time). | Eliminate or take down the Officer first to break squad coordination and slow alarm calls; disable alarm consoles beforehand. |
| `"heavy"` | **Jaffa Heavy / Staff Cannon Trooper** | `220` | `3.2` / `4.0` | **Heavy Armoured Suppression**: 1) **Frontal Heavy Plate**: `30%` damage reduction (`0.70x`) against frontal ballistic fire (`"bullet"`, `"50cal_heavy"`), fully bypassed by side/rear flanking, plasma, explosives, Zat, and slow melee. 2) **Suppression Resistant**: requires `5` incoming ballistic rounds within the pressure window (vs `2` for troopers) and holds suppression only `0.8 s`. 3) **3-Bolt Heavy Staff Cannon Volley**: fires a rapid 3-bolt suppressive burst (`0.14 s` cadence, `34` HP/bolt, `24 m/s`). | Flank around cover to negate frontal plate, use Zat stun, Ma'Tok Staff plasma, C4/Claymore, or close-quarters flank melee. |
| `"grenadier"` | **Jaffa Shock Grenadier** | `115` | `4.4` / `5.5` | **Anti-Cover Flusher (Goa'uld Shock Grenade)**: Carries `3` canonical spherical **Goa'uld Shock Grenades** (`GoauldShockGrenade.tscn`, `9.5 s` cooldown, `4.5 m`–`18 m` throw envelope). Telegraphs and lobs a rolling/pulsing orb toward operatives holding cover or chokepoints (`1.45 s` fuse). Detonation (`4.5 m` radius, blocked by solid walls) deals `10–25` concussive damage and applies **2.4 s flash-concussion disorientation** (`0.55x` movement slow + HUD flash + trauma shake). | Reposition outside the `4.5 m` glowing blast radius during the `1.45 s` fuse, break LOS behind solid wall corners, or focus the Grenadier early. |
| `"goauld_lord"` | **Goa'uld System Lord Boss** (`GoauldSystemLord.tscn`) | `320` | `3.9` / `5.0` | **Personal Shield + Kara Kesh (Hand Device) + Command Presence**: See §2 below. | Coordinate shield-break countermeasures (Zat, Staff plasma, C4/Claymore, slow `[F]` melee) and use solid pillars/cover to break Kara Kesh LOS. |

---

## 2. Goa'uld System Lord Boss (`GoauldSystemLord.tscn`)

Built on `JaffaAI` (`combat_role = "goauld_lord"`, `is_shock_guard = true`, `has_personal_shield = true`, `HealthComponent.max_health = 320.0`, `PersonalShield.max_energy = 140.0`) so all existing navigation, perception, alert, multiplayer replication, and SW-2 shield systems integrate seamlessly.

### Personal Shield Interaction
- Starts with an active **140-energy `GoauldPersonalShield`** blocking high-velocity ballistic rounds (`"bullet"`, `"50cal_heavy"`, `"thrown_knife"`) and gunfire suppression.
- Countermeasures match SW-2:
  - **Zat'nik'tel**: 1st shot overloads the shield immediately (`6.0 s` vulnerability window); 2nd shot while overloaded stuns the boss.
  - **Ma'Tok Staff plasma**: drains `55` energy/hit (`3` hits overload `140` energy).
  - **C4 / Claymore**: immediate shield overload + `50%` concussive HP bleed-through.
  - **Close-quarters slow melee (`[F]`)**: bypasses the shield (`65` frontal / `150` flank).
  - **Stealth / Ambush rule**: a System Lord cannot be one-shot deleted by a rear `stealth_takedown` (`can_be_taken_down_by()` returns `false` for bosses); sneaking behind a boss instead allows a devastating `150 HP` `"melee_slow_flank"` bypass ambush that initiates the encounter.

### Kara Kesh (Goa'uld Hand Device) Attacks
1. **Telekinetic Shockwave Push** (`range <= 10.5 m`, `65°` forward arc, `cooldown = 7.0 s`, `0.55 s` golden gauntlet charge telegraph):
   - Checks clear solid-wall LOS (`collision_mask = 1`) to each standing operative/Airman in the cone.
   - Deals `32.0 HP` (`"kara_kesh_push"`), delivers a `13.5 m/s` outward horizontal knockback impulse (forcing turret dismount if mounted), and triggers golden shockwave VFX + camera trauma on all peers.
2. **Focused Neural / Energy Beam** (`range 4.0 m`–`16.0 m`, `cooldown = 8.5 s`, `0.65 s` charge telegraph → up to `2.2 s` sustained channel):
   - Channels a visible golden energy beam from `KaraKeshMount` to the locked operative.
   - Ticks `14.0 HP` (`"kara_kesh_beam"`) every `0.35 s` and applies `0.55x` movement slow + subtle golden flash while unobstructed LOS holds.
   - **Immediate cancel / counterplay**: ducking behind solid cover breaks LOS and terminates the beam; overloading the boss's shield, stunning, downing, or killing the boss cancels the channel immediately.
3. **Command Presence**: Rallies nearby Jaffa escorts within `14.0 m` (clearing suppression).

---

## 3. Replication, HUD & Mission Placement

- **Replication**:
  - `JaffaAI.combat_role`, `boss_display_name`, and `kara_kesh_state` replicate via `MultiplayerSynchronizer` (`EnemySpawner` includes `GoauldSystemLord.tscn`).
  - `GoauldShockGrenade.tscn` spawns under `FieldKitDeployments` via `GadgetSpawner` using `FieldKitNetwork`, cleaned up on mission end/retry.
  - `PlayerController3D` receives server-authoritative `receive_external_impulse` and `receive_disorientation` RPCs (also applied directly in local/host sessions).
  - `TacticalHUD` displays a live **Boss Health & Shield Bar** whenever a living `goauld_lord` is active in the player's world, plus a non-blocking `ShockFlashOverlay` for shock grenades and Kara Kesh hits.
- **Authored Deployments**:
  - **Ha'tak Mothership Objective** (`goauld_mothership_objective.tres`): Bridge Commander promoted to **Goa'uld System Lord Boss** (`patrol_bridge`), Heavy Staff Cannon Trooper in Engineering (`patrol_engineering`), First Prime Officer on upper deck (`patrol_upper`).
  - **Goa'uld Infiltration & Alarm Escape** (`goauld_infiltration.tres`, `goauld_alarm_escape.tres`): First Prime Officer leads the Checkpoint patrol, Shock Grenadier patrols upper Command, Heavy Staff Cannon Trooper leads the first reinforcement group, and Shielded Horus Officer leads the second reinforcement group.
  - **Outdoor Gate Site** (`outdoor_gate_site.tres`): First Prime + Shock Grenadier guard the bunker command patrol; Heavy Trooper leads bunker reinforcements.
  - **SGC Defense** (`WaveManager.gd`): Wave 2 introduces First Prime Officers & Shock Grenadiers on Medium/Hard; Wave 3 adds Heavy Staff Cannon Troopers alongside the shielded Horus Officer; Wave 4 Climax Breach spawns a Goa'uld System Lord Boss at the Gate Room.
