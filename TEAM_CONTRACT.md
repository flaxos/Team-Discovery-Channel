# THE SGC GROUNDING PACT: ANTI-ABANDONMENT COVENANT
### Team Discovery Channel // Cheyenne Mountain Complex

We, the founding crew of **Team Discovery Channel**:
* **flaxos** (🚀)
* **Scotty** (⚡)

solemnly pledge on this date to uphold this pact so that we **ship and enjoy our Stargate co-op game** rather than leaving another idea in the dev graveyard.

---

### Article I: The Core Covenant
> **"Gameplay & Stargate Feel Before Bespoke Art"**
We agree that all decisions bend to this rule. No asset, no refactor, and no clever feature shall delay having 2 players walk through the gate, shoot Jaffa, and dial home under fire.

### Article II: Target Timeframe
The original planning target was **The 2-Week SGC Vertical Slice (Recommended)**. It records the founding scope constraint, not a rolling deadline for later refactors. Current implementation and acceptance work are tracked in [ROADMAP.md](ROADMAP.md). Keep new work scoped to a playable co-op slice.

### Article III: The Scope Creep Defense
1. **The Shared Prefab Rule**: All mission types must share the exact same Stargate, DHD, weapons, and Jaffa AI components.
2. **The Fun Test**: If an idea cannot be prototyped with graybox primitives in under 2 hours with our coding agents, it waits for Milestone 2.
3. **No 2 AM Netcode Rewrites**: We stick to simple, rock-solid networking. No writing bespoke rollback netcode from scratch.

### Article IV: The Friday SGC Playtest
Every Friday at 8:00 PM, we hop on Discord, dial the gate, play whatever build exists, log bugs, and have fun.

---
**Signed by the Squad:**
- [x] flaxos
- [x] Scotty


### Current quality and documentation gates

Preserve the shared gate/combat/AI components, server authority and working controls. Indoor map changes must pass enclosure and continuous capsule traversal checks; navigation resources must match collision. UI notifications must not strand gameplay in an orphan session panel. Visual replacements retain gameplay collision and documented bounds.

Use [testing and UAT](docs/TESTING.md) for current automated and human checks, [the map contract](docs/maps/sgc.md) for authoring, and [the documentation index](docs/README.md) for maintained instructions. Keep historical audits dated and generated voting snapshots separate from delivered-game status. These engineering gates support the original pact; they do not change the squad's signed commitments or playtest schedule.
