# player/: the player character

Owner: **Alex**. One scene, `player.tscn`, is every human and every bot (bots have a negative
peer id and a `BotController`). It's built from components: health, hitbox, weapon, knockback,
wallet, score, loadout.

## Who runs what
| Peer | What happens |
|---|---|
| Host | Takes the next `InputCommand` (human: `CommandQueue`; bot: `BotController`) and runs `Player.simulate()`. That result is the truth |
| Owner client | `player_prediction.gd` runs `simulate()` on its own input at once, then rewinds to the host's state and replays unconfirmed commands |
| Other clients | `NetEntity` shows interpolated snapshots through `player_net_sync.gd` |

## Key files
| File | Job |
|---|---|
| `player.gd` | Wiring, `simulate()` (one tick of movement, knockback and firing), respawn and death |
| `player_motor.gd` | The movement rule (pure, tested) |
| `player_net_sync.gd` | The player's snapshot: `capture` (host), `show_state` (others), `restore` (owner) |
| `player_timeline.gd` | Host: where a remote human's own inputs put them, for fair dodging |
| `player_input_source.gd` | Owner: keys and mouse → one `InputCommand` per tick. `scripted` lets tests drive it |
| `player_prediction.gd`, `own_player_drawing.gd` | Your own player: instant response, corrections eased out |
| `player_loadout.gd` | Weapon index and upgrade levels → effective stats (`upgrades/player_stats.gd`) |
| `player_camera.gd`, `player_spectate.gd` | Camera, and watching a teammate while down |
| `fair_view.gd` | Every window shape sees the same world box (`PlayerData.view_size`): the camera's zoom, and where `ui/view_mask.gd` puts its bars |
| `player_look.gd`, `character_look.gd`, `looks/` | The sprite per weapon pose and where its barrel ends |
| `data/default_player.tres` | `PlayerData`: speed, health, knockback, camera |

## Rules that aren't obvious
- **`simulate()` must be deterministic.** The host and the owner run it on the same commands
  and must get the same result. Only use the command, the player's own state, and stats from
  the loadout. No randomness without a seed from the command (see `WeaponComponent.shot_seed`),
  no wall-clock time, nothing only the host knows.
- **`replaying` is true when the owner re-runs a command after a correction.** Don't fire or
  show effects twice.
- **A new field the owner must rewind to goes in the snapshot** (see the `add-networked-field`
  recipe). Otherwise prediction drifts and the player rubber-bands.
- **Nothing here may depend on the window.** Window size, UI scale and frame rate change only
  how things are drawn (`tests/test_no_window_dependence.gd` checks it).
- Shots start at the drawn barrel: `CharacterLook.muzzle_for(pose)`, rotated by the aim.

## Tests
`tests/player/`, plus `tests/upgrades/test_player_stats.gd` for stat stacking. Movement or firing
changes also need `.\tools\check.ps1 -Smoke` (scenario A checks prediction and host agreement).
