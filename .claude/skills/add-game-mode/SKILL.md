---
name: add-game-mode
description: Add a new game mode (like Waves or Gun Game). Use when asked to create a new mode or match type.
---

# Add a game mode

Area: **shared** for the base and Main, otherwise whoever owns the mode. This is a big change:
plan first and wait for an OK.

1. **Pure rules first:** a `RefCounted` class in `modes/<mode>/` with no nodes or networking,
   fully unit-tested in `tests/modes/<mode>/`. See `modes/gun_game/gun_game_ladder.gd` and
   `modes/waves/wave_flow.gd`.
2. **The mode node:** `modes/<mode>/<mode>_mode.gd` + `.tscn`, extending `GameMode`
   (`modes/game_mode.gd`). Copy `modes/gun_game/gun_game_mode.tscn` for the node layout (it has
   the `NetEntity`, kind MATCH). Override what you need: `_start()`, `restart()`,
   `_on_peer_joined()`, `_on_ready_changed()`, `_on_player_killed()`, `_on_request()`.
   Everything runs on the host. Set `state` and call `publish_state()`.
3. **Settings:** new tuning goes in `MatchSettings` (`modes/match_settings.gd`) as an
   `@export_group`. Create `modes/data/<mode>_match.tres` with `mode_scene` set to the new scene.
4. **Spawning:** add the scene to `_spawnable_scenes` of `ModeSpawner` in `main.tscn` (shared;
   keep the diff to that one line). `tests/test_project_consistency.gd` fails if you forget.
5. **UI:** add a `MatchNetState.ModeKind` value
   (`shared/network/states/match_net_state.gd`) for its layout, and an entry in `MODES` in
   `ui/main_menu.gd` (Yusuf's area). The HUD, scoreboard and results choose a layout by
   `mode_kind` and never by mode class (rule 7). New mode fields in `MatchNetState` follow the
   `add-networked-field` recipe and bump `Handshake.PROTOCOL`.
6. **Smoke test:** a scenario in `tests/net/` that extends `tests/net/smoke_script.gd` and plays a
   quick match to the end with a host and a client (copy `tests/net/gun_smoke.gd`, with a quick
   `.tres` in `tests/net/data/`). Add it to `tests/net/run_smoke.ps1`.
7. Add the mode's files to `tools/check_scope.json` (with a smoke scenario for it), run `.\tools\check.ps1 -Smoke` (a new mode is a big change), add a section to `docs/PROGRESS.md`, and write
   `modes/<mode>/` notes into `modes/CLAUDE.md`.
