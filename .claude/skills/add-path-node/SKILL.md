---
name: add-path-node
description: Add a node to the Path (the Waves route bought with Cores), or a new kind of Path effect. Use when asked to add, design or change a Path node, branch or effect.
---

# Add a Path node

Read `path/CLAUDE.md` first.

1. **Pick or make its effects.** Existing kinds: `StatEffect` (one player stat by a share,
   through PlayerStats) and `EconomyEffect` (shop upgrade price multiplier, extra Cores per
   boss). A new kind is a small `extends PathEffect` script in `path/` that overrides the hooks
   it needs. A hook that isn't in `PathEffect` yet: add it there (returning "no change"), add it
   up in `PathTree`, and read it where it applies. Host-only effects (damage, Cores) run on the
   host; anything `simulate()` reads must be worked out from the owned mask on every peer, like
   `PlayerLoadout._apply` does with `stat_bonuses`.
2. **Write the node** as `path/data/<name>.tres` (a `PathNode`): `display_name`, a one-line
   `description` with its numbers, `branch`, `tier`, `core_cost` (1 for tier 1, 2 for tier 2,
   3 for tier 3 and capstones), `requires` (earlier tiers), `excludes` (one side is enough),
   `effects` as sub-resources.
3. **Append it** to `path/data/path_tree.tres` `nodes`. Never reorder: nodes travel by index.
   At most 64 (`PathTree.MAX_NODES`).
4. **Tests:** the effect's numbers in `tests/path/test_path_effects.gd` (a new effect kind gets
   its own test), and `test_starter_branch_data`-style checks if a branch changes. A new effect
   that changes the network format (it shouldn't) bumps `Handshake.PROTOCOL`.
5. Run `.\tools\check.ps1 -Changed` (smoke C and D) and add the node to `docs/PROGRESS.md`.
