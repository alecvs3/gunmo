# path/: the Path (Waves)

A run-long route of nodes in branches, bought with **Cores** (a scarce second currency). At most
one step per break, deeper nodes need earlier ones, some nodes lock each other out, and nothing
can be undone. Recipe: `add-path-node`.

## Key files
| File | Job |
|---|---|
| `path_node.gd` | One node: name, description, branch, tier, `core_cost`, `requires`, `excludes`, `effects` |
| `path_tree.gd` | Every node in a fixed order (at most 64), and the owned nodes' effects added up |
| `path_effect.gd` | Base effect: hooks that change nothing (`stat_bonus`, `shop_price_multiplier`, `extra_boss_cores`) |
| `stat_effect.gd`, `economy_effect.gd` | A player stat through PlayerStats' multipliers; shop discount and extra Cores per boss |
| `path_progress.gd` | One player's Path: owned mask, Cores, whether this break's step is used |
| `path_rules.gd` | Pure rules: can this player take this node now, taking it, a new break, Cores paid |
| `data/*.tres` | The nodes and `path_tree.tres`. Append new nodes; never reorder (they travel by index) |

## Rules that aren't obvious
- **Nodes travel by index:** bit i of the owned mask is `PathTree.nodes[i]`, in the request and
  the player snapshot. Appending is safe; reordering or removing breaks saved masks and old peers.
- **The host decides** (rule 1): `WaveMode` turns `EventBus.path_step_requested` into
  `REQUEST_PATH`, `modes/waves/wave_path.gd` checks it with `PathRules` and pays Cores. Clients
  only use PathRules to show what can be taken.
- **A step needs a break** (`Phase.BREAK`, not the lobby). An early call never starts a break,
  so that break's step is skipped.
- **Effects that change `simulate()`** (move speed, fire rate, reload) are worked out from the
  owned mask in `PlayerLoadout._apply`, on the host and in the owner's prediction alike.
- `excludes` works both ways: listing it on one of the two nodes is enough.
- Numbers belong in the node's `.tres` (rule 6); Core payouts in `MatchSettings`.

## Tests
`tests/path/`, `tests/ui/test_path_text.gd`, the layout test, and smoke D (a client takes
Fortitude over the network).
