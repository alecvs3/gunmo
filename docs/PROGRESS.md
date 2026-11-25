# Progress

Update this file in the same PR that finishes a feature or adds/fixes a known limitation.

## Milestone 1 — playable multiplayer core ✅ (merged)

Neither game mode existed yet; this was a test arena.

| Feature | Status | Where |
|---|---|---|
| Folder layout, `.gitignore`, Git LFS for png/wav/ogg | Done | repo root |
| Autoloads: EventBus, NetworkManager (host/join, port, peer list), GameSettings (empty) | Done | `autoloads/` |
| HealthComponent, HitboxComponent, WeaponComponent | Done, tested | `shared/components/` |
| WeaponData + pistol, PlayerData, EnemyData | Done | `weapons/`, `player/`, `enemies/` |
| Main menu: Host, Join (IP + port), Quit | Done | `ui/main_menu.tscn` |
| Networked player: WASD, mouse aim, hold to fire, R to reload | Done | `player/` |
| Bullets spawned by the host | Done; replaced by predicted shooting (netcode) | `weapons/` |
| Test enemy: chases nearest living player, contact damage, host-only AI | Done | `enemies/test_enemy.gd` |
| Test arena: floor, walls, 2 pillars, spawn points | Done | `levels/test_arena.tscn` |
| Debug enemy spawner (every 3 s, max 15) | Done | `levels/debug_enemy_spawner.gd` |
| Temporary respawn after 3 s | Done (to be replaced in M2) | `levels/test_arena.gd` |
| GUT tests (24) + gdlint/gdformat config | Done | `tests/`, `gdlintrc`, `gdformatrc` |

**Verified:** tests and lint pass; a headless host + client on one machine agreed on players,
health, ammo, enemies, bullets, death and respawn.

## Networking hardening ✅ (merged, issue #4)

| Feature | Status | Where |
|---|---|---|
| Join check (SceneMultiplayer auth): refuses different build/version and full lobbies, with a reason | Done, tested | `shared/network/join_gate.gd`, `handshake.gd`, `build_info.gd` |
| Faster drop detection (~6–8 s instead of up to 30 s), join timeout (8 s), Cancel button | Done | `autoloads/network_manager.gd`, `ui/main_menu.*` |
| Clear end reasons: host closed, connection lost, kicked, refused | Done | `autoloads/network_manager.gd` |
| Host can kick a peer with a reason (`NetworkManager.kick`) | Done (no UI yet) | `autoloads/network_manager.gd` |
| Ping counter top right, F3 details (all pings, loss, bandwidth, build id) | Done | `shared/network/ping_tracker.gd`, `ui/net_overlay.*` |
| Smoothing for remote players and enemies | Done; replaced by snapshot interpolation (netcode) | — |
| Esc menu: Resume / Leave match (host: end match for everyone) | Done | `ui/game_menu.*` |
| Dev launch args `-- --host [port]`, `-- --join ip[:port]` | Done, tested | `shared/network/launch_args.gd`, `main.gd` |
| Host validates client input (non-finite values ignored) | Done | `player/player.gd` |
| Network log lines (`[net hh:mm:ss] ...`) | Done | `shared/network/net_log.gd` |
| Network tuning in a Resource | Done | `shared/network/default_network_config.tres` |
| Three-process smoke test (host, client, wrong-build client) | Done | `tests/net/run_smoke.ps1` |

**Verified:** 56 GUT tests; smoke test passes; killing the host is detected by the client in ~6 s;
joining nobody fails after 8 s with a clear message; launch args host/join with no errors.

## Movement feel ✅ (merged, issue #6)

| Feature | Status | Where |
|---|---|---|
| Physics interpolation on: no more blur/ghosting on 120-180 Hz screens | Done | `project.godot` |
| Teleports (respawn, big network corrections) skip interpolation | Done | `player/`, `shared/network/` |
| Camera updates on physics ticks so it stays in step with the player | Done | `player/player.tscn` |
| Acceleration 0.12 s, deceleration 0.08 s, top speed 300 -> 220 px/s | Done, tested | `player/player_motor.gd`, `player/data/default_player.tres` |
| Client's own player glides instead of jumping to each update | Done; replaced by prediction (netcode) | — |

## Netcode foundation ✅ (merged, issues #10 #11 #7 #12 #13 #14 #8)

How it works and how to extend it: [NETCODE.md](NETCODE.md).

