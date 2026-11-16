# Repository agent instructions

For modular level creation, inspection, themes or repair, first read [the shared AI authoring guide](docs/maps/ai-level-authoring.md). Use `python3 tools/level_authoring.py`; discover capabilities before selecting IDs. Native LevelLayout `.tres` resources are authoritative. Preserve user-authored work and report unsupported requirements instead of inventing gameplay or geometry.

For community 3D assets (weapons, props, materials), follow [the community asset integration playbook](docs/assets/community-asset-playbook.md): licence gate, staging outside `client/`, the recipe-driven packer, cosmetic wrappers that leave gameplay anchors untouched, and the evidence a draft PR needs.

## Workspace and delivery

Use the checkout supplied by the user. Do not create additional Git worktrees, clones, sibling project directories, alternate checkouts or project copies unless the user explicitly requests them. Work, run the game and test in this checkout; use the existing ignored `build/` area for generated artifacts and the established external staging area for raw asset intake. Ordinary source/content folders needed by the task are allowed. Preserve unrelated unfinished work in other existing checkouts.

When the user asks to commit and merge, that authorizes committing the current task's complete changes and merging them to `main` after the required checks. Do not stop for another confirmation or leave the result on a preview branch. Update the remote and finish this checkout on `main`. Raw owner-download archives remain local intake files, not repository deliverables; commit the prepared assets and provenance instead.

These workspace and delivery rules supersede older worktree and draft-only instructions in project guides and handoff prompts.
