# Repository agent instructions

For modular level creation, inspection, themes or repair, first read [the shared AI authoring guide](docs/maps/ai-level-authoring.md). Use `python3 tools/level_authoring.py`; discover capabilities before selecting IDs. Native LevelLayout `.tres` resources are authoritative. Preserve user-authored work and report unsupported requirements instead of inventing gameplay or geometry.

For community 3D assets (weapons, props, materials), follow [the community asset integration playbook](docs/assets/community-asset-playbook.md): licence gate, staging outside `client/`, the recipe-driven packer, cosmetic wrappers that leave gameplay anchors untouched, and the evidence a draft PR needs.
