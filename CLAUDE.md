# [GAME NAME] — Project guide for Claude

## What this is
A multiplayer shooter made in Godot by two developers: **Alex** (Dev A) and **Yusuf** (Dev B). Bots fill the other slots.

Game modes:
- **Waves (co-op):** players team up against 25 waves that get harder each time. Players upgrade their weapons between waves, and clearing wave 25 wins. Late waves should demand real strategy, which comes from systems that combine with each other, not from hand-scripted scenarios.
- **Gun Game (free-for-all):** players and bots climb a weapon ladder. Each kill target moves you to the next gun, and the first to finish the ladder wins. The ladder length, kills per tier and win condition all come from `MatchSettings`.

**2D, top-down.** Players aim with the mouse (twin-stick on a controller) and move with WASD. Use 2D nodes only (`CharacterBody2D`, `Area2D`, `NavigationAgent2D`, `TileMapLayer`).

Not decided yet (ask, don't assume): [art style] · [target platform]

## Tech
- Godot **4.7.2**. Only use APIs from this version. If you're not sure an API exists in it, say so.
- GDScript with static typing everywhere (`var hp: int`, `func f(x: float) -> void`).
- Multiplayer uses Godot's high-level multiplayer API (ENet) with a **host-authoritative listen server**.
- Tests: GUT 9.7.1 (`addons/gut/`, config in `.gutconfig.json`). Lint and format: gdtoolkit (`gdlint`, `gdformat`).

## System map
Folders marked * have their own `CLAUDE.md` with the details. Read it before working there.
```
autoloads/       EventBus (signals only), NetworkManager (connection, clock, channel, replicator,
                 lag compensator, stats), GameSettings (name, fullscreen)
shared/network/* netcode: clock, channel, snapshots, prediction history, lag compensation
shared/components/ HealthComponent, HitboxComponent, WeaponComponent, Knockback, Wallet, Score,
                 DisplayDelay: the parts players, bots and enemies are built from; DamageType
                 (Kinetic, Pierce, Blast, Arcane: what enemy traits resist or fear)
shared/feedback/ looks and sounds only: HitFeedback (hit flash, damage numbers), FeedbackSystem (numbers,
                 death bursts, world sounds), FeedbackData (tuning, camera shake), SoundData +
                 SoundPlayback (which sound for each moment; files in assets/kenney_sounds/ and
                 assets/pixabay_sounds/; each gun's WeaponData.fire_sound)
player/*         Player scene: input, movement (PlayerMotor), prediction, snapshot (PlayerNetSync)
weapons/*        WeaponData, Shot, Bullet, ProjectileSystem, rockets (Explosion), fair dodging
                 (TimelineHits)
shared/          WindowRules (window modes, min size, UI scales), Groups
upgrades/        ShopCatalog, UpgradeData (stats), PlayerStats (each gun's per-level amounts),
                 ShopRules
enemies/         Chaser (one scene for every EnemyData), enemies/data/*.tres, behaviours/
                 (movement + attack parts an EnemyData combines), EnemyTrait
                 (enemies/data/traits/: how much of each damage type an enemy takes)
bots/*           BotController (host only) + BotBrain (pure decisions), bots/profiles/*.tres
pets/*           Waves pets: PetData/PetCatalog (pets/data/*.tres), PetLook, PetFollower
path/*           Waves Path: PathNode/PathTree (path/data/*.tres), PathEffect kinds, PathRules
                 (one step per break, bought with Cores; owned nodes on PlayerLoadout)
modes/*          GameMode base, WaveMode + modes/waves/ (difficulty score in modes/waves/difficulty/,
                 team progression and strain on paper in modes/waves/progression/),
                 GunGameMode + modes/gun_game/, MatchSettings
ui/*             menus, HUD, scoreboard, shop, results, F3 overlay; HudMenu (base of every pop-up menu)
levels/          maps: MapData (levels/data/*.tres, picked by MatchSettings.map) → a Level scene
                 (where things spawn, never when); MapCheck validates every map
tests/           GUT tests mirroring the folders; tests/net/ = multiplayer smoke scenarios
```
**One tick on the host** (60 Hz): NetChannel reads packets first → each Player takes its next
InputCommand (human: CommandQueue, bot: BotController) and runs `simulate()` → enemies, bullets
and modes run → Replicator captures every NetEntity and sends snapshots → NetChannel sends last.
**On a client:** your own player is predicted (PlayerPrediction runs `simulate()` on your input
right away, then reconciles with the host's state); everything else is drawn from snapshots at
NetClock's render tick. **A shot:** `simulate()` fires → EventBus `shot_fired` (host) or
`shot_predicted` (owner) → ProjectileSystem spawns a Bullet → the host decides the hit and tells
everyone how the bullet ended.

**Recipes** (`.claude/skills/`): step-by-step checklists for adding a weapon, enemy, upgrade,
wave modifier, damage type or trait, Path node, tuning wave difficulty, networked field, client
request, pop-up menu or game mode. Use one when it fits.

## Architecture rules
1. **The host decides everything that matters:** damage, health, kills, spawns, wave state, upgrades, ladder progress and all bot and enemy AI. Clients send only inputs and requests, and the host checks them. Never trust a client to report damage or kills.
2. **Every gameplay feature must work in multiplayer from the start.** Test it with 2 instances running (Debug → Customize Run Instances). There is no "add networking later".
3. **Bots and enemies run only on the host** and are replicated like any other networked entity.
4. **Use components rather than deep inheritance.** Players, bots and enemies are built from the same `HealthComponent`, `HitboxComponent` and `WeaponComponent`.
5. **Systems talk through `EventBus` signals** (`enemy_killed`, `wave_started`, `player_killed`, ...). No `get_node()` paths that reach into another scene.
6. **Tuning numbers live in Resources (`.tres`), never in code:** `WeaponData`, `UpgradeData`, `EnemyData`, `WaveSchedule`, `WaveModifier`, `BotProfile`, `MatchSettings`.
7. **Mode logic stays inside `modes/`.** Shared systems never check which mode is running.
8. **Only the three autoloads listed above.** Ask before adding another.
9. **Networking follows `docs/NETCODE.md`:** the host decides, the owner predicts, others interpolate. Continuous state goes through `NetEntity` snapshots (never a continuous `MultiplayerSynchronizer`), player actions through `InputCommand`, one-off messages through `NetChannel` events. Keep `Player.simulate()` deterministic and bump `Handshake.PROTOCOL` when a network format changes.

## Code style
- `snake_case` for files, variables and functions, `PascalCase` for `class_name`, `UPPER_SNAKE` for constants.
- Signals are named in the past tense (`died`, `wave_cleared`, `tier_advanced`).
- Use `@export` for anything a designer might tweak.
- Keep functions short (about 40 lines at most) and give each script one job.
- No commented-out code, no unused code, and no `TODO` without an issue number (`# TODO(#42): ...`).

## How Claude should work here
- **Plan first.** For anything bigger than a small fix, list the files you'll touch and the approach, then wait for an OK.
- **Keep changes small:** one GitHub issue per branch, and say `Closes #N` in the PR.
- **Say what you're about to change.** There are no fixed areas yet (see Ownership), so before a big change name the systems it touches, in case the other developer is working there.
- **Follow the roadmap.** `docs/ROADMAP.md` lists the next milestones and their steps in order, each with how to test it.
- **Edit scene files carefully.** Keep `.tscn` diffs minimal and explain them. Never edit `project.godot`, `.import` files or `export_presets.cfg` without asking.
- **Test logic.** Add or update tests for damage math, upgrade stacking, wave difficulty, ladder progression and bot decisions.
- **Before calling something done,** run the checks the change needs (see "Which checks to run") and report the results honestly, including which smoke scenarios ran and why. If you couldn't run the game or test multiplayer, say so.

## Which checks to run
Run only what a change can break; run everything for a big change.
- **Docs only** (`docs/`, `README.md`): no checks, locally or in CI. Nothing reads them. Guides (`CLAUDE.md`, `.claude/skills/`) still run GUT, because `tests/test_guides.gd` checks the paths they name.
- **Always otherwise:** import, GUT, lint and format (`.\tools\check.ps1`, under a minute). They're cheap and catch most mistakes.
- **Smoke scenarios:** `.\tools\check.ps1 -Changed` picks them from the files this branch changes, using `tools/check_scope.json` (each folder → the scenarios that exercise it), and prints why. Docs-only changes run none. Use it while working and before a PR.
- **Everything** (`.\tools\check.ps1 -Smoke`) for a **big change**: netcode, autoloads, the player, `main.tscn`, `project.godot`, the mode base class, the check tools themselves, any file no rule covers, or more than 25 changed files. `-Changed` already picks "all" for these; run the full set yourself before calling one done. Add the `full-checks` label to such a PR.
- **CI** does the same: a docs-only pull request runs nothing (`paths-ignore` in `.github/workflows/checks.yml`), other pull requests run the scoped scenarios (or all of them with the `full-checks` label), and every push to main runs all of them, so a miss is still caught.
- **Timing scenarios (F, G, H) are unreliable with the Godot editor or a game open.** If one fails locally by a little, say so and let CI decide; don't loosen a budget for it.
- **New folder or scenario?** Add it to `tools/check_scope.json` in the same PR (`tests/tools/test_check_scope.gd` fails for a folder with no rule).
- **Ask instead of guessing.** Don't add addons or dependencies without asking.
- **Explain what you did** in plain words, so both developers understand every change.
- **Update `docs/PROGRESS.md`** in the same PR when a feature is finished or a known limitation is added or fixed.
- **Keep the guides current.** If a change makes a folder `CLAUDE.md`, a recipe or the system map above wrong, fix it in the same PR. `tests/test_guides.gd` fails when a file path a guide names no longer exists.

## Ownership
- No fixed areas for now: Alex and Yusuf both work anywhere. Areas may be assigned later; this section will say so.
- **Both review:** `autoloads/`, `shared/`, `modes/` base class, `main.tscn`, `project.godot`

## Commands
- **All checks:** `.\tools\check.ps1` (import, GUT, lint, format; prints only failures). Add `-Smoke` for the multiplayer smoke test (run it for any networking change; `-Scenarios A,E` for just those), `-Changed` to run only the smoke scenarios this branch needs (`-Base <ref>`, default `origin/main`), `-Fix` to format first, `-Only tests|lint|format|smoke` for one step. `-Smoke -Scenarios S` is the 10-minute soak test (opt-in: memory and node counts must not keep growing).
- **Wave report:** `.\tools\wave_report.ps1` (`-Seed N`, `-Players N`, `-Schedule res://...`) prints every wave's target and difficulty (each axis), bounty, enemies by type, health, peak alive and modifiers as a markdown table. Paste it before/after in any PR that changes wave balance.
- **Balance graphs:** `.\tools\balance_graphs.ps1` (`-Seed N`, `-Team res://...`, `-NoOpen`) runs every team through the waves on paper, prints one team's difficulty, progression, strain, income and loadout per wave, and opens `tools/balance/graphs.html`.
- Single steps: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`, `gdlint .`, `gdformat --check .`, `.\tests\net\run_smoke.ps1 -Godot <console exe>`

## Glossary
- **Tier:** one gun on the gun game ladder.
- **Wave difficulty:** a 0–10 score for a wave from its enemies' own stats (five axes: toughness, melee, pressure, ranged, sustain). Each wave is built to hit the target its curve sets, scaled by the number of players.
- **Wave modifier:** a rule applied to a wave, such as "armored", "fast" or "regenerating".
- **Damage type / trait:** every hit is Kinetic, Pierce, Blast or Arcane; an enemy's traits
  (Armored, Swarm) take more or less of each. Picking the type that beats the next wave is a counter.
- **Progression:** how strong a team is likely to be going into a wave, in the difficulty's units
  (0–10 inside, ×10 in the graphs), from its upgrades, gun, pet, Path and skill.
- **Strain:** how far a wave is above the team, on the axes that wave pushes on. Below 0 the team
  is ahead; the `StrainCurve` says what it should be.
- **Bot profile:** a Resource that sets a bot's skill (reaction time, aim error, awareness, playstyle).