| Step | Feature | Status | Where |
|---|---|---|---|
| 1 (#10) | Instant aim: the gun follows the mouse every frame; aim angle sent in commands | Done | `player/player_input_source.gd` |
| 2 (#11) | Tick clock, numbered input commands with redundancy, host command budget (no speed hacks), NetChannel + network simulator (`--net-sim`) | Done, tested | `shared/network/` |
| 3 (#7) | Own-player prediction + reconciliation (rewind, replay, eased correction) | Done, tested | `player/player_prediction.gd`, `player/player.gd` |
| 4 (#12) | Snapshot interpolation; batched, MTU-split entity snapshots at 30 Hz | Done, tested | `shared/network/replicator.gd`, `snapshot_codec.gd`, `state_buffer.gd`, `net_entity.gd` |
| 5 (#13) | Predicted shooting: instant bullets/ammo, deterministic spread, host-confirmed; event-based ProjectileSystem | Done, tested | `weapons/` |
| 6 (#14) | Lag compensation (rewind ≤ 250 ms), swept hit tests (no tunnelling), teams | Done, tested | `shared/network/lag_compensator.gd`, `hit_geometry.gd` |
| 7 (#8) | Knockback: enemy contact, bullet hits, small wall bounce; predicted for the owner | Done, tested | `shared/components/knockback_component.gd` |
| extra | Dedicated server mode (`--dedicated`), F3 netcode stats | Done | `main.gd`, `ui/net_overlay.gd` |

**Verified:** 136 GUT tests; lint/format clean; smoke test (listen host + client with 80 ms
simulated lag + wrong-build client; dedicated server + shooter + observer) passed 5 of 5 runs:
own movement responds within 3 ticks under lag, position matches the host exactly after stopping,
~50% of shots at moving enemies confirmed as hits, remote players and bullets seen.

### Known limitations

- Players don't collide with each other. No friendly fire in co-op (by team).
- The host sees remote players move in small steps when their commands arrive unevenly.
- GUT prints Godot leak warnings at exit (the game itself shuts down cleanly);
  traced to engine/GUT shutdown order with the Replicator node, not to a runtime leak.

## Display smoothness ✅ (merged, issue #16)

| Feature | Status | Where |
|---|---|---|
| Camera moves every rendered frame, following the player's drawn position (no 60 Hz steps) | Done, measured | `player/player_camera.gd` |
| Adaptive V-Sync by default (no tearing while the game keeps up, never waits when it falls behind) | Done | `project.godot` |
| Less input delay: 2 swapchain images, agile input flushing, physics jitter fix off | Done | `project.godot` |
| GPU, API, V-Sync mode and refresh rate logged at start and shown in F3, warning on an integrated GPU | Done | `autoloads/game_settings.gd`, `ui/net_overlay.gd` |
| Frame-pacing measurement in a real window | Done | `tests/visual/frame_pacing.gd` |

**Measured** (RTX 4060, 180 Hz, 4 runs): the screen scrolls on every frame (0% frozen frames,
before: 67%), frame-to-frame unevenness 7–13% (≈0.1 px), player perfectly still on screen.
**Not yet verified:** how it feels to play; other monitors and PCs (Yusuf's).

## Milestone 2 — wave loop ✅ (merged, issues #18–#24)

| Issue | Feature | Status | Where |
|---|---|---|---|
| #18 | GameMode base (replicated next to the level), Level spawn API, MatchSettings + `--match`, MatchState entity, client→host requests, F = ready | Done, tested | `modes/game_mode.gd`, `levels/level.gd`, `shared/network/states/match_net_state.gd` |
| #19 | Grunt / runner / brute as data on one chaser scene; WaveSchedule (25 waves, budget curve); seeded budget planner; spawner away from players | Done, tested | `enemies/`, `modes/waves/` |
| #20 | Wave loop: lobby → waves → breaks (skip when all ready) → victory after 25 / defeat when all down; host restart | Done, tested | `modes/waves/wave_flow.gd`, `modes/wave_mode.gd` |
| #21 | Down players spectate a teammate (click to switch), revive at the break, late joiners spectate until the break | Done, tested | `player/player_spectate.gd`, `modes/wave_mode.gd` |
| #22 | Enemy pathfinding around walls and pillars (navigation baked on the host) | Done, tested | `levels/test_arena.tscn`, `enemies/chaser.gd` |
| #23 | HUD (health, ammo/reload, wave, enemies left, countdown, ready, banners) + results screen | Done, tested, checked in a window | `ui/hud.*`, `ui/results_screen.*` |
| #24 | Wave smoke scenario + GitHub Actions CI (lint, format, GUT, smoke) on every PR | Done | `tests/net/wave_smoke.gd`, `.github/workflows/checks.yml` |

**Verified:** 179 GUT tests; lint/format clean; all three smoke scenarios pass (a host and a
client play a quick match through ready-up, two waves, victory, restart and defeat, and see the
same phases); a real host runs waves; the HUD checked in screenshots; a fresh clone imports.
**Not yet verified:** a full 25-wave match by people (balance).

### Known limitations

- The spectate line still says "a teammate", not the name.
- The command-line `--import` crashes now and then on an already-imported working copy right
  after files changed (a Godot 4.7.2 cache bug; running it again works, a fresh clone
  imports fine). If the editor crashes once after pulling, open it again.

## Milestone 3 — upgrades and combat depth ✅ (merged, issues #26–#31)

| Issue | Feature | Status | Where |
|---|---|---|---|
| #26 | SMG, shotgun (6 seeded pellets), rifle (pierces 2); one weapon slot, weapon index in the snapshot; per-hit confirmations | Done, tested | `weapons/`, `player/player_loadout.gd` |
| #27 | Credits: bounty to the killer, wave-clear bonus (50 + 10 × wave) to everyone standing, starting credits, reset on restart | Done, tested | `shared/components/wallet_component.gd`, `modes/wave_mode.gd` |
| #28 | 7 upgrades (damage, fire rate, magazine, reload speed, move speed, max health, knockback); levels add up per stat; levels in the snapshot for prediction | Done, tested | `upgrades/` |
| #29 | Shop: host-checked purchase requests; panel in lobby/breaks, B toggles | Done, tested, checked in a window | `upgrades/shop_rules.gd`, `ui/shop_panel.*` |
| #30 | Wave modifiers: armored, fast, regenerating; one from wave 6, two from wave 16; enemies tinted; HUD shows them | Done, tested | `modes/waves/` |
| #31 | Shop smoke scenario (D) and docs | Done | `tests/net/shop_smoke.gd` |

**Verified:** 208 GUT tests; lint/format clean; all four smoke scenarios pass. Scenario D: a client buys
the shotgun and a damage level (applied on the host and client), the host refuses a duplicate weapon
and a mid-wave purchase, the shotgun fires exactly 6 pellets per shot, hits are confirmed, credits are
earned, and wave modifiers reach the client. Shop, HUD credits and modifier banner checked in a window.
**Not yet verified:** economy and balance over a full 25-wave match with people.

### Known limitations

- Prices, upgrade strengths, bounties and modifier strengths are a first guess (all in `.tres` files).
- No hit marker yet (`ProjectileSystem.hit_confirmed` is there for it).

## Milestone 4 — Gun Game and bots ✅ (merged, issues #33–#37)

| Issue | Feature | Status | Where |
|---|---|---|---|
| #33 | Names (in the join hello, saved in `user://settings.cfg`, shown above players); teams in the snapshot, own bullets never hit yourself; ScoreComponent (kills, deaths, tier); spawn protection; menu mode select + bot count; `MatchSettings.mode_scene`; signed shooter ids; protocol 5 | Done, tested | `shared/`, `player/`, `ui/main_menu.*`, `modes/match_settings.gd` |
| #34 | GunGameMode: free-for-all, ladder from MatchSettings (SMG → Rifle → Shotgun → Pistol, 3 kills each, 2 on the last), respawn at the point farthest from everyone, winner, restart | Done, tested | `modes/gun_game/`, `modes/data/gun_game_match.tres`, `levels/` |
| #35 | Bots: BotProfile (easy / normal / hard), BotBrain decisions, host-only BotController (line of sight, reaction time, aim error, turn speed, strafing, navigation), fill empty slots | Done, tested | `bots/` |
| #36 | Gun Game HUD (gun, kills on it, leader, next-gun banner), Tab scoreboard for both modes, winner on the results screen | Done, tested | `ui/` |
| #37 | Gun Game smoke scenario (E) and docs | Done | `tests/net/gun_smoke.gd` |

**Verified:** 240 GUT tests; lint/format clean; all five smoke scenarios pass. Scenario E: a host
and a client named themselves and see each other's names; 2 bots fill the match to 4 (a third bot
leaves when the client joins); with the humans holding fire the bots find and kill players on
their own; someone climbs the ladder and wins, both sides agree on the winner, the results screen
names them and the scoreboard lists all 4; the host restarts and every tier is back at 0.
**Not yet verified:** playing it in a window (HUD layout, scoreboard, name labels, how the bots
feel), bot difficulty, two PCs.

### Known limitations

- The ladder only uses guns from the shop catalog (5 so far), so the default ladder is short.
- Gun Game has no lobby or countdown: it starts when the host hosts, and the host's "Play
  again" restarts it.
- Bot difficulty, ladder length and kills per gun are first guesses (`bots/profiles/*.tres`,
  `modes/data/gun_game_match.tres`).

## Foundations, part 1: tooling, safety nets, stress test, latency ✅ (merged)

| Issue | Feature | Status | Where |
|---|---|---|---|
| #39 | One command for every check: `.\tools\check.ps1` (`-Smoke`, `-Fix`, `-Only`); CI runs it too | Done | `tools/check.ps1` |
| #40 | Safety-net tests: every NetState field survives encode/decode/copy (and the public form), every data file is valid, every mode/level is spawnable, every EventBus signal is used | Done, tested | `tests/shared/network/test_net_state_fields.gd`, `tests/test_project_consistency.gd` |
| #41 | Shared Claude Code hook formats every edited `.gd` file | Done | `.claude/settings.json`, `tools/hooks/format_gd.py` |
| #42 | Stress scenario F: 8 players (6 bots) vs 40 enemies, host tick time and bandwidth budget | Done | `tests/net/stress.gd` |
| #45 | Smaller snapshots: 4-byte entity header, other players in a 29-byte public form (your own in full), quarter-pixel enemy positions; now sent 60 times a second | Done, tested | `shared/network/snapshot_codec.gd`, `replicator.gd`, `states/` |
| #51 | Connection diagnostics in F3, hiccup logging, per-session net logs in `user://logs/net/` | Done | `jitter_meter.gd`, `net_log.gd`, `ui/net_overlay.gd` |
| #52 | Adaptive smoothing (latency + jitter-based buffer) on clients; the host draws others 2 ticks back and aims at that moment | Done, tested | `net_clock.gd`, `shared/components/display_delay.gd` |
| #53 | Input buffer on the host: 0 unless a player's inputs stall, at most 2 ticks | Done, tested | `command_queue.gd` |
| #54 | Your own player drawn one tick of motion ahead | Done, tested | `player/own_player_drawing.gd` |
| #55 | Latency budget + checks (settings test, smoke scenario G) | Done | `shared/network/latency_budget.tres`, `tests/net/latency.gd` |

**Measured** (Alex's PC, headless):

| | Before | Now |
|---|---|---|
| Others drawn behind you, clean | 100 ms (fixed) | 41 ms (35 ms smoothing), 0 hitches |
| Others under 80 ms ± 10 ms lag, 2% loss | 100 ms fixed: only ~20 ms of real buffer, so it ran dry several times a second | 146 ms (80 latency + 60 smoothing), 0 hitches |
| The host's view of other players | live: stops and jumps when inputs bunch up | 33 ms behind, smooth |
| Your own input → movement | 1 tick | 1 tick, and drawn a tick of motion ahead |
| Snapshots | 30/s, ~50 KB/s per player | 60/s, ~51 KB/s per player |
| Host tick (stress) | 2.9–3.4 ms avg | 3.5–6 ms avg, p95 4.3–8 ms (budget 10) |

All seven smoke scenarios pass; 267 GUT tests.
**Not verified:** playing in a window with Yusuf (the stutter fix is aimed at what you saw, but
untested between your two PCs), how the draw-ahead feels, CI machine timings against the
budgets (first CI run on the PR).

### Known limitations

- Headless test runs pace frames every 7–16 ms, so the host may hold back 1 tick of a clean
  connection's inputs there; windowed play at high refresh rates should need less.
- The stress test uses one real client; snapshot encoding cost grows with the number of
  clients (each gets its own packets). To measure with more clients in #43.
- The host's tick cost rose a little with 60 snapshots/s (more encoding); #43 looks at it.

## Placeholder art: Kenney top-down shooter ✅ (merged, issue #62)

Mostly looks; the gameplay changes are where shots start, the aim
angle, and the player's collision sizes. Network messages are unchanged.

| What | How | Where |
|---|---|---|
| Players | One character sprite under the aim pivot (it turns with the aim) replaces the octagon and barrel. Each peer gets a character from its peer id (Man Blue, Man Brown, Survivor, Soldier); bots get Robot or Hitman. Every peer picks the same one, so nothing is sent. | `player/player_look.gd`, `player/character_look.gd`, `player/looks/*.tres`, `PlayerData.player_looks` / `bot_looks` |
| Weapon poses | `WeaponData.pose` (gun / machine / silencer) replaces the barrel color: pistol gun, SMG and rifle machine, shotgun silencer | `weapons/weapon_data.gd`, `weapons/data/*.tres` |
| Enemies | Zombie sprite, tinted by `EnemyData.color` and the wave modifiers, drawn at `EnemyData.visual_scale` (brute 1.25), faces where it walks (sent by the host, 1 byte) and flinches when hit (#81) | `enemies/chaser.*`, `enemies/data/*.tres` |
| Arena | Floor and walls use repeating 64 px tiles | `levels/test_arena.tscn` |
| Shots leave the barrel | Each look stores where its drawn barrel ends per pose (`gun_muzzle`, `machine_muzzle`, `silencer_muzzle`, about 10 px to the gun side). The host and the owner start shots there, from the held weapon's pose. The owner's aim turns the character slightly so the barrel line, not the head, passes through the mouse | `player/character_look.gd`, `player/looks/*.tres`, `player/player.gd`, `player/player_input_source.gd` |
| Player collision | Body circle 16 → 18 px radius (walls), hit circle 18 → 21 px (about the shoulder width of the sprites) | `player/player.tscn` |

Assets: `assets/kenney_top_down_shooter/` (only the PNGs used, CC0, see its `License.txt`).

**Verified:** 273 GUT tests (new `tests/player/test_player_look.gd`); lint/format clean; smoke
scenarios A–G pass (a first run had scenario G's lagged smoothing at 107 ms against its 100 ms
budget; the rerun passed, and this change doesn't touch networking).
**Not yet verified:** how it looks in a window and with two instances.

### Known limitations

- The hit circle is round while the sprite is about 30 × 43 px, so it covers a little empty space
  in front of and behind the character. A capsule that turns with the aim would need the lag
  compensator to remember rotation too.
- Bots aim at targets from their body's center, so their shots pass about 10 px beside the target.
- Hugging a wall can put the barrel tip past the wall's edge (as with the old 30 px muzzle).

## Latency tier 1: fair play at high ping ✅ (merged, issues #57–#61)

Aimed at Yusuf's report (160 ms round trip): bots "shooting all over
the place", and getting hit by bullets that missed on his screen.

| Issue | Feature | Status | Where |
|---|---|---|---|
| #57 | Packets are read at the start of every physics tick and sent at its end (not once per frame) | Done | `shared/network/net_channel.gd` |
| #58 | Bots lead moving targets (intercept), from where the target's own screen has them | Done, tested | `bots/bot_brain.gd`, `bots/bot_controller.gd` |
| #59 | Fair dodging: bots' bullets are tested against remote players on their own timeline | Done, tested | `weapons/timeline_hits.gd`, `weapons/bullet.gd`, `player/player.gd` |
| #60 | Incoming bullets that pass near you catch up to the present, so the one that hits you visibly arrives | Done, tested | `weapons/bullet.gd` |
| #61 | Hit-direction marker when you are hit | Done, tested | `ui/hurt_indicator.gd`, `weapons/projectile_system.gd` |

**Measured** (new smoke scenario H: a client with 160 ms round trip against 2 hard bots, alternating
dodging and standing still): with fair dodging **47 of 47 bot hits (100%) were where the client's
own screen had it**; with it switched off, 29% of the hits were bullets that had missed on the
client's screen. Protocol 7.
**Not verified:** how it feels in a window between your two PCs; the hit marker's look.

### Known limitations

- Fair dodging is for bots' bullets only. Between two humans the shooter is still favoured (lag
  compensation), so a laggy player can still be hit "around a corner" by another human.
- A bot's bullet that hits on a laggy player's timeline lands its damage up to that player's
  latency later than before (that is the point: it waits to see where they really were).
- Pierce: a fair-dodging hit ends the bullet even if it could pierce.
- Headless timing is noisy when other programs run (the editor, a game): measured snapshot
  jitter on one PC ranged 7–27 ms between runs, and the smoothing buffer follows it. Scenario G
  therefore checks that the buffer is exactly what the jitter calls for (no waste) plus hard
  caps, rather than tight fixed numbers. The buffer now rate-limits only itself and follows the
  latency directly, which cut its lagged p95 from about 105 to 65 ms.
- Light can't be beaten: Yusuf still sees others about his latency in the past. A server between
  your continents would split it evenly (needs the Linux build, #48).

## Fullscreen ✅ (merged, issue #65)

Display only: nothing is sent over the network.

| What | How | Where |
|---|---|---|
| Fullscreen setting | `GameSettings.fullscreen`, saved in `user://settings.cfg` next to the name and applied on start. Borderless fullscreen (covers the screen, quick Alt+Tab) | `autoloads/game_settings.gd` |
| Keys | Input action `toggle_fullscreen`: **F11** and **Alt+Enter**, handled before the GUI so Alt+Enter doesn't also press a focused button | `project.godot`, `autoloads/game_settings.gd` |
| Menus | "Fullscreen (F11)" checkbox in the main menu and the Esc menu; both follow the keys and each other | `ui/fullscreen_check.gd`, `ui/main_menu.tscn`, `ui/game_menu.tscn` |

**Verified:** 6 new GUT tests (`tests/autoloads/test_game_settings.gd`, using a test settings file);
lint/format clean.

### Known limitations

- Fullscreen uses the screen the window is on; there is no monitor picker.

## Builds: more guns, hit effects and perks ❌ (merged in #68, removed again)

The 6 extra guns (Revolver, Torch, Cryo Carbine, Arc Caster, Launcher, Railgun), the 5 perks
and the hit-effect system (burn, chill, shock, shred, blast, enemy status rings) were taken
out: they didn't fit the game's direction and weren't balanced. New guns are now added one at
a time. The shop keeps its scroll area; the Gun Game ladder is back to SMG → Rifle → Shotgun →
Pistol, 3 kills each.

## Foundations: refactors for clarity ✅ (merged, issue #44)

No behaviour or network format change (protocol stays 7).

| What | Where |
|---|---|
| A player's snapshot (capture, show, restore) is its own component; `Player` forwards to it | `player/player_net_sync.gd` (new node in `player.tscn`) |
| The fair-dodging timeline is its own class | `player/player_timeline.gd` |
| The host's report on how a player's inputs arrive moved to the stats it fills | `NetStats.report_inputs` |
| Every smoke scenario extends one base instead of copying the same helpers (about 400 lines less) | `tests/net/smoke_script.gd` |
| Typed classes instead of loose Dictionaries | `LaunchArgs.Options`, `PositionHistory.Place`, `TimelineHits.Hit`, `Player.HudStats`, `Scoreboard.Row`, `BotBrain.Candidate` |

`player/player.gd` went from 389 to about 300 lines. `MatchNetState` keeps its mode-specific
fields (26 bytes; splitting it would change the network format for little gain).
**Checked:** 292 GUT tests, lint, format, and all 18 smoke roles pass. Tests that called the
changed functions now use the typed fields instead of Dictionary keys.

## Foundations: guides for Claude ✅ (merged, issue #50)

Makes the project quick for Claude (and new readers) to work in without
reading everything first.

| What | Where |
|---|---|
| System map: what each folder holds, one host tick, one client frame, one shot | root `CLAUDE.md` |
| Folder guides: key files, rules that aren't obvious, which tests cover it | `CLAUDE.md` in `shared/network/`, `player/`, `weapons/`, `modes/`, `bots/`, `ui/` |
| Recipes: add a weapon, enemy, upgrade, wave modifier, networked field, client request, game mode | `.claude/skills/*/SKILL.md` |
| A test that fails when a guide names a file that no longer exists, and checks every recipe has a name and description | `tests/test_guides.gd` |
| Rule: a PR that makes a guide wrong fixes it in the same PR | root `CLAUDE.md` |

**Checked:** the add-weapon recipe was followed once on a throwaway branch (a new gun, data only):
import, 295 tests, lint and format passed, and the shop listed it. That branch was not kept.
Claude Code loads a folder's `CLAUDE.md` when it works in that folder.

## Faster checks ✅ (merged, issue #71)

The smoke scenarios A-E (behaviour only) run at the same time, each on its own port; F (stress), G (latency) and H (fairness) measure timing and still run alone afterwards. Stress measures 12 s (was 20), fairness plays 20 s (was 30). `.\tools\check.ps1 -Smoke` went from about 4.5 minutes to about 2 minutes on Alex's PC; `-Scenarios A,E` runs only some (`run_smoke.ps1 -Only`).
The latency scenario allows one isolated ran-dry hitch per 6 s phase (a single one already reads as 10/min); the per-minute budget applies above that.

## Adaptive screen sizes ✅ (merged, issue #73)

Movement, shooting, aim, hits, bots and the netcode already ran on
ticks in world units; this makes the *view* and the *menus* fit any window, and locks that in.

| What | Where |
|---|---|
| **Fair view box:** every window shape sees the same 1152x648 world box (data: `PlayerData.view_size`). The camera zooms to fit it; a wider or taller window gets dark bars over the extra world, while the HUD and menus use the whole window | `player/fair_view.gd`, `player/player_camera.gd`, `ui/view_mask.gd` |
| Resizable window, starts at 1600x900, never smaller than 960x540; size and place remembered and kept on a screen that still exists | `shared/window_rules.gd`, `autoloads/game_settings.gd`, `project.godot` |
| Borderless fullscreen (F11, Alt+Enter) or exclusive fullscreen (`fullscreen_exclusive` in `settings.cfg`; no menu option yet, #49) | `autoloads/game_settings.gd` |
| UI size: Small / Normal / Large / Huge in the main menu and the Esc menu. Only menus and HUD change size | `ui/ui_scale_option.gd` |
| The shop runs from the top of the screen to the bottom and its list scrolls (it overflowed at Huge) | `ui/shop_panel.tscn` |
| Every panel laid out at 6 canvas sizes (16:9, 21:9, 4:3, 16:10, small and huge UI); fails on anything off screen or overlapping | `tests/ui/test_ui_layout.gd` |
| Gameplay code may not read the window, viewport size or frame rate | `tests/test_no_window_dependence.gd` |

**Checked:** 337 GUT tests, lint, format and all 18 smoke roles; a windowed run at 2560x1080
starts and hosts without errors.
**Not verified by eye:** how the bars, menus and UI sizes look on real monitors.

### Known limitations
- Exclusive fullscreen has no menu option yet (it waits for the settings menu, #49).
- The view box is 16:9. Windows within 12% of that shape are filled; on 21:9 thinner dark bars remain at the sides by design (fair in Gun Game).

## Screen fill fix ✅ (merged, issue #75)

Alex's report after #74: a maximized window didn't fill (thin bars at the sides) and leaving
fullscreen dropped back to a small window.
- **Cause 1:** a maximized window on a 16:9 monitor is 1920x1009 (taskbar and title bar), a bit
  wider than 16:9, so the strict fair box added side bars.
  **Fix:** a window within `PlayerData.view_max_crop` (12%) of the box's shape is filled edge to
  edge by showing up to that much *less* of the box on one axis; nobody ever sees more. Only
  shapes further off (21:9) still get bars, now thinner.
- **Cause 2:** leaving fullscreen restored the saved window size even when it had been maximized.
  **Fix:** maximized is remembered (`window_maximized`) and comes back, at start and after F11.
- Checked in a real window on a 1920x1080 monitor: windowed, maximized (filled, no bars),
  F11 fullscreen, back to maximized. Tests for the crop rule and the saved maximized state.

## Rocket launcher ✅ (merged, issue #77)

The first gun added one at a time, after the builds work was taken out.

| Feature | Status | Where |
|---|---|---|
| Rocket Launcher: 60 damage on a direct hit, then a blast (40 damage, 90 px) that pushes everyone around away; also explodes on walls and at the end of its range. Never hurts the shooter or teammates | Done, tested | `weapons/data/rocket_launcher.tres`, `weapons/explosion.gd` |
| Looks: a green tube held at the muzzle, and a big red rocket with a nose, fins and a flame (not a yellow bullet); everyone sees the blast | Done, not checked in a window | `weapons/models/rocket_launcher_tube.tscn`, `weapons/rocket.tscn`, `weapons/explosion_flash.*` |
| Shop (450 credits) and Gun Game ladder: SMG → Rifle → Shotgun → Rocket Launcher → Pistol | Done | `upgrades/data/shop_catalog.tres`, `modes/data/gun_game_match.tres` |
| Smoke scenario E uses it (quick ladder SMG → Rocket Launcher → SMG): the client must see blasts | Done | `tests/net/gun_smoke.gd` |

Protocol 9 (shots carry their projectile type; new blast event; the builds fields are gone).

### Known limitations

- The numbers are a first guess (`weapons/data/rocket_launcher.tres`).
- Blasts use where targets are now (not lag-compensated) and go through walls.
- The shooter sees their own rocket's blast when the host's message arrives (one round trip
  after the rocket lands on their screen).
- **Not verified:** how it looks and feels in a window.

## Upgrades per gun ✅ (merged, issue #79)

The gun upgrades used to add a percentage of the gun's number, rounded, so some levels added
nothing (the Rocket Launcher's 3 rockets went 4, 4, 5, 5, 6). Now every gun says what one level
of each gun upgrade gives it.

| Feature | Status | Where |
|---|---|---|
| Per-level amounts on every gun for Damage, Fire rate, Magazine, Reload speed and Knockback (e.g. Magazine: Pistol +2, SMG +6, Shotgun/Rifle/Rocket +1); every level always adds something | Done, tested | `weapons/data/*.tres`, `upgrades/player_stats.gd` |
| The Rocket Launcher's blast grows with Damage too (+6 per level) | Done, tested | `weapons/data/rocket_launcher.tres` |
| Levels carry over when you switch guns and give the new gun's amounts | Done, tested | `upgrades/player_stats.gd` |
| The shop shows what the next level gives the gun you hold ("Magazine 2/5 · +1 ammo · 150") | Done, not checked in a window | `ui/shop_panel.gd` |
| Move speed and Max health stay a percentage, the same for everyone | Unchanged | `upgrades/data/*.tres` |

### Known limitations

- The amounts are a first guess, roughly matching the old percentages.
- A reload never gets shorter than 0.1 s.

## Enemies face where they walk ✅ (merged, issue #81)

Enemies used to turn their picture towards wherever they moved. A bullet pushes them backwards,
so they spun around, and because a half turn is a tie that Godot always settles the same way,
they spun to the left about 80% of the time.

| Feature | Status | Where |
|---|---|---|
| Enemies face where they walk along their path, not where a push slides them | Done, tested | `enemies/enemy_facing.gd`, `enemies/chaser.gd` |
| The host sends the facing to clients: 1 byte per enemy (256 directions), blended the short way round between snapshots (enemy data 6 → 7 bytes) | Done, tested | `shared/network/states/enemy_net_state.gd` |
| A hit makes a short flinch towards the side it was pushed, then it turns back; a hit from straight in front picks a side at random | Done, tested | `enemies/enemy_facing.gd`, `EnemyData` "Flinch" |
| `KnockbackComponent` tells when a push lands (`pushed` signal) | Done, tested | `shared/components/knockback_component.gd` |
| Collision shapes don't rotate, so hits, walls and contact damage are unchanged | Unchanged | `enemies/chaser.tscn` |

Protocol 10 (enemy snapshots carry the facing). Smoke scenario F: about 52.8 KB/s download per
client (was about 51; budget 60).

### Known limitations

- The flinch numbers are a first guess (25°, back in 0.25 s, the same for every enemy type).
- The flinch side comes from the push direction, not where the bullet touched the enemy.
- On the host's own screen, the picture turns a few ticks before the (slightly delayed) body
  is drawn moving.
- **Not verified:** how it looks in a window.

## Hardening: client limits, garbage input, soak ✅ (merged, issue #47)

- **Client limits:** the host lets each client send at most 120 command packets a second
  (bursts of 40) and 8 requests a second (bursts of 16), and drops requests over 64 bytes, before
  decoding anything (`RateLimiter`, numbers in `default_network_config.tres`). Normal play sends
  60 a second, so it never hits the limit; a flooding client only loses its own extra packets.
  Drops are logged at most once a second per client.
- **Garbage input test** (`tests/shared/network/test_garbage_input.gd`): seeded random bytes into
  input commands, join hellos, snapshots and shop requests. It found two real problems, both fixed:
  - a huge (but finite) aim angle passed `InputCommand.sanitized()` as garbage, because `wrapf`
    loses precision on huge numbers; aims beyond 1000 rad now become 0;
  - a junk join hello made Godot log hundreds of decode errors; `Handshake.decode` now drops
    anything that isn't a plain Dictionary of at most 1 KB before decoding it.
- **Soak test:** smoke scenario **S** (opt-in, `-Smoke -Scenarios S`) runs the stress scene for 10
  minutes and fails if memory, objects or nodes grow more than 15% between the first and last
  quarter. 90 s run: nodes 913 → 914, memory 74.6 → 74.8 MB (host).
- No network format change (protocol stays 10).
- Also: `docs/ROADMAP.md` (the plan for what comes next), no fixed developer areas in
  `CLAUDE.md`/`README.md` for now, and the six merged sections above marked merged.

### Known limitations
- A client over its limit is slowed down, not kicked.
- The garbage test covers what clients send today; each new client decoder needs its own case.
- Client object count rose about 3% over the 90 s soak (within the limit); the 10-minute soak is
  the real check.

## M7 step 1: wave report ✅ (merged, issue #84)

A measuring tool for the rest of M7: one command prints the whole wave difficulty curve.

| Feature | Status | Where |
|---|---|---|
| `.\tools\wave_report.ps1` prints a markdown table for every wave: budget, enemies by type, total health (after modifiers), effective health (armor counted), peak alive, spawn time and modifiers. `-Seed N` (default 1) and `-Schedule res://...` | Done, tested | `tools/wave_report.ps1`, `tools/wave_report.gd`, `modes/waves/wave_report.gd` |
| The wave seed, the modifier pick and an enemy's scaled health are now pure functions that the game and the report both call, so the report can't drift from what spawns. Same seeds and numbers as before (tests pin them) | Done, tested | `WaveBudget.wave_seed`, `ModifierCatalog.pick_for_wave`, `WaveModifier.scaled_health` |
| `check.ps1` and the report share one Godot finder | Done | `tools/find_godot.ps1` |

No network format change (protocol stays 10).

### Known limitations
- **Peak alive is the `max_alive` cap** (fewer enemies or the cap), not a prediction: the real
  peak depends on how fast players kill.
- Effective health counts armor (damage taken) but not regeneration.
- One seed per report: the enemy mix and modifiers change with the seed.
  Compare before/after with the same seed.
- Godot prints "ObjectDB instances leaked" at exit for any `-s` script in this project (an
  empty one too); the `.ps1` hides it. Same engine shutdown-order noise as the GUT runs.

## Gun and bullet redesign ✅ (merged, issue #85)

The pistol, SMG, shotgun and rifle were only the small guns painted into each character picture, and
every bullet was the same pale-yellow bar that was hard to see on the concrete floor. Looks
only: no numbers, shop or ladder changes.

| Feature | Status | Where |
|---|---|---|
| Pistol, SMG, shotgun and rifle get their own models drawn over the hands, like the rocket launcher (black pistol with a brown grip; gunmetal SMG with a wire stock and side magazine; shotgun with a wooden pump and stock; tan rifle with a scope) | Done, checked on all 6 characters in a render | `weapons/models/pistol_model.tscn`, `weapons/models/smg_model.tscn`, `weapons/models/shotgun_model.tscn`, `weapons/models/rifle_model.tscn` |
| Bullets: orange tracer (pistol, SMG), long red-white streak (rifle), round orange pellets (shotgun), all with a dark outline and a fading tail | Done, tested | `weapons/bullet.tscn`, `weapons/rifle_round.tscn`, `weapons/pellet.tscn` |
| Two new projectile kinds, `PELLET` and `RIFLE_ROUND` (added at the end; the shot format is unchanged, so no protocol bump) | Done, tested | `weapons/weapon_data.gd`, `weapons/projectile_system.gd` |

### Known limitations

- **Not verified:** how it looks in a multiplayer game.

## M7 step 2: enemy behaviours as parts ✅ (merged, issue #88)

An enemy type is now a combination of parts instead of code. No behaviour change.

| Feature | Status | Where |
|---|---|---|
| `EnemyData.movement` (where it walks: `EnemyMovement.goal(own, target)`) and `EnemyData.attack` (`EnemyAttack.wants_to_attack()` pure + `perform()` on the host) | Done, tested | `enemies/behaviours/`, `enemies/enemy_data.gd` |
| `ChaseMovement` (shared `enemies/behaviours/data/chase.tres`) and `MeleeAttack` (damage, interval, knockback; was `contact_*` on `EnemyData`) | Done, tested | `enemies/behaviours/` |
| Grunt, runner and brute are chase + melee with their old numbers (a test pins them) | Done, tested | `enemies/data/*.tres` |
| The data check fails on an `EnemyData` without movement or attack | Done | `tests/test_project_consistency.gd` |

No network format change (protocol stays 10); clients never run the behaviours. Wave report unchanged.

## M7 step 3: enemy projectiles ✅ (merged, issue #90)

Enemies can shoot now, and a laggy player can dodge their bullets fairly.

| Feature | Status | Where |
|---|---|---|
| `RangedAttack`: fires a `WeaponData`'s bullets at its target when it sees it (no wall in between) within `attack_range`, leading a moving target by `lead` (0..1). Shots go through `shot_fired` on the enemies' team | Done, tested | `enemies/behaviours/ranged_attack.gd`, `enemies/chaser.gd` |
| Enemy bolt: slow (420 px/s), 12 damage, a pink orb every peer draws (projectile kind 4, after the redesign's pellet and rifle round) | Done, not checked in a window | `enemies/behaviours/data/enemy_bolt.tres`, `weapons/enemy_bolt.tscn` |
| **Fair dodging for enemy bullets:** enemies fire as shooter `Shot.enemy_shooter_id(net_id)` (negative, below any bot), so `TimelineHits` tests them on each remote player's own timeline like bots' bullets | Done, tested | `weapons/shot.gd`, `weapons/timeline_hits.gd` |
| Leading a target is one shared function for bots and enemies | Done (moved) | `weapons/aim_lead.gd` (was `BotBrain.intercept`) |
| Smoke **H**: 2 ranged test enemies also hunt the 160 ms client; their hits are judged on their own count. Smoke **F**: half of the 40 stress enemies are ranged | Done | `tests/net/fairness.gd`, `tests/net/data/test_spitter.tres`, `stress_waves.tres` |

Protocol 11 (a new projectile kind; the shot format is unchanged).

**Measured:** smoke H: enemy-bolt hits on the lagged client **8 of 8 (100%) where its own
screen had it** (bot hits 41 of 41). Smoke F with ranged enemies: host tick p95 4.6 ms
(budget 10), client download 53.8 KB/s (budget 60). A first version cast a line-of-sight ray
for every enemy every tick (p95 9.7 ms); now only a ranged enemy whose attack is ready casts one.

### Known limitations
- Enemies lead from where the host has the target (not the target's own screen, as bots do).
- Line of sight is one ray from the enemy's center; a bolt can still clip a pillar's corner.

## M7 step 4: enemy roster, part 1: roles ✅ (merged, issue #92)

Three new enemy types, each a combination of parts plus numbers (`enemies/data/*.tres`), all
bought by the default schedule.

| Enemy | Role | Parts and numbers |
|---|---|---|
| **Shooter** (from wave 6, cost 3) | Ranged: keeps 260–460 px away and fires enemy bolts | `KeepDistanceMovement` + `RangedAttack` (1.6 s, 560 px, 60% lead); 70 health |
| **Tank** (from wave 9, cost 7) | Frontline: slow, armored, barely pushed | chase + melee (30 damage); 650 health, takes 60% damage (`damage_taken`), 5% knockback |
| **Swarmer** (from wave 6, cost 0.4 each) | Swarm: cheap, fast, comes 6 at a time | chase + melee (4 damage, fast); 18 health; `group_size` 6, bought and spawned together |

| System | Where |
|---|---|
| `KeepDistanceMovement`: walk in when too far, back off when too close, hold in between | `enemies/behaviours/keep_distance_movement.gd` |
| `EnemyData.damage_taken` (armor, stacks with the wave's modifiers; the wave report's Effective column counts it) | `enemies/enemy_data.gd`, `enemies/chaser.gd`, `modes/waves/wave_report.gd` |
| `EnemyData.group_size`: the budget buys a group at once (a partial one if points run out); the spawner releases one group around one point (`WaveSpawner.group_count`, `group_offset`), never past `max_alive` | `modes/waves/wave_budget.gd`, `modes/waves/wave_spawner.gd` |

No network format change (clients load the new types from `enemies/data/` like the others).

### Known limitations
- All enemies use the zombie picture, told apart by tint and size.
- **Not verified:** how the three play in a window.

## M7 step 5: enemy roster, part 2: Splitter and Support ✅ (merged, issue #94)

Enemies that change other enemies, so the fight becomes about what to kill first.

| Enemy | What it does | Numbers |
|---|---|---|
| **Splitter** (from wave 7, cost 3) | Dies into 2 Splitlings where it fell | 140 health, melee 15; Splitling: 35 health, fast, melee 6 |
| **Support** (from wave 8, cost 4) | Hangs back (380–620 px) and every 1.5 s heals every wounded enemy within 240 px (itself too) by 12% of their max health. Never hurts players | 90 health |

| System | Where |
|---|---|
| `EnemyData.split_into` + `split_count`; the dying enemy emits EventBus `enemy_split` before it is freed, and the host's `WaveSpawner` spawns the children around it at once, with the wave's modifiers | `enemies/enemy_data.gd`, `enemies/chaser.gd`, `autoloads/event_bus.gd`, `modes/waves/wave_spawner.gd` |
| Splits never count twice: children don't go into the spawn queue, they're alive enemies of the wave until killed, so a wave with a Splitter clears only after its children die | `modes/waves/wave_spawner.gd` |
| `HealPulseAttack` (pure `heal_amount`, `reaches`); enemies join `Groups.ENEMIES` | `enemies/behaviours/heal_pulse_attack.gd`, `shared/groups.gd` |
| The wave report counts a split enemy's children in Health and Effective | `modes/waves/wave_report.gd` |
| Smoke **C** now plays a Splitter (wave 1) and a Support (wave 2) over the network, and checks that the Splitter split and that wave 1 needed 3 kills to clear | `tests/net/wave_smoke.gd`, `tests/net/data/combo_*.tres` |

No network format change (the split children are normal enemy spawns).

### Known limitations
- A split ignores `max_alive` (the children appear at once, at most 2 per Splitter).
- Heals have no visual yet (health bars aren't drawn; a pulse ring would help, M10).
- **Not verified:** that a wave with a Support is noticeably harder unless it is focused. That
  needs people playing (the roadmap's "done when"); on paper a Support adds about 12% of the
  nearby enemies' health every 1.5 s.

## M7 step 6: modifiers that stack ✅ (merged, issue #96)

| Feature | Status | Where |
|---|---|---|
| One modifier from wave 6, two from 16, **three from 21** (`triple_modifier_wave`) | Done, tested | `modes/waves/modifier_catalog.gd`, `wave_schedule.gd`, `default_waves.tres` |
| Two new modifiers: **Tough** (×1.4 health) and **Frenzied** (×1.2 speed, takes ×1.15 damage) | Done | `modes/waves/data/modifiers/` |
| Rules for which combine: `WaveModifier.conflicts_with` (Frenzied never with Fast); the pick skips conflicting ones (and picks fewer if nothing fits). Without conflicts it picks exactly as before | Done, tested | `modes/waves/wave_modifier.gd`, `modifier_catalog.gd` |
| Caps however many stack: health ≤ ×2.5, speed ≤ ×1.8, damage taken ≥ ×0.4, regeneration ≤ 8%/s (on the catalog) | Done, tested | `modes/waves/data/modifier_catalog.tres` |
| The HUD's wave banner names every modifier of the wave ("Wave 21 / 25 · Armored · Tough · Frenzied") | Already there (M3) | `ui/hud.gd` |

No network format change: the mask is still one byte (5 of 8 modifiers used).

### Known limitations
- The modifiers only change health, speed, armor and regeneration; new kinds of effect need
  code (recipe `add-wave-modifier`).
- **Not verified:** how a 3-modifier banner reads in a window.

## M7 step 7: the wave curve to 25 ✅ (merged, issue #98)

| Feature | Status | Where |
|---|---|---|
| Every enemy has a role (`EnemyData.role`: frontline, ranged, swarm, support) | Done | `enemies/enemy_data.gd`, `enemies/data/*.tres` |
| **Composition rules:** the schedule gives each role a share of the budget in wave 1 (`shares_first`: all frontline) and the last wave (`shares_last`: 50% frontline, 25% ranged, 10% swarm, 15% support), blended in between; a role with no type yet passes its share on. Roles buy in turn, frontline last (it soaks up what the others couldn't spend); the picks are shuffled (groups kept together) so roles arrive mixed | Done, tested | `modes/waves/wave_budget.gd`, `wave_schedule.gd` |
| **Modifiers cost budget:** a wave buys budget ÷ threat, where threat (`ModifierCatalog.threat`) is how much tougher its modifiers make each enemy (health ÷ damage taken × speed and regeneration terms). Armored waves get fewer, tougher enemies instead of a spike; a wave always buys at least one enemy | Done, tested | `modes/waves/modifier_catalog.gd`, `wave_mode.gd`, `wave_spawner.gd` |
| **The budget curve:** 6 + 1.9 × (wave − 1)^1.35, from 6 points in wave 1 to 144 in wave 25 (was 91), so late waves still fill the field after paying for 2–3 modifiers | Done | `modes/waves/data/default_waves.tres` |
| The wave report has a **Threat** column (points bought × threat): the curve on paper. A test checks it rises every wave and stays within 3 points of the budget (no dips or spikes) over 20 seeds, and that waves 20–25 have Shooters, Swarmers and Supports | Done, tested | `modes/waves/wave_report.gd`, `tests/modes/waves/test_wave_budget.gd` |
| `max_alive` stays **40**: at 50 the stress client downloads 59.5 KB/s (budget 60); at 45 the host tick p95 was 8.3–9.0 ms (budget 10) on Alex's PC, too close for CI | Measured | `tests/net/stress.gd` |

**Measured:** smoke F at 40 with the real mix (grunt, shooter, tank, swarmer by shares): host
tick p95 4.2 ms, client download 52.8 KB/s. Soak S (10 min): see the PR.

### Known limitations
- A bigger `max_alive` needs smaller enemy snapshots (bandwidth is the limit at 50).
- **Not verified:** how the curve plays (step 15's playtests).

## M7 step 8: bosses at waves 10, 20 and 25 ✅ (merged, issue #99)

| Boss | Wave | Phases (health share where it starts) |
|---|---|---|
| **Brood Mother** (2400 hp) | 10 | Hungry (100%): bites · Brood (60%): hangs back, calls 4 Swarmers every 4 s (1.2 s warning) · Frenzy (25%): chases 1.7× faster |
| **Warden** (5200 hp, armored) | 20 | Sentry: keeps range, fans of 5 bolts (0.8 s warning) · Lockdown (55%): chases, rings of 16 (1.2 s) · Overload (20%): fans of 7, fast (0.5 s) |
| **Overlord** (9000 hp, armored) | 25 | Awakened: rings of 12 (1 s) · Summoner (66%): hangs back, calls 2 Shooters · Unbound (33%): chases, fans of 9 (0.6 s). **Killing it ends wave 25: the match is won** |

| Framework | Where |
|---|---|
| `BossPhase` (health threshold, movement, attack, speed) on `EnemyData.phases`; the phase follows health on every peer (`BossPhase.index_for`, pure) | `enemies/behaviours/boss_phase.gd`, `enemies/enemy_data.gd`, `enemies/chaser.gd` |
| **Telegraphed attacks:** `EnemyAttack.windup`. The enemy winds up first; the host sends how far (1 byte per enemy snapshot, protocol 12) and every peer draws a ring that fills before it fires | `enemies/chaser.gd`, `enemies/enemy_telegraph.gd`, `shared/network/states/enemy_net_state.gd` |
| `VolleyAttack` (aimed fans, or rings that fire unseen) and `SummonAttack` (calls enemies through `enemy_split`, capped) | `enemies/behaviours/` |
| Bosses are big: `body_scale` grows hitbox, touch area and body (`HitboxComponent.scale_size`) | `enemies/chaser.gd`, `shared/components/hitbox_component.gd` |
| Boss waves: `WaveSchedule.boss_waves` + `bosses`; the boss comes first and is paid from the wave's budget. `ends_wave_on_death` stops the wave and clears its enemies | `modes/waves/wave_schedule.gd`, `wave_budget.gd`, `wave_spawner.gd` |
| **Boss health bar:** name, phase and health, bottom centre, while a boss is alive | `ui/boss_bar.gd`, `ui/hud.tscn` |
| Smoke **C** plays 3 waves: Splitter, Support, then a 2-phase boss; the host checks it reached phase 2 and its death won the match | `tests/net/wave_smoke.gd`, `tests/net/data/combo_boss.tres` |

Protocol 12 (enemy snapshots 7 → 8 bytes). Smoke F: client download 55.3 KB/s (was 52.8;
budget 60), host tick p95 4.7 ms.

### Known limitations
- **Not verified:** that 2 players can beat each boss (the roadmap's "done when"); the numbers
  are a first guess for step 15's playtests. Only the smoke test's small boss was beaten.
- The boss bar, the warning ring and the bosses' looks (tinted, scaled zombies) are not checked
  in a window.
- A boss's attack waits for its windup even if the target walks away; it then fires at where
  the target is.

## M7 step 9: downed and revive (co-op) ✅ (merged, issue #102)

| Feature | Status | Where |
|---|---|---|
| At 0 health during a wave a player **goes down** where they fell (greyed, enemies ignore them, can't act) instead of being out | Done, tested | `modes/wave_mode.gd`, `player/player.gd` |
| A teammate within 70 px **holding E** (new `revive` action, `InputCommand.REVIVE`) fills a revive bar over 3 s; letting go or walking away empties it. Revived players come back with 30% health where they lie | Done, tested | `modes/waves/revive_rules.gd`, `modes/waves/downed_players.gd` |
| **Bleed-out:** 20 s, paused while someone is reviving; then out until the break (as before) | Done, tested | same |
| Everyone down = defeat (downed players don't count as living) | Done (WaveFlow unchanged) | `modes/waves/wave_flow.gd` |
| Everyone sees it: `down_left` and `revive_progress` (1 byte each, also in the public form; protocol 13); a green ring fills over the downed player; HUD: "You're down · being revived 60%" for them, "Hold E to revive Yusuf" next to them | Done, tested | `shared/network/states/player_net_state.gd`, `player/player_net_sync.gd`, `ui/hud.gd` |
| Numbers in `MatchSettings` (`bleed_out_seconds` 0 = off; Gun Game keeps it off) | Done | `modes/match_settings.gd`, `modes/data/default_match.tres` |
| Smoke **C**: the host downs the client, teleports next to it and holds revive; the client sees itself go down and come back | Done | `tests/net/wave_smoke.gd` |

Also: `project.godot` gets the `revive` input action (E).

### Known limitations
- Reviving doesn't stop you moving or shooting; walking out of range interrupts it.
- **Not verified:** how it feels in a window; the ring and the prompts' look.

## M7 step 10: bots in co-op ✅ (merged, issue #105)

| Feature | Status | Where |
|---|---|---|
| Bots fill empty slots in Waves too (the menu's bot count now applies to co-op); the fill moved from Gun Game into the `GameMode` base | Done | `modes/game_mode.gd`, `modes/gun_game/gun_game_mode.gd`, `modes/wave_mode.gd`, `ui/main_menu.gd` |
| **Most dangerous target:** a target's danger (an enemy's wave cost, 1 for a player) over its distance; equal danger = nearest, as before | Done, tested | `bots/bot_brain.gd`, `bots/bot_controller.gd` |
| **Revive:** a bot walks to the nearest downed teammate within 900 px and holds revive next to them, still shooting | Done, tested | same |
| **Stay with the team:** with nobody in sight it walks back to the team's centre when more than 320 px away, instead of roaming | Done, tested | same |
| **Shopping:** between waves each bot buys one thing every half second: the dearest gun it can afford that beats its own, else the cheapest next upgrade (`BotShopping`, checked by the same `ShopRules`) | Done, tested | `bots/bot_shopping.gd`, `modes/wave_mode.gd` |
| Bots are ready whenever every human is; a lobby of bots alone waits for its timer | Done, tested | `modes/waves/wave_flow.gd` |
| Smoke **C** gets a third role: 1 human (never fires, can't be hurt) + 3 bots clear a quick 3-wave schedule; the host downs a bot and another bot revives it; the bots shopped | Done | `tests/net/wave_smoke.gd`, `tests/net/data/bot_coop_*.tres` |

Also: bots replan a path only when their goal moves more than 64 px (the team centre moves
every tick); the main menu's rows are 6 px apart (was 10) so it still fits at 768x432 with the
bot count shown for Waves.

No network format change.

### Known limitations
- Their shopping ignores what suits their style; the Rocket Launcher counts as "dearer, so better".
- **Not verified:** whether they feel like useful teammates in a window.

## Shop rework: the see-through shop ✅ (issue #103)

| Feature | Status | Where |
|---|---|---|
| The shop is a big see-through window over the game. While it's open (lobby, breaks) a gold "B: Shop" hint shows bottom right; **B** opens it, **B**, **Esc** or a click outside closes it. A new lobby or break starts with it closed | Done | `ui/shop_panel.*` |
| **Gun cards:** each gun's own drawn model (`WeaponData.held_model`) shown big, its name and price (Free / Equipped); the gun you hold has a blue frame, guns you can't afford are dimmed | Done, tested | `ui/shop_weapon_card.*`, `ui/shop_gun_picture.gd` |
| **Upgrade rows** for the gun you hold: level dots (gold = bought), what the next level gives, a buy button with the price (MAX at the cap) | Done, tested | `ui/shop_upgrade_row.*`, `ui/shop_pips.gd` |
| **Buy feedback:** when the host confirms a purchase (your weapon or a level actually changes), that card swells and settles, or the new dot pops. A refused request pops nothing | Done, tested | `ui/shop_seen.gd` |

Nothing about buying changed: the buttons still only send `shop_purchase_requested` and the host
checks it. No network format change.

### Known limitations
- The credits number still jumps instead of counting.
- Tried in a window by Yusuf. **Not verified:** a 2-player match.

## M7 step 11: smarter bots ✅ (merged, issue #107)

| Feature | Status | Where |
|---|---|---|
| **Aim from the barrel:** the aim is turned so the shot from the barrel (about 10 px to the gun side) passes through the target, not the body's centre | Done, tested | `bots/bot_brain.gd` `barrel_aim`, `player/player.gd` `muzzle_offset` |
| **Dodge:** bullets that will pass within 30 px in the next 0.3–0.4 s make it sidestep away from their line, blended into its move by `dodge` (Easy 0, Normal 0.2, Hard 0.5) | Done, tested | `BotBrain.dodge`, `bots/bot_controller.gd`, `Groups.BULLETS` |
| **Cover:** below `cover_health` (Normal 25%, Hard 40%) under fire it runs to the nearest respawn point the threat can't see for 2–2.5 s (then not again for 8 s), still shooting | Done, tested | `BotBrain.cover_point` |
| **Goals instead of roaming:** with nobody in sight it hunts the nearest opponent (`hunts`), coming in `flank_degrees` round from the side (Normal 25°, Hard 45°, switching sides after cover) | Done, tested | `BotBrain.flank_point` |
| Smoke **E** gets a `botduel` role: a Hard bot vs a Normal bot with SMGs for 45 s on a dedicated server; fails unless Hard has more kills | Done | `tests/net/gun_smoke.gd`, `tests/net/data/bot_duel_match.tres` |

**Measured (3 duels each, 45 s, SMG vs SMG):**

| | Hard kills : Normal kills | Hard hit rate | Normal hit rate |
|---|---|---|---|
| Before | 5:3, 6:3, 5:3 | 41–50% | 28–36% |
| After | 5:2, 5:2, 4:1 | 39–49% | 9–24% |

Hard beat Normal in every duel before and after; now by a wider margin, mostly because
Normal's shots get dodged. A first version had Hard dodge at 0.8: two Hard bots then barely hit
each other and smoke E stopped finding a winner, so it is 0.5. Gun Game matches take a little
longer: smoke E now allows 95 s for a winner (was 70).

### Known limitations
- Cover means the level's respawn points (maps with real points of interest come in step 13).
- Hunting uses what the host knows (every opponent's position), not what the bot could see.
- Bots dodge on the host's timeline; against a lagged human's bullets that is a little early.
- `bot_controller.gd` is long (about 370 lines); a split into senses and actions would help.
- **Not verified:** how they feel to fight in a window.

## M7 step 12: Gun Game polish ✅ (merged, issue #111)

| Feature | Status | Where |
|---|---|---|
| **Spawn protection ends when you fire** (it was a fixed 0.5 s): no shooting from safety | Done, tested | `modes/gun_game/spawn_protection.gd`, `modes/gun_game/gun_game_mode.gd` |
| **Kill feed:** the host reports every kill (killer, victim, gun) to every peer (event topic 3, protocol 14); the HUD shows the last 5 top right, "Killer [SMG] Victim", fading after 5 s. Reports stop once someone has won | Done, tested | `gun_game_mode.gd`, EventBus `kill_reported`, `ui/kill_feed.gd`, `ui/hud.tscn` |
| **A different character per player:** the host gives each new player a look nobody has yet (humans from the human looks first, bots from the bot looks), sent once with the spawn (`look_index`); repeats only when all 6 are taken. Fixes "two players can get the same one" | Done, tested | `player/character_assignment.gd`, `player/player_data.gd`, `levels/level.gd`, `player/player.tscn` |
| **Results screen at the end:** already there (M4: winner, scoreboard); smoke E keeps checking it | Done (M4) | `ui/results_screen.*` |
| Smoke **E**: both sides print the last 5 kill feed entries; run_smoke checks they are the same | Done | `tests/net/gun_smoke.gd`, `tests/net/run_smoke.ps1` |

### Known limitations
- The kill feed is Gun Game only (Waves has no feed of enemy kills).
- **Not verified:** the kill feed's look and the characters in a window.

## M7 step 13: maps, the framework ✅ (merged, issue #113)

| Feature | Status | Where |
|---|---|---|
| **Maps as data:** `MapData` (name, level scene, which modes it suits) in `levels/data/*.tres`; `MatchSettings.map` picks one (the lobby picker is M6) and Main loads its scene | Done | `levels/map_data.gd`, `levels/data/test_arena.tres`, `modes/match_settings.gd`, `main.gd` |
| A level holds every kind of spawn point: player starts (co-op), respawns (free-for-all), enemy spawn zones, and new **bot points of interest** (cover behind the pillars), which bots use for hunting and cover | Done | `levels/level.gd`, `levels/test_arena.tscn` |
| **Map check** for every map: every point is on the navigation mesh (within 40 px), not inside a wall, and can walk to and from every other one | Done, tested | `levels/map_check.gd`, `tests/levels/test_map_check.gd` |
| Smoke scripts find the loaded level instead of naming `TestArena`, so they run on any map | Done | `tests/net/smoke_script.gd` (`_level_path()`) and the scenarios |

**Adding a map without code:** make a level scene like `test_arena.tscn` (walls in the
`navigation_obstacles` group, the four point groups), add it to Main's `LevelSpawner`, and add a
`MapData` `.tres` in `levels/data/`. The map check runs on it automatically.

### Known limitations
- No map picker yet (M6); a map is chosen in the match settings `.tres` or with `--match`.

## M7 step 14: two new maps ✅ (merged, issue #116)

Both added without code: a level scene, a `MapData` `.tres`, and a line in Main's `LevelSpawner`.

| Map | For | Layout |
|---|---|---|
| **Outpost** (2400×1500) | Co-op first | Players start in a walled central hall reached only through three 160–180 px gaps (chokepoints); open yards west and east with pillars, where enemies arrive from six spawn zones at the edges. Points of interest just inside each gap and behind cover |
| **The Pit** (1400×1000) | Free-for-all first | Compact and symmetric: a centre block, four low walls and two side pillars for cover; ten respawn points all round, four starts in the corners |

| Check | Result |
|---|---|
| Map check (on the mesh, not in a wall, every point reaches every other) | Both pass (`tests/levels/test_map_check.gd` runs on every map in `levels/data/`) |
| Smoke **C** (waves) | Main wave run (Splitter, Support, boss, revive) on **The Pit**; 1 human + 3 bots clear the quick schedule on **Outpost** |
| Smoke **E** (Gun Game) | Main match (host, client, 2 bots: winner, kill feed, restart) on **The Pit**; Hard-vs-Normal bot duel on **Outpost** |

The test arena keeps scenarios A, B, D, F, G and H.

### Known limitations
- On Outpost a Support that hangs back behind the hall's walls has to be hunted down: the smoke
  test's players (who stand still) couldn't clear it there, so its main wave run is on The Pit.
- Both maps reuse the concrete floor (tinted) and plank walls; real art is M10.
- No picker yet (M6): choose a map in the match settings `.tres`.
- **Not verified:** how they play in a window (sight lines, whether the chokepoints feel right).

## M7 step 15: balance pass, on paper ⚠️ (issue #118; playtests still to do)

Tuning only (`.tres`). Without people playing, this pass works from the numbers: the wave
report, the economy (bounties are about 10 credits per budget point, plus the wave bonus), and
a model of two players' damage as they buy the SMG and upgrades (70% of shots landing,
magazine and reload counted).

| Change | Why |
|---|---|
| Regenerating: 5% of max health per second → **1.5%**; the stacking cap 8% → **3%** | On a boss it was unbeatable: the Warden at wave 20 with Fast · Regenerating healed about 276/s against about 232 damage/s from two well-upgraded players. On normal enemies 1.5% still matters for Tanks and Splitters |
| Overlord (wave 25) 9000 → **6500** health | With wave 25's three modifiers (Armored · Tough · Frenzied) it was about 24,000 effective health: about 94 s of nonstop focused fire before its summons and rings |
| Warden (wave 20) 5200 → **7000** health | With regeneration fixed it fell in about 36 s, shorter than wave 10's boss feels relative to the players' growth |

**Boss fights on paper (seed 1's modifiers, 2 players, focused fire):** Brood Mother about 25 s,
Warden about 61 s, Overlord about 68 s, plus the time lost to dodging rings and fighting summons.

**Economy check:** by wave 10 a player has about 2,000 credits (an SMG and about 8 upgrade
levels); everything is close to maxed by wave 22. Left as it is.

**Checked:** wave report before and after (only regeneration waves and boss waves change), all
smoke scenarios, the 10-minute soak (numbers in the PR).
Also: smoke E's quick ladder is 1 kill per gun now (was 2): with smarter bots, CI's slower
machines sometimes ran out of time before anyone finished it.

### Not done: the playtests
The roadmap's test for this step is two real playtests by Alex and Yusuf of a full run to wave
25, and its "done when" is "winnable by 2 players who play well, lost by ones who don't". Neither
can be checked without people. Things to watch for when you play:
- whether waves 6–9 (the first modifiers, Shooters and Swarmers) are a difficulty jump;
- whether the Support is focused and whether it should heal less (12% every 1.5 s);
- the bosses' telegraphs: is the ring readable in time;
- bots' shopping: they buy the Rocket Launcher (the dearest gun), which is weak against single targets.

## Game feel: hit flash, damage numbers, death bursts, screen shake ✅ (issue #109)

| Feature | Status | Where |
|---|---|---|
| **Hit flash:** enemies and players flash bright when they lose health (healing and respawns don't). Every peer watches the health the host decided, so it needs no network data | Done, tested | `shared/feedback/hit_feedback.gd`, `enemies/chaser.tscn`, `player/player.tscn` |
| **Damage numbers** pop from enemies, rise and fade; hits in the same frame add up. A hit taking 50%+ of the enemy's starting health (Yusuf's rule; the health it actually lost counts) is a **big hit**: bigger and gold (a crit look, no randomness) | Done, tested | `shared/feedback/damage_number.gd`, `feedback_system.gd` |
| **Death bursts:** a dying enemy bursts into pieces in its colour (wave modifier tint included), bigger for bosses. The host sends every client one small event (where, colour, size), so a match reset never sets off bursts | Done, tested | `shared/feedback/feedback_system.gd`, `death_burst.gd`, `levels/test_arena.tscn` |
| **Screen shake** when your player is hit and when an explosion goes off near you (fades with distance) | Done, tested | `player/player_camera.gd` |
| All tuning in one Resource | Done | `shared/feedback/data/default_feedback.tres` (`FeedbackData`) |

Network: new event topic 2 (`FeedbackSystem.EVENT_DEATH`), `Handshake.PROTOCOL` 14 → 15 (the kill feed
had taken 14 while this branch waited).
Every map has the `Effects` layer and `FeedbackSystem` (test arena, Outpost, The Pit), and the map
check now fails a map without a `ProjectileSystem` or `FeedbackSystem`.
EventBus gets `damage_seen` and `blast_shown` (both looks only, every peer).

### Known limitations
- No setting to turn screen shake off.
- A client draws enemies slightly in the past, so a burst can appear a few pixels ahead of
  where it last saw the enemy.
- Tried in a window by Yusuf (test arena). **Not verified:** a 2-player match, and the new maps by eye.

## Sounds: hits, kills, explosions, shop and banners ✅ (issue #114)

| Feature | Status | Where |
|---|---|---|
| **World sounds**, placed where they happen (louder near your camera): enemy death (thud), explosions, gunshots. Hits are silent for now: the punch sounded like a drum, none of the Kenney or generated options fit, and a tin clank on big hits played on nearly every hit (see below) | Done | `shared/feedback/feedback_system.gd` |
| Your player hit (a short metal clink) | Done | `shared/feedback/feedback_system.gd` |
| **Shop:** open/close, a click when you ask to buy, coins when the host confirms the purchase | Done | `ui/shop_panel.gd` |
| **HUD banners** (wave started/cleared, Gun Game next gun) play a chime | Done | `ui/hud.gd` |
| Every play picks a random variant and nudges the pitch; at most N of one sound at once (an SMG into a crowd stays readable); silent on headless peers | Done, tested | `shared/feedback/sound_playback.gd`, `sound_cue.gd` |
| All picks and volumes in one Resource | Done, tested | `shared/feedback/data/default_sounds.tres` (`SoundData`) |
| **Gunshots:** every gun has its own sound (`WeaponData.fire_sound`, a `SoundCue` in `shared/feedback/data/guns/` that future guns can share): pistol (3 variants of one creator's shot; two others sounded different and were dropped), SMG (only the first shot of a P90 burst, quieter so fast fire stays clear), shotgun, rifle (3 variants), rocket launcher (an RPG-7 whoosh). One bang per trigger pull, not per pellet; enemies' shots are silent. Every peer hears every gun where it fires | Done, tested | `shared/feedback/feedback_system.gd`, `weapons/projectile_system.gd` (EventBus `shot_shown`) |
| **Explosions** use one Pixabay boom (two alternating sounded odd); **boss deaths** play a monster death grunt (normal enemies keep the quiet thud). The death event carries a boss flag: `Handshake.PROTOCOL` 15 → 16 | Done, tested | `shared/feedback/data/default_sounds.tres`, `feedback_system.gd` |
| 11 sounds Yusuf picked on Pixabay (free, no credit required), saved as trimmed WAVs: the downloads started with up to 1.3 s of silence (the SMG played nothing at all, the shotgun fired late), so a one-off Godot script decoded each one (directly: a first try recorded them live, which dropped chunks and cut into the start of the pistol shots, making them sound fluttery), cut the silence and long tails and evened out the loudness, keeping stereo. Sources in the folder's README | Done | `assets/pixabay_sounds/` |
| 19 sounds from Kenney's CC0 packs (Impact Sounds, Interface Sounds, RPG Audio) | Done | `assets/kenney_sounds/` |

### Known limitations
- No sound on hits yet (to decide once the guns are heard together; idea: a quiet tick for your own hits).
- The files are levelled to the same loudness; each gun's `volume_db` (in its `.tres`) sets how
  loud it is against the others (Yusuf turned the rifle and shotgun down 6 dB by ear).
- No volume setting; everything plays on the Master bus.
- Tried in a window by Yusuf (every gun, explosions). **Not verified:** a 2-player match, boss deaths.

## Enemies inside you can be shot ✅ (issue #124)

| Feature | Status | Where |
|---|---|---|
| Enemies walk through players, and bullets start at the muzzle (33-38 px ahead), so an enemy between your body and the muzzle was never hit (worst with the shotgun and SMG). A player's bullet is still drawn from the muzzle, but its first hit test now starts at the body (`Shot.hit_origin`). Enemies behind you still aren't hit. Enemies' own shots are unchanged. Nothing new is sent over the network | Done, tested | `weapons/shot.gd`, `weapons/bullet.gd`, `player/player.gd` |

### Known limitations
- A wall between your body and the muzzle now stops the shot (before, a barrel poking through a wall could shoot past it).
- **Not verified:** played in the game or in a 2-player match by hand (the smoke test passed).

## Shop hint no longer covers the Host/ping label ✅ (issue #122)

| Feature | Status | Where |
|---|---|---|
| The gold "B: Shop" hint moved from the top-right corner (where the "Host · N players" / ping label is) to the bottom-right corner | Done | `ui/shop_panel.tscn` |

### Known limitations
- The UI layout test checks each scene on its own, so it can't catch two scenes using the same corner.
- **Not verified:** seen in the running game.

## Bullets no longer drawn over the gun ✅ (issue #129)

| Feature | Status | Where |
|---|---|---|
| A bullet spawns centred on the muzzle and its tail reaches 11-44 px back, so it was drawn over the gun. Bullets now draw **under** characters: every map puts `Projectiles` before `Enemies` and `Players`, and the gun and body cover the part still in the barrel. Explosion flashes stay on top | Done | `levels/*.tscn`, `weapons/explosion_flash.gd` |
| MapCheck fails a map whose bullets would draw over its characters | Done, tested | `levels/map_check.gd`, `tests/levels/test_map_check.gd` |

### Known limitations
- Bullets also pass under other players and enemies they fly past (Yusuf chose this over cutting off the back of each new bullet).
- **Not verified:** seen in the running game.

## Pets & pacing 1: call the next wave early ✅ (merged, issue #126)

Instead of a speed-up button (a shooter is played every second, and the netcode runs at a fixed
60 ticks), early waves get a choice:

| Feature | Status | Where |
|---|---|---|
| Once a wave has spawned everything, a prompt appears: **G** votes to start the next wave at once, on top of the enemies still alive. Everyone must vote; bots vote with the humans | Done, tested | `modes/waves/early_call.gd`, `modes/wave_mode.gd`, `WaveFlow.call_early`, `project.godot` (`call_wave`) |
| **The reward:** the called-away wave's clear bonus plus 6 credits per enemy still alive and 3 per second of break skipped, to everyone standing | Done, tested | `MatchSettings.early_call_bonus_*`, `modes/data/default_match.tres` |
| **The catch:** the shop only opens in breaks, so calling early means not shopping: free money in waves 1–5, a gamble later | By design | |
| HUD: "G: call the next wave early for bonus credits (1/2)" during the wave (`call_open`, `call_votes` in the match state; protocol 17) | Done, tested | `ui/hud.gd`, `shared/network/states/match_net_state.gd` |
| Faster start: first break 30 → 20 s, breaks 20 → 15 s, wave 1 spawns every 0.8 s (was 1.2) | Data | `default_match.tres`, `default_waves.tres` |
| Smoke **C**: the human of the bot co-op run votes every wave early; at least one must start early | Done | `tests/net/wave_smoke.gd` |

### Known limitations
- Not the last wave, and not before the current wave has spawned everything.
- **Not verified:** how it feels in a window.

## Pets & pacing 2: pets and the Pets menu ✅ (merged, issue #128)

| Feature | Status | Where |
|---|---|---|
| Three pets as data, five tiers each with the ability texts and prices (200 / 400 / 700 / 1100 / 1600, about 4,000 in all): **Healer** (support), **Wizard** (control), **Soldier** (offense) | Done, tested | `pets/data/*.tres`, `pets/pet_data.gd`, `pets/pet_tier.gd`, `pets/pet_catalog.gd` |
| **Buying:** adopt a pet, then buy its tiers one by one; another pet starts again at tier 1. The host checks every purchase (`ShopRules.check_pet`, `KIND_PET`) | Done, tested | `upgrades/shop_rules.gd`, `player/player_loadout.gd`, `modes/wave_mode.gd` |
| **Pets menu (P):** a see-through window in the shop's style. Left: the three pets as cards with an animated portrait, role and tier pips (gold frame on yours). Right: the chosen pet's ladder (owned tiers lit, the next one framed in gold with its price, the rest dimmed), one big button ("Adopt Wizard · 200", "Tier 3: Conduction · 700") and a warning before you swap pets. A confirmed tier flashes gold | Done, tested, checked in a rendered screenshot | `ui/pet_panel.gd`, `ui/pet_card.gd`, `ui/pet_tier_row.gd`, `ui/pet_portrait.gd` |
| **The pet in the world:** floats behind its owner, bobbing, eyes blinking, with its mark (Healer's cross and halo, Wizard's hat and star, Soldier's helmet) and gold tier pips. Drawn from the owner's replicated pet, so nothing extra is sent | Done | `pets/pet_look.gd`, `pets/pet_follower.gd` |
| Pet and tier in the player snapshot, public too (protocol 18) | Done, tested | `shared/network/states/player_net_state.gd`, `player/player_net_sync.gd` |
| Bots adopt a favourite pet (one per bot) and raise it when the next tier costs at most twice their cheapest upgrade | Done, tested | `bots/bot_shopping.gd` |
| Smoke **D**: the client adopts the Wizard and buys tier 2; the host must apply both and the client see them | Done | `tests/net/shop_smoke.gd` |

The abilities themselves come in the next three steps. Until then a pet does nothing but follow.

### Known limitations
- **Not verified in a running match:** the menu was checked in a rendered screenshot, and the
  pet in the world only in code.
- Swapping pets loses the old pet's tiers (the menu warns first).

## Pets & pacing 3: the Healer ✅ (merged, issue #132)

| Tier | What it does | Where |
|---|---|---|
| 1 Mending | Once the team has dealt half of the wave's planned enemy health, heals you 12% of your max health (15% from tier 2). Once a wave | `pets/healer_rules.gd`, `pets/pet_powers.gd` |
| 2 Wave's End | When a wave is cleared (or called early), everyone standing heals 8% (10% from tier 3). Two Healers don't stack: the stronger one heals, once | same |
| 3 Triage | Players you revive come back with +20% health, and your revives fill 25% faster | `modes/waves/downed_players.gd` |
| 4 Siphon | 2% of the damage you deal heals you, at most 10% of your max health a wave (15% at tier 5) | `pets/pet_powers.gd` |
| 5 Guardian | The first time each wave you'd go down, you stay up at 20% instead | `modes/wave_mode.gd` |

Every number is in `pets/data/healer.tres` (`HealerData`).

**Shared pieces for every pet:** EventBus `enemy_damaged` (who hit which enemy for how much),
`PetPowers` (host only, created by WaveMode), and `PetEffects` (every peer's level draws pet
effects the host announces, event topic 4; protocol 19). Heals show as a green ring and cross.

**Tests:** `tests/pets/test_healer.gd` (every tier's rule, the caps, the effect decoder against
200 random packets); smoke **C**: the host gives the client a tier-2 Healer and the client must
see its heals arrive.

### Known limitations
- Mending measures against the wave's planned enemy health (before modifiers and splits).
- **Not verified:** how the heals look and feel in a window.

## Pets & pacing 4: enemy status and the Wizard ✅ (merged, issue #134)

| Tier | What it does |
|---|---|
| 1 Arc Spark | A hit has a 15% chance (at most once a second) to arc lightning to 2 enemies within 140 px, for 40% of the hit (20% and 3 jumps from tier 2) |
| 2 Frost Rune | Every 8 s a rune lands where enemies are thickest within 450 px of you: 35% slower for 3 s (every 6 s from tier 4) |
| 3 Conduction | Arcs deal 25% more to slowed enemies, and a slowed first enemy passes the arc on once more |
| 4 Hex | Every 12 s it marks the toughest enemy within 600 px (a boss first): +20% damage from everyone for 5 s, arcs start from it, bots focus it (every 7 s from tier 5) |
| 5 Tempest | Every 25 s, after a 1 s warning ring, bolts strike up to 6 enemies within 400 px for 8% of their max health (2% on bosses) |

| System | Where |
|---|---|
| `EnemyStatus`: slowed and hexed, the stronger effect and later end kept; the host's chaser moves slower and takes more damage | `enemies/enemy_status.gd`, `enemies/chaser.gd` |
| Every peer sees it: slowed enemies look frosty, hexed ones wear a purple diamond. The two flags share the telegraph's byte (telegraph is now 6 bits), so the snapshot stays 8 bytes per enemy; protocol 20 | `shared/network/states/enemy_net_state.gd`, `enemies/enemy_telegraph.gd` |
| Pure rules and host powers; Wizard damage goes through the enemy's hitbox in the owner's name (kills and bounties are theirs) and never arcs again | `pets/wizard_rules.gd`, `pets/wizard_powers.gd`, `pets/data/wizard.tres` |

**Tests:** `tests/pets/test_wizard.gd` (status stacking and expiry, the packed byte, every tier's
rule, the chain, the rune's spot, the hex target, tempest damage); smoke **C**: the host has a
tier-5 Wizard and the client must see its lightning or runes. Smoke F download 57.8 KB/s
(budget 60; it varies run to run, but it's getting close).

### Known limitations
- Hex and runes don't check line of sight (they reach through walls).
- **Not verified:** how the lightning, runes and marks look in a window.

## Pets & pacing 5: player buffs and the Soldier ✅ (merged, issue #136)

| Tier | What it does |
|---|---|
| 1 Drill | You deal 8% more damage (10% from tier 2) |
| 2 Rally | Every 12 kills, teammates within 400 px fire 15% faster for 6 s (you too from tier 4; 20% from tier 5) |
| 3 Covering Fire | Every 0.8 s the pet shoots the nearest enemy within 350 px it can see, for 25% of your gun's damage (an instant tracer; the kill is yours) |
| 4 Last Stand | While a teammate is down you deal 25% more damage and move 10% faster |
| 5 Airstrike | 10 kills within 8 s call an airstrike: a 600 px line toward the thickest enemies, a 1.2 s warning, 300 + 20 per wave damage (a quarter on bosses) |

| System | Where |
|---|---|
| **Player buffs:** fire rate and move speed on the loadout (`set_buffs`, applied to the effective stats) and in the owner's snapshot (`buff_fire`, `buff_move`, protocol 21), so the owner's prediction fires and moves at the host's speed | `player/player_loadout.gd`, `shared/network/states/player_net_state.gd`, `player/player_net_sync.gd` |
| Damage bonus on the host only (`Player.damage_bonus` scales the shots it fires) | `player/player.gd` |
| Pure rules and host powers; Rally from two Soldiers keeps the stronger | `pets/soldier_rules.gd`, `pets/soldier_powers.gd`, `pets/data/soldier.tres` |

**Tests:** `tests/pets/test_soldier.gd` (every tier, the streak window, the strike line); smoke
**C**: a bot with a tier-5 Soldier fights and its pet's shots must show (11 in a local run);
smoke **D**: the host gives the client a Rally and its own snapshot must carry it (its shotgun
then fires 1.69 shots a second, 1.3 × 1.3).

### Known limitations
- When a buff starts or ends, the owner's prediction can be off for one round trip (a small
  correction), as for any state the host changes.
- **Not verified:** how the tracers, rallies and airstrikes look and feel in a window.

## Pets & pacing 6: balance pass ⚠️ (issue #138; playtests to do)

On paper, from the numbers (no people played it):

| Question | Finding | Change |
|---|---|---|
| Do pets compete with upgrades for credits? | All five tiers cost about 4,000; maxed upgrades about 9,500; a player earns about 10,000 by wave 22. You can't max both, so a pet is a real choice | None |
| Tier 1 against a damage level of the same price | Drill: +8% for 200. Arc Spark with an SMG: about +8% (40% of a 14-damage hit, 2 jumps, at most once a second). A damage level: about +7% for 225 | None |
| Covering Fire | 25% of the gun's damage per shot is about 4 damage a second with an SMG (3%) for 700 credits, against about +20% with the rifle | **At least 10 damage a shot** (`cover_min_damage`): about +10% with an SMG, the rifle unchanged |
| Calling early | 6 per enemy alive + 3 per second of break: about 100 credits a call in waves 1–5, enough for an early pet tier | None |
| Do pets break the late waves? | Two players with maxed pets deal roughly 20% more: boss fights on paper about 20 / 50 / 55 s instead of 25 / 61 / 68 s | None until the playtests say so |

**Performance:** smoke F now gives all 8 players a tier-5 pet. With pets the host's tick rose by
about 2.5 ms on this PC (while two other Godot processes ran here; without pets the same run was
also over budget, so local timings were unreliable). Pets that find no target now wait 0.25 s
before looking again, and covering fire casts at most 3 sight rays per look. CI's clean machines
judge the 10 ms budget (see the PR).

### Not done
- The playtests: whether pets feel worth their price, whether any is a must-pick, and whether
  calling early feels good.

## Bosses no longer out-heal the players ✅ (issue #140)

The Warden on wave 20 was close to unkillable. Support pulses (12% of max health every 1.5 s)
and Regenerating (1.5% a second) heal a *share* of max health, and a boss has a lot of it: with
two supports and Regenerating (wave report, seed 4) the Warden healed about 1,225 HP/s, more
than a whole team of maxed-out players deals.

| Feature | Status | Where |
|---|---|---|
| `EnemyData.heal_received`: the healing an enemy gets is multiplied by it (default 1.0, so normal enemies heal as before). The support pulse and Regenerating both use it | Done, tested | `enemies/enemy_data.gd`, `enemies/chaser.gd` |
| All three bosses get 10% (`heal_received = 0.1`). That worst-case Warden now heals about 120 HP/s, and only about 10 HP/s once its supports are dead, so killing supports first still pays off. The Overlord's worst case (wave 25, seed 7) drops from about 1,590 to 160 HP/s | Data, tested | `enemies/data/bosses/*.tres` |
| A test fails if a boss could heal more than 2.5% of its max health a second in the worst case (2 supports beside it, regeneration and health at the modifier catalog's caps; it was 19%). Another runs a real Warden and checks both kinds of healing | Done | `tests/enemies/test_bosses.gd` |

### Known limitations
- The wave report doesn't include healing, so its numbers don't change.
- **Not verified:** a real wave-20 or wave-25 fight in a window.

## Joining no longer fails the latency check ✅

Since the pets landed, smoke **G** failed on main: the client's smoothing buffer sat at about
95–140 ms instead of 35–60. The cause was not the network. Joining a match freezes the client
for one frame while it loads (about 180 ms locally), and the snapshots read after that frame
arrive all at once. The jitter meter took that for 165 ms of network jitter, the buffer jumped
to about 210 ms, and it shrinks slowly, so it was still too high when the test measured.

| Feature | Status | Where |
|---|---|---|
| A client frame longer than `NetworkConfig.local_stall_seconds` (0.1 s) drops the jitter measured so far, so a local freeze never counts as network jitter | Done, tested | `shared/network/net_clock.gd`, `default_network_config.tres` |

Smoke G locally: 3 of 3 failed before (buffer 20–38 ms over what the jitter needs), 3 of 3 pass
after (about 0 ms over, p95 about 60 ms).

### Known limitations
- The join freeze itself is still there (about 180 ms). It is only a frame, but it grows as
  more scripts and data load at join.

## The Wizard's Tempest no longer crashes the host ✅

A two-player game crashed on wave 22: `SCRIPT ERROR: Trying to assign invalid previously freed
instance` in `WizardPowers._strike_due`. The Tempest (tier 5) marks enemies, then strikes them
after a warning. When one of them died during the warning, the loop put it into a typed
`ChaserEnemy` variable before the existing "is it still there?" check ran, which is an error.

| Feature | Status | Where |
|---|---|---|
| `WizardPowers.still_standing()` checks each marked enemy before treating it as a `ChaserEnemy` | Done, tested | `pets/wizard_powers.gd`, `tests/pets/test_wizard.gd` |

### Known limitations
- A match can't be saved or resumed, so a crash loses the run.

## The early-call prompt shows again ✅ (issue #142)

The "G: call the next wave early" prompt from #126 never appeared: during a wave the HUD wrote
it and then overwrote the same label with the wave's modifier names, so G worked but nobody
knew it was there.

| Feature | Status | Where |
|---|---|---|
| During a wave the label under the enemy count shows the modifiers, then the early-call prompt on the next line (either one alone when the other is empty) | Done, tested | `ui/hud.gd` (`Hud.stack_lines`), `tests/ui/test_hud_text.gd` |

### Known limitations
- Checked in a window (host, solo). **Not verified:** how the two lines look with long modifier
  lists.

## Checks run only what a change needs ✅

The full smoke suite takes 2.5–5 minutes on every change, even a typo fix. Now the smoke
scenarios are picked from the files a branch changes; the cheap checks still always run.

| Feature | Status | Where |
|---|---|---|
| Rules: each folder → the smoke scenarios that exercise it (longest path wins; `*.md` none; a file in no rule, or more than 25 files, means all) | Done, tested | `tools/check_scope.json`, `tools/check_scope.gd` |
| `.\tools\check.ps1 -Changed` (`-Base`, default `origin/main`): prints the scenarios and why, then runs only those | Done | `tools/check.ps1`, `tools/check_scope_cli.gd` |
| CI: a pull request runs its scenarios (all with the `full-checks` label); a push to main runs all | Done | `.github/workflows/checks.yml` |
| The rule for Claude: "Which checks to run" | Done | `CLAUDE.md`, the recipes |
| A test fails if a project folder has no rule or a rule names a scenario `run_smoke.ps1` lacks | Done | `tests/tools/test_check_scope.gd` |

A pets-only change now runs C, D and F: 56 s instead of about 4 minutes locally. Docs-only
changes run no smoke at all.

### Known limitations
- A pull request can pass with its scenarios and still break one it didn't run; the full run on
  main catches it, but only after the merge.
- The `full-checks` label has to exist on GitHub before it can be added to a PR.

## Early calls only through wave 5 ✅

Calling early all game, with stacked waves paying for the same leftovers again on every call,
could add about 5,000 credits late and break the economy. Rushing waves 1–4 (about 400) stays.

| Feature | Status | Where |
|---|---|---|
| `MatchSettings.early_call_last_wave` (255 = no limit; 5 in the default match): the last wave that may be started early, so the break before wave 6 always happens | Done, tested | `modes/match_settings.gd`, `modes/waves/early_call.gd`, `tests/modes/waves/test_early_call.gd` |
| The per-enemy bonus counts only the called-away wave's own enemies still alive (not older leftovers or split children) | Done, tested | `modes/waves/wave_spawner.gd` (`alive_count`), `modes/wave_mode.gd` |

### Known limitations
- Not checked in a 2-instance window test; the HUD prompt goes away through `call_open`, which
  was already in the match state.

## Wave difficulty 1: every wave measured on a 0–10 scale ✅ (issue #147)

Plan: https://claude.ai/artifact/TWnaN1PmUgMJ38VWhFugNw. This part only measures; the waves
are still bought from the budget. The next part builds each wave to hit its target.

| What | Status | Where |
|---|---|---|
| Each enemy type as numbers per second: effective health (armor, splits), melee and ranged damage (fans and rings: shots inside a 30° cone; windups slow the cycle), healing, summons, speed × size. Each attack reports its own part (`add_stats`); boss phases count by the share of health they cover | Done, tested | `enemies/enemy_stats.gd`, `enemies/behaviours/*_attack.gd` |
| Five axes: Toughness, Melee, Pressure, Ranged, Sustain. Each scores `10 × (raw / reference) ^ 0.7`; the difficulty is their weighted length (every axis at its reference = 10). Modifiers move the axes they touch instead of being their own axis | Done, tested | `modes/waves/difficulty/`, `modes/waves/data/difficulty_model.tres` |
| The target curve: a straight trend from 2.05 (wave 1) to 10 (wave 25); boss waves +0.4, the two waves after a boss −0.3 and −0.15 (a boss wave is a little harder than the next); the final wave 10.25 | Done, tested | `modes/waves/difficulty/difficulty_curve.gd`, `default_waves.tres` |
| The target is **about 15% above today's waves** (fitted line of today's scores × 1.15), as asked | Data | same |
| Wave report: Target, Difficulty and an H M P R S column per wave | Done, tested | `modes/waves/wave_report.gd`, `tools/wave_report.gd` |
| Recipe for tuning it, adding a category or recalibrating; `add-enemy` asks new attacks for `add_stats` | Done | `.claude/skills/tune-wave-difficulty/`, `modes/CLAUDE.md` |

**What the score shows about today's curve (seed 1):** it zigzags. Boss wave 10 scores 4.3 but
wave 11 scores 5.7; wave 13 is 6.5 and wave 16 is 5.0; wave 23 (9.2) beats the final wave (8.9),
where the Overlord takes most of the budget and little stands around it.

### Known limitations
- The weights and references are a first calibration, fitted to today's waves; playtests will move
  them. The score can't see pathing, focus fire or how readable a telegraph is.
- Gameplay is unchanged until the next part (the composer) uses the target.

## Wave difficulty 2: each wave built to hit its target ⚠️ (issue #151; playtests to do)

The budget is gone: every wave is built to land on the difficulty its curve sets (part 1, #147).

| What | Status | Where |
|---|---|---|
| **The composer:** the boss first, then every minimum the rules ask for, then random types (`spawn_weight`, pulled toward the role shares by each type's solo difficulty) while the wave stays under target + 0.3, until it reaches the target; 4 tries keep the closest. Same seed, same wave | Done, tested | `modes/waves/wave_composer.gd`, `modes/waves/wave_draft.gd` |
| **Rules:** `EnemyLimit` (min/max of one type) and `AxisLimit` (an axis's share of the difficulty: a cap, or a minimum that makes a themed wave), each for a wave range. None in the default schedule yet | Done, tested | `modes/waves/difficulty/`, `WaveSchedule.rules` |
| Removed: `WaveBudget`, `base_budget`/`budget_growth`/`budget_curve`, `ModifierCatalog.threat()`. Modifiers act through the score: a Tough wave gets fewer enemies | Done | |
| **15% harder:** every default wave (20 seeds) lands within 0.3 of its target, about 15% above the old waves. Boss waves sit a little above the next wave (wave 10: 5.43, wave 11: 5.06) | Done, tested | `tests/modes/waves/test_wave_composer.gd` |
| **Credits unchanged:** more enemies paid about 29% more bounty, which would have undone most of the 15%. Every bounty × 0.78 (Grunt 10 → 8, Tank 90 → 70, Warden 900 → 700...), so two players still earn about 8,650 each from kills and clear bonuses by wave 22, as after #139 (tested) | Done, tested | `enemies/data/*.tres` |
| Wave report: a Bounty column instead of Budget and Threat | Done | `modes/waves/wave_report.gd` |

### Known limitations
- **Not played.** How 15% harder feels, and whether Shooters and Supports showing up more often in
  waves 6–12 than before reads well, needs the playtests.
- A target is only reached in steps of one enemy, so waves land up to 0.3 above or below it.

## Wave difficulty 3: no more enemy cost ✅ (issue #153)

| What | Status | Where |
|---|---|---|
| `EnemyData.cost` is gone (from the script and every enemy file): the composer never needed it, and its last user was the co-op bots' target danger | Done | `enemies/enemy_data.gd`, `enemies/data/`, `tests/net/data/` |
| Bots rank an enemy by its difficulty alone, with the 0.7 exponent undone (`BotBrain.danger_of`): in Grunts, a Runner or Swarmer 0.8, a Support 2.0, a Shooter 2.9, a Tank 3.5, the bosses 7 to 26 (with cost: Support 4, Shooter 3, Tank 7, bosses 12 to 40) | Done, tested | `bots/bot_brain.gd`, `bots/bot_controller.gd` |

### Known limitations
- Bots now rank a Shooter a little above a Support (2.9 against 2.0; with cost it was 3 against 4),
  so they focus healers a bit less. Raise the Sustain axis's weight if playtests want healers
  focused first.

## Waves starts with 0 bots ✅ (issue #155)

The host menu's bot count now starts at the chosen mode's own `bot_fill_to`: 0 for Waves, 4 for
Gun Game (it was 4 for both). Tested in `tests/ui/test_main_menu.gd`.

## Strategy 1: the next-wave forecast ✅

Plan: https://claude.ai/artifact/7EPV52pTXaRkvnrzkgHpJm (section 1).

| What | Status | Where |
|---|---|---|
| In the lobby and every break, the HUD shows the next wave: its two strongest difficulty axes (▲▲ when one is at least 35% of the wave), its modifiers, and a boss warning. "Next: Toughness ▲▲ · Ranged ▲ · Armored · Boss" | Done, tested | `ui/hud.gd` (`Hud.forecast_line`) |
| It's exact: a wave depends only on the match seed and its number, so the host builds it at the start of the break (`WaveComposer.plan_wave`, also used by the wave report) and the wave that spawns is the one forecast (tested against the report for every default wave) | Done, tested | `modes/waves/wave_forecast.gd`, `modes/wave_mode.gd` |
| 7 bytes in the match state: flags, the modifier mask and one byte per axis (tenths, up to 25.5). Protocol 22 | Done, tested | `shared/network/states/match_net_state.gd`, `shared/network/handshake.gd` |
| Smoke C: host and client both see a forecast during a break, and the boss warning before wave 3 | Done | `tests/net/wave_smoke.gd` |

### Known limitations
- No "new enemy type" or "bring this damage type" yet: clients don't know the schedule's enemy
  list, and the damage types (#158) aren't shown in the forecast yet.
- **Not checked in a window:** whether ▲ renders in the HUD font on every platform (Godot falls
  back to a system font for it).

## Strategy 2: interest on held credits ✅ (issue #157)

| What | Status | Where |
|---|---|---|
| After each clear bonus (and for a wave called away early), every standing player earns 10 for every 100 credits they hold, at most 50 a wave (`MatchSettings.interest_step` / `interest_per_step` / `interest_cap`, 0 = off). The final wave pays none: it ends the match | Done, tested | `modes/waves/interest.gd`, `modes/wave_mode.gd`, `modes/data/default_match.tres` |
| Economy: a bank of 500+ held from wave 5 earns about 1,000 by wave 25, against about 8,650 from kills and clear bonuses by wave 22 (tested) | Done, tested | `tests/modes/waves/test_wave_composer.gd` |

### Known limitations
- **Not played.** Whether 50 a wave is worth skipping a purchase for needs the playtests.
- Interest isn't shown on the HUD or shop yet; players only see their credits jump.

## Strategy 3: counters (damage types and enemy traits) ⚠️ (issue #158; playtests to do)

Every hit has a damage type and every enemy has traits, so a wave can need a specific answer.
Part 3 of the strategy-layer plan; the forecast's "Bring: <type>" reads `CounterProfile`.

| What | Status | Where |
|---|---|---|
| **Damage types:** Kinetic (default), Pierce, Blast, Arcane, one enum | Done | `shared/components/damage_type.gd` |
| **Sources:** `WeaponData.damage_type` (rocket launcher Blast, hit and explosion; pistol, SMG, rifle, shotgun Kinetic), `PetData.damage_type` (Wizard Arcane, Soldier Kinetic). Host only: the host's `Shot` takes it from its own `WeaponData` and it is never sent, so no protocol change | Done, tested (smoke E checks every rocket the host simulates is Blast) | `weapons/`, `pets/` |
| **Traits:** `EnemyTrait` (a multiplier per type), `EnemyData.traits`. Armored (Kinetic 0.6, Pierce 1.3, Blast 0.7, Arcane 1.0) on the Tank (was `damage_taken` 0.6); Swarm (Pierce 0.7, Blast 1.5) on Swarmers and Splitlings | Done, tested | `enemies/enemy_trait.gd`, `enemies/data/traits/` |
| **Modifiers add traits:** `WaveModifier.adds_traits`. The Armored modifier adds the Armored trait instead of its flat 0.6, so Pierce now beats it. `combined()` keeps every added trait; the 0.4 damage taken floor holds for every type | Done, tested | `modes/waves/` |
| **Host applies it:** `HitboxComponent.hit(..., damage_type)` → `HealthComponent.type_multipliers` (the enemy's traits plus the wave's, `EnemyTrait.profile`) | Done, tested | `shared/components/`, `enemies/chaser.gd` |
| **Score unchanged:** the difficulty score reads Kinetic only (`EnemyData.taken`, `WaveModifier.taken`); the wave report is identical before and after | Done, tested | `enemies/enemy_stats.gd`, `modes/waves/difficulty/` |
| **`CounterProfile`:** per type, the health-weighted multiplier of a planned wave, and `best_type(min_edge)`. Every default Armored wave gives Pierce | Done, tested | `modes/waves/difficulty/counter_profile.gd` |
| Recipe `add-damage-type`; `add-weapon`, `add-enemy`, `add-wave-modifier` updated | Done | `.claude/skills/` |

### Known limitations
- **Nothing deals Pierce yet.** Only the rocket (Blast) and the Wizard (Arcane) aren't Kinetic;
  Pierce comes with the Path (armor-piercing rounds). Until then an Armored wave is just tougher,
  as before, and Blast does a little better than Kinetic against it (0.7 against 0.6).
- The rocket now deals 1.5× to Swarmers and Splitlings and 0.7× (instead of 0.6×) to Tanks and
  Armored waves: a small buff the score can't see (it is Kinetic-based). Playtests decide.
- Bosses keep a flat `damage_taken` (0.75, 0.8) that applies to every type, so no type counters
  them yet.
- No trait fears or resists Arcane yet (the plan has Warded and Ethereal for later).

## Strategy 4: the Path engine ⚠️ (issue #159; playtests to do)

Part 1 of the Path (strategy-layer plan, section 4): a run-long route bought with Cores, a second,
scarce currency. This proves the engine end to end with one branch; the other branches come next.

| What | Status | Where |
|---|---|---|
| **Cores:** every player gets `cores_per_wave` (1) per wave cleared (a wave called early counts once it is called away) and `cores_per_boss` (2) per boss killed; solo (one human, no bots) gets `cores_solo_bonus` (1) more every `cores_solo_every` (5) waves. Paid by the host, standing or not. A full solo run earns 30 from waves, a team 25 | Done, tested | `modes/match_settings.gd`, `modes/waves/wave_path.gd`, `modes/data/default_match.tres` |
| **Data:** `PathNode` (name, description, branch, tier, Core cost, `requires`, `excludes`, `effects`) and `PathTree` (every node in a fixed order, at most 64; append, never reorder). Effects: `StatEffect` (a player stat through PlayerStats' multipliers) and `EconomyEffect` (shop upgrade price multiplier, extra Cores per boss) | Done, tested | `path/` |
| **Rules:** a step only in a break, one per break (calling a wave early skips that break's step), enough Cores, every requirement owned, nothing excluded either way, never twice; no respec | Done, tested | `path/path_rules.gd` |
| **Request** `WaveMode.REQUEST_PATH` (4): `[node index]`, checked by the host with PathRules | Done, smoke D | `modes/wave_mode.gd` |
| **Replication:** owned nodes (u64, public: everyone sees everyone's route), Cores and the break's step (owner only) in the player snapshot (Cores and the step share one byte), 106 / 41 bytes; protocol 23 (the forecast took 22). Smoke F's download budget goes from 60 to 64 KB/s: 8 players' masks add about 3.9 KB/s (61.5 KB/s measured before packing) StatEffects apply from the owned mask in `PlayerLoadout._apply` on the host and in the owner's prediction alike | Done, smoke D | `shared/network/states/player_net_state.gd`, `player/player_loadout.gd` |
| **Window:** O (new input action `path` in `project.godot`) opens it in the lobby and breaks: one column per branch, nodes by tier (owned / available / locked, teammates who own each), Cores, this break's step, a Take button. **For Yusuf's review** (`ui/` is his) | Done, layout test | `ui/path_panel.gd`, `ui/path_node_card.gd` |
| **Starter branch "Logistics":** Fortitude (+10% max health, 1 Core) → Quick hands (reload 20% faster, 2) and Quartermaster (shop upgrades −10%, 2) → Fleet foot (+10% move speed, 3, needs Quick hands) or Scavenger (+1 Core per boss, 3, needs Quartermaster); the two tier-3 nodes lock each other out | Done, tested | `path/data/` |
| Smoke D: in the break after wave 1 the client takes Fortitude, a second step is refused, and its own loadout shows 110 max health | Done | `tests/net/shop_smoke.gd` |

### Known limitations
- Bots earn Cores but never take a step (bot branch preferences are part 6 of the plan).
- Someone joining late starts with no Cores (they only get what is paid after they join).
- Not played: the Core numbers and node costs are the plan's first draft.

## Menus share one base ✅

The Shop, Pets and Path windows were built separately, so they drifted: the "P: Pets" and
"O: Path" hints had a thicker outline than "B: Shop" (they looked bold), the windows had
different padding, and all three could be open at once.

| What | Status | Where |
|---|---|---|
| **`HudMenu`:** the base of every pop-up menu: the bottom-right hint (one style, stacked by slot), the dim, the window style, open/close with the menu's key, Esc or a click outside, the sounds, closing when a new phase starts. Hints hide while any menu is open | Done, tested | `ui/hud_menu.gd` |
| **One menu at a time:** opening a menu closes the others (P while the shop is open switches to Pets) | Done, tested | `ui/hud_menu.gd` |
| Shop, Pets and Path extend it; all three now use the shop's look (outline 4, window padding 16/12, fill 0.82) | Done, layout test | `ui/shop_panel.gd`, `ui/pet_panel.gd`, `ui/path_panel.gd` |
| A test finds every menu scene in `ui/` and fails if one looks different or two can be open; recipe `add-menu` for the next one | Done | `tests/ui/test_hud_menus.gd`, `.claude/skills/add-menu/SKILL.md` |

## Quieter rifle and rocket, new rocket blast sound ✅

| What | Status | Where |
|---|---|---|
| Rifle shot quieter (−13 → −18 dB) | Done, heard in a window | `shared/feedback/data/guns/rifle_shot.tres` |
| Rocket blast plays the launch sound, deeper (pitch 0.6) and quieter (−4 → −10 dB); `explosion_1.wav` removed | Done, heard in a window | `shared/feedback/data/default_sounds.tres` |
| `SoundCue.pitch_scale`: any sound can be played deeper or higher (default 1) | Done, tested | `shared/feedback/sound_cue.gd`, `shared/feedback/sound_playback.gd` |
| `rocket_launch_1.wav` trimmed to the launch (0.45 s): the file had a stray second burst at 1.45 s that played during reloads | Done, heard in a window | `assets/pixabay_sounds/` |

## Enemy overhaul 1: the Charger ⚠️ (issue #168; playtests to do)

The first enemy with its own move (overhaul plan: Charger, then Bomber #169, then Shielder #170).
Most enemies only walk at you; the Charger makes you sidestep and rewards baiting it into walls.

| What | Status | Where |
|---|---|---|
| **Charger** (from wave 4, 180 health): walks at you; at 340 px with line of sight it stops and warns for 0.8 s with a line along its dash (direction locked when the warning starts), then dashes 420 px at 620 px/s. A player it hits takes 25 and a big push and the dash ends | Done, tested | `enemies/data/charger.tres`, `enemies/behaviours/charge_attack.gd` |
| **Wall stun:** running head-on into a wall (not scraping along it, not another enemy) stuns it for 1.5 s: it can't act and takes 50% more damage. Stars circle over it | Done, tested | `enemies/enemy_dash.gd`, `enemies/chaser.gd` |
| **Looks:** `EnemyData.look` draws extra shapes on an enemy's sprite (looks only, every peer); the Charger's `HornsLook` has horns and kicks up dust while it dashes | Done | `enemies/looks/` |
| **Replication:** the dash line comes from the facing and telegraph clients already get; the stun is a third status bit, so the telegraph byte now has 5 bits (31 steps, was 63). Snapshot size unchanged; protocol 24 | Done, tested | `shared/network/states/enemy_net_state.gd` |

### Known limitations
- Bots don't sidestep a dash on purpose.
- A dash that hits a player ends there; the enemy can't hit two players in a row on one dash.
- Not played: the numbers are a first draft.
