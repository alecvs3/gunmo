# bots/: bot players

Owner: **Yusuf**. A bot is a normal `player/player.tscn` with a negative peer id. The host adds
a `BotController` to it (`Level.spawn_bot`). Clients see bots exactly like human players.

## Split
| File | Job |
|---|---|
| `bot_controller.gd` | Host only. Gathers facts each tick (targets, line of sight, paths) and builds an `InputCommand` like a human's |
| `bot_brain.gd` | Pure decisions, unit-tested: choose a target (`Candidate`, weighed by danger), turn the aim (leading a moving target is `weapons/aim_lead.gd`), when to fire, where to move; co-op: regroup with the team, which downed teammate to revive |
| `bot_shopping.gd` | Pure: what a bot buys between waves (a dearer gun, else the cheapest upgrade); `WaveMode` sends it through the normal purchase path |
| `bot_profile.gd`, `profiles/*.tres` | Skill: reaction time, aim error, turn speed, fire cone, awareness, distance, strafing; smarts: dodge, cover, flanking, hunting |

## Rules that aren't obvious
- **Bots only make input commands.** They never touch health, position or the weapon
  directly, so everything a bot does goes through the same `Player.simulate()` and netcode as a
  human. That's what keeps them fair and replicated.
- A new decision goes in `bot_brain.gd` as a pure function with a test. The controller only
  gathers facts for it.
- Targets are any hittable hitbox on another team (`LagCompensator.hitboxes()`): other
  players in Gun Game, enemies in Waves. No mode checks (rule 7). Danger = an enemy's solo
  difficulty with the exponent undone (`BotBrain.danger_of`; 1 for a player), so bots focus
  Supports and bosses.
- **Teammates** = players on the bot's own team. Gun Game gives everyone a team of their own,
  so the co-op decisions (regroup, revive) simply find nobody there.
- Bots fill empty slots in both modes (`GameMode._sync_bots`, `MatchSettings.bot_fill_to`).
  In Waves they are ready whenever every human is.
- Bots lead remote humans from where those players' own screens have them
  (`Player.timeline_lead()`), and their bullets use fair dodging (`weapons/timeline_hits.gd`).
- A new skill number goes in `BotProfile` as an `@export`, with values in each profile `.tres`.

- Bots aim so the shot leaves the **barrel** on target (`BotBrain.barrel_aim`,
  `Player.muzzle_offset()`), dodge the host's live bullets (`Groups.BULLETS`), hide behind the
  level's respawn points when hurt, and hunt (`hunts`) by flanking the nearest opponent.

## Tests
`tests/bots/test_bot_brain.gd`, `test_bot_shopping.gd`, plus smoke scenarios C (co-op bots),
E (gun game, and the Hard-vs-Normal duel `botduel`) and H (fairness at 160 ms).
