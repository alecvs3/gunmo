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
| `waves/wave_budget.gd` | How many points a wave may spend, and which enemies it buys (role shares, modifier threat) |
| `waves/wave_schedule.gd` | How waves grow (data in `waves/data/default_waves.tres`) |
| `waves/modifier_catalog.gd` | Which modifiers a wave gets (`pick_for_wave`), sent as a one-byte mask |
| `waves/early_call.gd` | Calling the next wave early: when it's allowed (only up to `MatchSettings.early_call_last_wave`, 5 by default), the vote, the bonus (per enemy of the called-away wave still alive: `WaveSpawner.alive_count`) |
| `waves/revive_rules.gd` | Downed and revive: bleed-out timer, revive bar, range, interruption (`waves/downed_players.gd` applies it on the host) |
| `waves/wave_report.gd` | The difficulty curve on paper, from the same functions (`tools/wave_report.ps1`) |
| `gun_game/gun_game_ladder.gd` | Kills per tier, the last tier, who has won |
| `gun_game/spawn_protection.gd` | Spawn protection: how long, and that firing ends it |

Put new rules in a pure class like these and test it. The mode node should only wire it up.

## MatchNetState fields by mode
`shared/network/states/match_net_state.gd` holds both modes' fields in one 26-byte state.
That's kept on purpose: splitting it would change the network format for little gain.
- **Both:** `mode_kind`, `phase`, `phase_end_tick`, `ready_count`, `player_count`, `living_count`, `winner_id`
- **Waves:** `wave`, `total_waves`, `enemies_left`, `modifier_mask`, `shop_open`, `call_open`, `call_votes`
- **Gun Game:** `ladder_length`, `kills_per_tier`, `final_tier_kills`

## Requests
Clients ask through `NetChannel.send_request(topic, data)`. `GameMode._on_request_received`
ignores peers without a player, handles `REQUEST_READY` (1) and passes the rest to
`_on_request()`. `WaveMode` uses `REQUEST_BUY` (2) and `REQUEST_CALL` (3, early-call vote). Check every request against the rules.
Host-to-client events: `GunGameMode.KILL_FEED_TOPIC` (3) reports each kill to everyone
(ProjectileSystem uses topic 1).

## Recipes
`add-game-mode`, `add-wave-modifier`, `add-client-request` (in `.claude/skills/`).

## Tests
`tests/modes/`, plus smoke scenarios C (wave loop), D (shop) and E (gun game).
A change to wave balance (budgets, enemy numbers, modifiers) pastes `.\tools\wave_report.ps1`
before and after into its PR.
