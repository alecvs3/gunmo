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
| `waves/wave_path.gd` | The Path in a match (host): Cores per wave, boss and solo bonus, one step per break, taking a node (rules in `path/path_rules.gd`) |
| `waves/revive_rules.gd` | Downed and revive: bleed-out timer, revive bar, range, interruption (`waves/downed_players.gd` applies it on the host) |
| `waves/wave_report.gd` | The difficulty curve on paper, from the same functions (`tools/wave_report.ps1`) |
| `waves/difficulty/difficulty_model.gd` | How hard a wave is, 0–10, from its enemies' own numbers (see "Wave difficulty" below) |
| `waves/difficulty/difficulty_curve.gd` | The difficulty each wave aims for |
| `waves/difficulty/counter_profile.gd` | Which damage type works best against a planned wave (see "Counters" below) |
| `waves/progression/progression_run.gd` | A run on paper for one team: progression and strain each wave (see "Progression and strain" below) |
| `gun_game/gun_game_ladder.gd` | Kills per tier, the last tier, who has won |
| `gun_game/spawn_protection.gd` | Spawn protection: how long, and that firing ends it |

Put new rules in a pure class like these and test it. The mode node should only wire it up.

## Wave difficulty
Every wave gets a score on a 0–10 scale (a duo's wave 25 ≈ 13: it can go past 10) that depends only on its enemies and
modifiers, never on the players. Recipe: `tune-wave-difficulty`.
- **Stats:** `enemies/enemy_stats.gd` turns an `EnemyData` into numbers per second (effective
  health, melee and ranged damage, healing, summons, speed × size). Each attack reports its own
  part in `add_stats()`. Splits count as part of the enemy, and boss phases count by the share
  of health they cover.
- **Axes:** `waves/difficulty/*_axis.gd`, listed in `waves/data/difficulty_model.tres`. Each
  reads the wave's summed stats (`WaveSheet`) and its merged modifier:

| Axis | Raw amount | Modifiers that move it |
|---|---|---|
| H Toughness | effective health against Kinetic damage (flat armor and traits) | health, damage taken, added traits (their Kinetic part) |
| M Melee | contact damage per second | |
| P Pressure | Σ speed × body size / 140 | speed |
| R Ranged | projectile damage per second that can hit (fans and rings: shots inside a 30° cone) | |
| S Sustain | support pulses (on 3 average allies) + regeneration + summons, health per second | regeneration, toughness |

- **Score:** each axis scores `10 × (raw / reference) ^ 0.7`; the difficulty is the weighted
  length `√(Σ weight × score² / Σ weight)`. Every axis at its reference = 10.
- **Target:** `WaveSchedule.difficulty` (a `DifficultyCurve`): a straight trend, boss waves a
  little above it, the two waves after a boss a little below, `overrides` to pin a wave.
- **Bigger teams, bigger waves:** every target is multiplied by `DifficultyCurve.player_scale`
  for the number of players (bots count; 2 players = 1.0, the default shape is (n / 2)^0.7).
  WaveMode passes `level.players().size()` to the spawner and the forecast, and builds the
  forecast again when that number changes in the lobby or a break, so it stays exact. More
  enemies also means more bounty to share.
- **Building a wave** (`WaveComposer.plan`): the boss first, then every minimum the schedule's
  `rules` ask for, then random types (`spawn_weight`, pulled toward the role shares by each
  type's solo difficulty) while the wave stays under target + tolerance, until it reaches the
  target. A few tries keep the closest. Modifiers are picked first (their own seed), so a Tough
  wave needs fewer enemies. `max_enemies` is a safety stop.
- **Rules** (`WaveSchedule.rules`, for a wave range): `EnemyLimit` (min/max count of one type),
  `AxisLimit` (an axis's share of the difficulty: a max, or a min that makes a themed wave).
- `tools/wave_report.ps1` prints the target, the difficulty, every axis and the bounty of each
  wave. Each axis also says how much of it a team handles (`handled`, for "Progression and
  strain" below).

## Progression and strain
How strong a team is likely to be at each wave, on paper, in the difficulty's own units, so the
two compare: a team at 6 handles a wave of 6. Tools only: nothing in a match reads it.
`.\tools\balance_graphs.ps1` prints one team's table and opens `tools/balance/graphs.html`
(difficulty, progression, strain, where the strain comes from, credits, loadouts; ×10, so 0–100).
Each team is measured against the waves built for its own size.
- **Inputs** (`waves/data/progression/`): `PlayerArchetype` (aim, uptime, dodge, counter skill,
  down chance, how they spend: greedy, saver, cheapest), `TeamSetup` (members, pets, calls early),
  and `ProgressionModel` (every estimate that turns a loadout into axis units, the `StrainCurve`
  and the reference team). The graphs also run each archetype at 1–4 players.
- **A run** (`waves/progression/progression_run.gd`): the wave report's rows (the waves the host
  spawns for that seed). Each wave: the team's `TeamPower` (`PlayerPower` per player, `PetPower`
  for its pet, team effects counted once) is scored on every axis by `DifficultyAxis.handled()`
  and the model's own formula (`DifficultyModel.handled_scores`); then `EconomyModel` pays it
  (bounty by kill share, clear bonus and interest by the chance of standing, early call, Cores),
  then `Buyer` takes a Path step and shops (ShopRules, the game's prices).
- **Strain** = Σ over axes of the wave's share × (wave score − team score), ×10: only the axes a
  wave pushes on count. `StrainCurve` says what it should be: a steady line to a knee
  (wave 16 by default), then a climb that bends upward to the last wave (+20: hard; +10 is
  "hard but fair", +30 an average team almost always loses). The room under the top of its
  band is what later randomness can spend.
- **The default waves are fitted to it:** the `DifficultyCurve` (first, last, power,
  last_wave_bonus; boss_bonus 0.6 keeps boss waves above the next on the steep climb) and `player_scale` in `default_waves.tres` were chosen so average teams of
  1–4 follow the StrainCurve (late waves weighted more, wave 25 most; seeds 1–3). Refit after
  changing the progression estimates, the economy or the strain target.
- **The estimates are a first guess.** `clear_seconds` and `sustain_share` are design intent;
  the melee and ranged hit shares and `kite_bodies` were set so a fresh team scores the same on
  M, R and P as on toughness. Real play data should replace them (the knobs are all in
  `progression_model.tres`).

## Counters
Every hit has a damage type (`DamageType.Type`: Kinetic, Pierce, Blast, Arcane;
`shared/components/damage_type.gd`) and every enemy has traits (`EnemyTrait`,
`enemies/data/traits/`: Armored, Swarm). Recipe: `add-damage-type`.
- **Where traits come from:** the enemy's own `EnemyData.traits`, plus the wave's
  `WaveModifier.adds_traits` (the Armored modifier adds the Armored trait).
  `ModifierCatalog.combined()` keeps every added trait (a trait twice counts twice: a Tank in an
  Armored wave takes 0.36 Kinetic, as before); the catalog's damage taken floor (0.4) holds for
  every type.
- **On the host:** `ChaserEnemy._apply_modifiers` gives its `HealthComponent` one multiplier per
  type (`EnemyTrait.profile`); `HitboxComponent.hit(damage, source, push, damage_type)` passes
  the type. Guns take it from `WeaponData.damage_type` (the rocket launcher is Blast, hit and
  explosion), pets from `PetData.damage_type` (the Wizard is Arcane). It is never sent.
- **The score stays Kinetic-based** (`EnemyData.taken(KINETIC)`, `WaveModifier.taken(KINETIC)`),
  so it never depends on the players' guns.
- **`CounterProfile`** (`waves/difficulty/counter_profile.gd`, pure), for the forecast:
  - `CounterProfile.of(planned: Array[EnemyData], modifier: WaveModifier) -> CounterProfile`:
    `planned` from `WaveComposer.plan`, `modifier` from `ModifierCatalog.combined(mask)`.
  - `multiplier(damage_type: int) -> float`: what hits of that type are multiplied by against
    this wave, weighted by each enemy's health (splits included). 1.0 = a plain enemy.
  - `best_type(min_edge: float = 0.0) -> int`: the type with the highest multiplier; Kinetic
    unless another beats Kinetic's by more than `min_edge` (ties go to the earlier type).
    `DamageType.name_of(type)` gives its name ("Bring: Pierce").
  - Every default Armored wave (seed 1) gives Pierce with `min_edge` 0.1 (tested).

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
`_on_request()`. `WaveMode` uses `REQUEST_BUY` (2), `REQUEST_CALL` (3, early-call vote) and `REQUEST_PATH` (4, take a Path node). Check every request against the rules.
Host-to-client events: `GunGameMode.KILL_FEED_TOPIC` (3) reports each kill to everyone
(ProjectileSystem uses topic 1).

## Recipes
`add-game-mode`, `add-wave-modifier`, `tune-wave-difficulty`, `add-damage-type`, `add-client-request` (in `.claude/skills/`).

## Tests
`tests/modes/`, plus smoke scenarios C (wave loop), D (shop) and E (gun game).
A change to wave balance (the curve, enemy numbers, modifiers, rules) pastes `.\tools\wave_report.ps1`
before and after into its PR.
