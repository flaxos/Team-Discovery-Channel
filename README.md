# Team Discovery Channel
> **Collab multiplayer game project with the agentic lads.**

Welcome to the **Team Discovery Channel** game dev repository!
We built a dedicated **Alignment & Voting Engine** to defeat scope creep and stay grounded.

---

## 🎮 Game Status & Alignment
* **Game Concept**: Deep Space Expedition Co-op
* **Alignment Status**: Compiled & Grounded
* **Documents Generated**:
  - [**BOOTSTRAP_PROMPT.md**](./BOOTSTRAP_PROMPT.md) - The complete agentic kickoff prompt for Claude Code, Antigravity, or Codex to scaffold the game.
  - [**GDD.md**](./GDD.md) - Game Design Document (Core Loop, Netcode Blueprint, Feature Matrix).
  - [**ROADMAP.md**](./ROADMAP.md) - Sprint 0 through 2 milestones with role division.
  - [**TEAM_CONTRACT.md**](./TEAM_CONTRACT.md) - The Grounding Pact & Anti-Abandonment rules.

---

## 🛠️ Alignment & Voting Web App
To run the live voting and prompt compiler app:

```bash
cd alignment-app
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) to cast votes, propose custom mechanics, or regenerate the bootstrap prompts!

---

## 👥 The Squad
* **flaxos** (🚀) - AI Agent Orchestrator, Core Gameplay & Systems, Combat Feel & Juice
* **Scotty** (⚡) - Multiplayer & Netcode, Game Feel & Combat, Weapons & Perks Scripter

*Built with passion, caffeine, and agentic AI.*

## Current Godot game

The SGC co-op game is in `client/` (Godot 4.4.1). Run `godot --path client` to open the lobby.
Run `python3 tools/run_godot_tests.py` for the takeover regression suites; this runner rejects script/engine errors and timeouts even if a suite prints a success banner.

Sprint plans and review notes are in `docs/plans/` and `docs/reviews/`.
The alignment API binds to localhost by default. Remote repository exports require `ALIGNMENT_EXPORT_TOKEN` and an `Authorization: Bearer …` header; set `ALIGNMENT_HOST` explicitly when remote API access is intended.

Sprint 20 controls: open Tactical Controls from the lobby or press F1/ESC in a mission, then click a binding button. Conflicts offer Swap, Replace or Cancel. ESC cancels capture; RESET DEFAULTS restores the standard layout. Bindings persist in Godot's `user://keybindings.cfg`. Mouse-wheel pulses are available for discrete actions; held actions require a key or mouse button. Hold Q/M4 while aiming to select a squad order without releasing ADS.
