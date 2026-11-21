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

## Folder layout
```
autoloads/   EventBus, NetworkManager, GameSettings
shared/      components (HealthComponent, HitboxComponent, ...), shared utils
player/      player scene, input, movement
weapons/     weapon scenes and logic; data in weapons/data/*.tres
upgrades/    upgrade logic; data in upgrades/data/*.tres
enemies/     enemy scenes and AI (wave mode)
bots/        bot AI (gun game); profiles in bots/profiles/*.tres
modes/       GameMode base, WaveMode, GunGameMode, waves/data/*.tres
ui/          HUD, menus, lobby
levels/      maps
tests/       automated tests, mirroring the folders above
```

## Architecture rules
1. **The host decides everything that matters:** damage, health, kills, spawns, wave state, upgrades, ladder progress and all bot and enemy AI. Clients send only inputs and requests, and the host checks them. Never trust a client to report damage or kills.
2. **Every gameplay feature must work in multiplayer from the start.** Test it with 2 instances running (Debug → Customize Run Instances). There is no "add networking later".
3. **Bots and enemies run only on the host** and are replicated like any other networked entity.
4. **Use components rather than deep inheritance.** Players, bots and enemies are built from the same `HealthComponent`, `HitboxComponent` and `WeaponComponent`.
5. **Systems talk through `EventBus` signals** (`enemy_killed`, `wave_started`, `player_died`, ...). No `get_node()` paths that reach into another scene.
6. **Tuning numbers live in Resources (`.tres`), never in code:** `WeaponData`, `UpgradeData`, `EnemyData`, `WaveConfig`, `BotProfile`, `MatchSettings`.
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
- **Stay in your lane.** Say so before editing files in the other developer's area (see Ownership).
- **Edit scene files carefully.** Keep `.tscn` diffs minimal and explain them. Never edit `project.godot`, `.import` files or `export_presets.cfg` without asking.
- **Test logic.** Add or update tests for damage math, upgrade stacking, wave budgets, ladder progression and bot decisions.
- **Before calling something done,** run the tests and the linter and report the results honestly. If you couldn't run the game or test multiplayer, say so.
- **Ask instead of guessing.** Don't add addons or dependencies without asking.
- **Explain what you did** in plain words, so both developers understand every change.
- **Update `docs/PROGRESS.md`** in the same PR when a feature is finished or a known limitation is added or fixed.

## Ownership
- **Alex (Dev A):** player, weapons, upgrades, gun game ladder
- **Yusuf (Dev B):** enemies, waves, bot AI, HUD and menus
- **Shared (both review):** `autoloads/`, `shared/`, `modes/` base class, `main.tscn`, `project.godot`

## Commands
- **All checks:** `.\tools\check.ps1` (import, GUT, lint, format; prints only failures). Add `-Smoke` for the multiplayer smoke test (run it for any networking change), `-Fix` to format first, `-Only tests|lint|format|smoke` for one step.
- Single steps: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`, `gdlint .`, `gdformat --check .`, `.\tests\net\run_smoke.ps1 -Godot <console exe>`

## Glossary
- **Tier:** one gun on the gun game ladder.
- **Wave budget:** the points a wave can spend on enemies. Each enemy type has a cost, and the budget grows each wave.
- **Wave modifier:** a rule applied to a wave, such as "armored", "fast" or "regenerating".
- **Bot profile:** a Resource that sets a bot's skill (reaction time, aim error, awareness, playstyle).
