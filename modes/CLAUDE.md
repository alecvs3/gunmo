# modes/: the rules of a match

No fixed owner for now (root `CLAUDE.md`, Ownership). The base class `game_mode.gd` is
reviewed by both developers.

## How a mode works
- One mode node lives under `Main/ModeContainer` on every peer. The host picks it from
  `MatchSettings.mode_scene` (`modes/data/*.tres`, or `--match`), and Main's `ModeSpawner`
  replicates it.
- **Host:** runs the rules and keeps `state` (a `MatchNetState`) up to date, then calls
  `publish_state()`. **Clients:** receive `state` through its `NetEntity` (newest only) and send
  requests.
- Everything else (HUD, scoreboard, results) listens to EventBus `match_state_changed` and never
  asks which mode is running (rule 7). `MatchNetState.mode_kind` only picks the UI layout.
- Phases: `LOBBY`, `BREAK`, `ACTIVE`, `VICTORY`, `DEFEAT`. Ready-up works in LOBBY and BREAK.
- Hooks a mode overrides: `_start()`, `restart()`, `_on_ready_changed()`, `_on_peer_joined()`,
  `_on_player_killed()`, `_on_request()`, `_prepare_new_bot()`, `_on_bot_removed()`.
- Bots: the base fills empty slots up to `bot_fill_to` (`_sync_bots()`); a mode calls it when
  peers join or leave.

## Pure rule classes (unit-tested, no nodes)
| File | Rules |
|---|---|
| `waves/wave_flow.gd` | The wave mode's state machine |
| `waves/wave_composer.gd` | Builds each wave to hit its target difficulty (`waves/wave_draft.gd` is one try; rules in `waves/difficulty/`) |
| `waves/wave_schedule.gd` | How waves grow (data in `waves/data/default_waves.tres`) |
| `waves/wave_forecast.gd` | The next wave ahead of time (exact: `WaveComposer.plan_wave` from the match seed), shown in the lobby and breaks |
| `waves/modifier_catalog.gd` | Which modifiers a wave gets (`pick_for_wave`), sent as a one-byte mask |
| `waves/early_call.gd` | Calling the next wave early: when it's allowed (only up to `MatchSettings.early_call_last_wave`, 5 by default), the vote, the bonus (per enemy of the called-away wave still alive: `WaveSpawner.alive_count`) |
| `waves/interest.gd` | Interest on held credits after each clear bonus: per step held, up to a cap (`MatchSettings.interest_*`) |
| `waves/revive_rules.gd` | Downed and revive: bleed-out timer, revive bar, range, interruption (`waves/downed_players.gd` applies it on the host) |
| `waves/wave_report.gd` | The difficulty curve on paper, from the same functions (`tools/wave_report.ps1`) |
| `waves/difficulty/difficulty_model.gd` | How hard a wave is, 0–10, from its enemies' own numbers (see "Wave difficulty" below) |
| `waves/difficulty/difficulty_curve.gd` | The difficulty each wave aims for |
| `gun_game/gun_game_ladder.gd` | Kills per tier, the last tier, who has won |
| `gun_game/spawn_protection.gd` | Spawn protection: how long, and that firing ends it |

Put new rules in a pure class like these and test it. The mode node should only wire it up.

## Wave difficulty
Every wave gets a score from 0 to 10 (wave 25 ≈ 10) that depends only on its enemies and
modifiers, never on the players. Recipe: `tune-wave-difficulty`.
- **Stats:** `enemies/enemy_stats.gd` turns an `EnemyData` into numbers per second (effective
  health, melee and ranged damage, healing, summons, speed × size). Each attack reports its own
  part in `add_stats()`. Splits count as part of the enemy, and boss phases count by the share
  of health they cover.
- **Axes:** `waves/difficulty/*_axis.gd`, listed in `waves/data/difficulty_model.tres`. Each
  reads the wave's summed stats (`WaveSheet`) and its merged modifier:

| Axis | Raw amount | Modifiers that move it |
|---|---|---|
| H Toughness | effective health | health, damage taken |
| M Melee | contact damage per second | |
| P Pressure | Σ speed × body size / 140 | speed |
| R Ranged | projectile damage per second that can hit (fans and rings: shots inside a 30° cone) | |
| S Sustain | support pulses (on 3 average allies) + regeneration + summons, health per second | regeneration, toughness |

- **Score:** each axis scores `10 × (raw / reference) ^ 0.7`; the difficulty is the weighted
  length `√(Σ weight × score² / Σ weight)`. Every axis at its reference = 10.
- **Target:** `WaveSchedule.difficulty` (a `DifficultyCurve`): a straight trend, boss waves a
  little above it, the two waves after a boss a little below, `overrides` to pin a wave.
- **Building a wave** (`WaveComposer.plan`): the boss first, then every minimum the schedule's
  `rules` ask for, then random types (`spawn_weight`, pulled toward the role shares by each
  type's solo difficulty) while the wave stays under target + tolerance, until it reaches the
  target. A few tries keep the closest. Modifiers are picked first (their own seed), so a Tough
  wave needs fewer enemies. `max_enemies` is a safety stop.
- **Rules** (`WaveSchedule.rules`, for a wave range): `EnemyLimit` (min/max count of one type),
  `AxisLimit` (an axis's share of the difficulty: a max, or a min that makes a themed wave).
- `tools/wave_report.ps1` prints the target, the difficulty, every axis and the bounty of each
  wave.

## MatchNetState fields by mode
`shared/network/states/match_net_state.gd` holds both modes' fields in one 34-byte state.
That's kept on purpose: splitting it would change the network format for little gain.
- **Both:** `mode_kind`, `phase`, `phase_end_tick`, `ready_count`, `player_count`, `living_count`, `winner_id`
- **Waves:** `wave`, `total_waves`, `enemies_left`, `modifier_mask`, `shop_open`, `call_open`, `call_votes`,
  and in the lobby and breaks the forecast (`forecast`, `forecast_boss`, `forecast_modifier_mask`,
  `forecast_scores`: one byte per difficulty axis, so adding an axis changes the format)
- **Gun Game:** `ladder_length`, `kills_per_tier`, `final_tier_kills`

## Requests
Clients ask through `NetChannel.send_request(topic, data)`. `GameMode._on_request_received`
ignores peers without a player, handles `REQUEST_READY` (1) and passes the rest to
`_on_request()`. `WaveMode` uses `REQUEST_BUY` (2) and `REQUEST_CALL` (3, early-call vote). Check every request against the rules.
Host-to-client events: `GunGameMode.KILL_FEED_TOPIC` (3) reports each kill to everyone
(ProjectileSystem uses topic 1).

## Recipes
`add-game-mode`, `add-wave-modifier`, `tune-wave-difficulty`, `add-client-request` (in `.claude/skills/`).

## Tests
`tests/modes/`, plus smoke scenarios C (wave loop), D (shop) and E (gun game).
A change to wave balance (the curve, enemy numbers, modifiers, rules) pastes `.\tools\wave_report.ps1`
before and after into its PR.
