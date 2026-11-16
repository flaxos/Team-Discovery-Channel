# Shared level-authoring workflow

For modular map work, use [docs/maps/ai-level-authoring.md](docs/maps/ai-level-authoring.md) and `python3 tools/level_authoring.py`. This is the same interface used by Codex and Antigravity. Discover live capabilities, author native `.tres` layouts transactionally, validate/build/preview, and preserve existing user work. Do not infer capabilities from faction names or introduce unsupported gameplay.

For community 3D assets (weapons, props, materials), follow [the community asset integration playbook](docs/assets/community-asset-playbook.md): licence gate, staging outside `client/`, the recipe-driven packer, cosmetic wrappers that leave gameplay anchors untouched, and the evidence a draft PR needs.

# Workspace and delivery

Follow [AGENTS.md](AGENTS.md): use the user's existing checkout. Do not create extra worktrees, clones, sibling project directories or project copies unless explicitly requested. A user request to commit and merge is authorization to finish that task on `main` after checks; do not ask again or leave it on a preview branch.
