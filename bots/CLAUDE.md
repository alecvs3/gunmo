# bots/: bot players

Owner: **Yusuf**. A bot is a normal `player/player.tscn` with a negative peer id. The host adds
a `BotController` to it (`Level.spawn_bot`). Clients see bots exactly like human players.

## Split
| File | Job |
|---|---|
| `bot_controller.gd` | Host only. Gathers facts each tick (targets, line of sight, paths) and builds an `InputCommand` like a human's |
| `bot_brain.gd` | Pure decisions, unit-tested: choose a target (`Candidate`), lead a moving target (`intercept`), turn the aim, when to fire, where to move |
| `bot_profile.gd`, `profiles/*.tres` | Skill: reaction time, aim error, turn speed, fire cone, awareness, distance, strafing |

## Rules that aren't obvious
- **Bots only make input commands.** They never touch health, position or the weapon
  directly, so everything a bot does goes through the same `Player.simulate()` and netcode as a
  human. That's what keeps them fair and replicated.
- A new decision goes in `bot_brain.gd` as a pure function with a test. The controller only
  gathers facts for it.
- Targets are any hittable hitbox on another team (`LagCompensator.hitboxes()`): other
  players in Gun Game, enemies in Waves. No mode checks (rule 7).
- Bots lead remote humans from where those players' own screens have them
  (`Player.timeline_lead()`), and their bullets use fair dodging (`weapons/timeline_hits.gd`).
- A new skill number goes in `BotProfile` as an `@export`, with values in each profile `.tres`.

## Tests
`tests/bots/test_bot_brain.gd`, plus smoke scenarios E (gun game) and H (fairness at 160 ms).
