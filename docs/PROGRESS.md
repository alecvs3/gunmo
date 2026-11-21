# Progress

Update this file in the same PR that finishes a feature or adds/fixes a known limitation.

## Milestone 1 — playable multiplayer core ✅ (merged)

Branch `m1-core`. Neither game mode exists yet; this is a test arena.

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
**Not yet verified:** windowed play (visuals, camera, real mouse), play between two computers.

## Networking hardening ✅ (merged, issue #4)

Branch `net-hardening`, stacked on `m1-core`.

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
**Not yet verified:** the overlay and Esc menu visually, play between two computers.


## Movement feel ✅ (merged, issue #6)

| Feature | Status | Where |
|---|---|---|
| Physics interpolation on: no more blur/ghosting on 120-180 Hz screens | Done | `project.godot` |
| Teleports (respawn, big network corrections) skip interpolation | Done | `player/`, `shared/network/` |
| Camera updates on physics ticks so it stays in step with the player | Done | `player/player.tscn` |
| Acceleration 0.12 s, deceleration 0.08 s, top speed 300 -> 220 px/s | Done, tested | `player/player_motor.gd`, `player/data/default_player.tres` |
| Client's own player glides instead of jumping to each update | Done; replaced by prediction (netcode) | — |

**Not yet verified:** that the blur is gone and the movement feels right (needs a real window).

## Netcode foundation ✅ (merged, issues #10 #11 #7 #12 #13 #14 #8)

Branch `netcode-foundation`. How it works and how to extend it: [NETCODE.md](NETCODE.md).

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
**Not yet verified:** windowed play (feel of aim, movement, corrections, knockback), two PCs.

### Known limitations

- Players don't collide with each other. No friendly fire in co-op (by team).
- The host sees remote players move in small steps when their commands arrive unevenly.
- GUT prints Godot leak warnings at exit on this branch (the game itself shuts down cleanly);
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

Branch `milestone-2`, one commit per issue.

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
**Not yet verified:** a full 25-wave match by people (balance), two PCs, the CI run itself
(first run happens on the PR).

### Known limitations

- Balance is a first guess: tune `modes/waves/data/default_waves.tres` and `enemies/data/*.tres`.
- ~~Players have no names yet~~ (names added in M4; the spectate line still says "a teammate").
- The command-line `--import` crashes now and then on an already-imported working copy right
  after files changed (a Godot 4.7.2 cache bug; running it again works, a fresh clone
  imports fine). If the editor crashes once after pulling, open it again.
- Only one map.

## Milestone 3 — upgrades and combat depth ✅ (merged, issues #26–#31)

Branch `milestone-3`, one commit per issue.

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
**Not yet verified:** economy and balance over a full 25-wave match with people; two PCs.

### Known limitations

- Prices, upgrade strengths, bounties and modifier strengths are a first guess (all in `.tres` files).
- The shop panel has room for about 7 upgrades at 648 px height; more will need a scroll area.
- No hit marker yet (`ProjectileSystem.hit_confirmed` is there for it).

## Milestone 4 — Gun Game and bots ✅ (merged, issues #33–#37)

Branch `milestone-4`, one commit per issue.

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

- Bots are Gun Game only. They don't dodge bullets, and they roam between respawn points rather
  than reading the map.
- The ladder only uses guns from the shop catalog (4 so far), so the default ladder is short.
- Gun Game has no lobby or countdown: it starts when the host hosts, and the host's "Play
  again" restarts it.
- Bot difficulty, ladder length and kills per gun are first guesses (`bots/profiles/*.tres`,
  `modes/data/gun_game_match.tres`).

## Foundations, part 1: tooling, safety nets, stress test, latency ✅ (merged)

Branch `foundations`. The rest of the Foundations plan (#43 performance fixes, #44 refactors,
#46 rejoin, #47 soak/fuzz/rate limit, #48 release builds, #49 settings menu, #50 folder guides)
is still open.

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

- The old fixed 100 ms delay left clients with higher ping (Yusuf on Tailscale) barely any
  buffer, which likely added to the stutter. Fixed: the delay now includes the latency.
- Headless test runs pace frames every 7–16 ms, so the host may hold back 1 tick of a clean
  connection's inputs there; windowed play at high refresh rates should need less.
- The stress test uses one real client; snapshot encoding cost grows with the number of
  clients (each gets its own packets). To measure with more clients in #43.
- The host's tick cost rose a little with 60 snapshots/s (more encoding); #43 looks at it.

## Placeholder art: Kenney top-down shooter ✅ (merged, issue #62)

Branch `placeholder-art`. Mostly looks; the gameplay changes are where shots start, the aim
angle, and the player's collision sizes. Network messages are unchanged.

| What | How | Where |
|---|---|---|
| Players | One character sprite under the aim pivot (it turns with the aim) replaces the octagon and barrel. Each peer gets a character from its peer id (Man Blue, Man Brown, Survivor, Soldier); bots get Robot or Hitman. Every peer picks the same one, so nothing is sent. | `player/player_look.gd`, `player/character_look.gd`, `player/looks/*.tres`, `PlayerData.player_looks` / `bot_looks` |
| Weapon poses | `WeaponData.pose` (gun / machine / silencer) replaces the barrel color: pistol gun, SMG and rifle machine, shotgun silencer | `weapons/weapon_data.gd`, `weapons/data/*.tres` |
| Enemies | Zombie sprite, tinted by `EnemyData.color` and the wave modifiers, drawn at `EnemyData.visual_scale` (brute 1.25), turns to face where it moves on every peer | `enemies/chaser.*`, `enemies/data/*.tres` |
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
- Characters are picked from the peer id, so two players can get the same one.
- Bullets are still shapes; menus and HUD are unchanged.

## Latency tier 1: fair play at high ping ✅ (merged, issues #57–#61)

Branch `latency-tier1`. Aimed at Yusuf's report (160 ms round trip): bots "shooting all over
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

Branch `ui/fullscreen`. Display only: nothing is sent over the network.

| What | How | Where |
|---|---|---|
| Fullscreen setting | `GameSettings.fullscreen`, saved in `user://settings.cfg` next to the name and applied on start. Borderless fullscreen (covers the screen, quick Alt+Tab) | `autoloads/game_settings.gd` |
| Keys | Input action `toggle_fullscreen`: **F11** and **Alt+Enter**, handled before the GUI so Alt+Enter doesn't also press a focused button | `project.godot`, `autoloads/game_settings.gd` |
| Menus | "Fullscreen (F11)" checkbox in the main menu and the Esc menu; both follow the keys and each other | `ui/fullscreen_check.gd`, `ui/main_menu.tscn`, `ui/game_menu.tscn` |

**Verified:** 6 new GUT tests (`tests/autoloads/test_game_settings.gd`, using a test settings file);
lint/format clean.

### Known limitations

- No exclusive fullscreen option (it can lower input delay a little on some PCs, but Alt+Tab is slower).
- Fullscreen uses the screen the window is on; there is no monitor picker.

## Builds: more guns, hit effects and perks ✅ (merged, issue #67)

Goal: players can build different characters, and late waves get strategy from systems that
combine (the CLAUDE.md goal) instead of from more health.

| Feature | Status | Where |
|---|---|---|
| Hit effects as data (`HitEffects`): burn (damage over time), chill (slow), shock (arcs to nearby foes), shred (target takes more damage from everyone), blast (area damage, also where a bullet stops) | Done, tested | `weapons/hit_effects.gd` |
| Host applies them on every hit; arcs and blasts pass burn/chill/shred on but never chain further; everyone sees arcs and blasts (new `EVENT_FLASH`) | Done, tested | `weapons/impact_effects.gd`, `weapons/projectile_system.gd`, `weapons/effect_flash.gd` |
| Status component on enemies: burn credited to the shooter (kill and bounty), chill capped per enemy (`EnemyData.max_slow`, brutes 0.35), shred also boosts burns; enemy snapshots carry the status flags (rings drawn on the enemy) | Done, tested | `shared/components/status_effects_component.gd`, `status_marks.gd`, `enemies/chaser.gd` |
| Combos with wave modifiers: burning stops Regenerating, chill answers Fast, shred cuts through Armored, arcs/blasts answer big crowds | Done | as above |
| 6 new guns: Revolver (pierce), Torch (burn), Cryo Carbine (chill), Arc Caster (shock), Launcher (blast), Railgun (pierce 6 + shred) | Done | `weapons/data/*.tres` |
| 5 perks (shop upgrades with effects, 3 levels each): Incendiary, Cryo, Arc, Shredder, Explosive rounds. **Only 2 different perks per player** (`ShopCatalog.max_perks`), so the choice is your build; the host checks the slots | Done, tested | `upgrades/data/perk_*.tres`, `upgrades/shop_rules.gd` |
| Shop: scrollable, perks in their own list with "x of 2 chosen" | Done, not checked in a window | `ui/shop_panel.*` |
| Gun Game ladder: SMG → Revolver → Arc Caster → Rifle → Launcher → Shotgun → Railgun → Pistol, 2 kills per gun (2 on the last) | Done | `modes/data/gun_game_match.tres` |
| Smoke scenario D: the client buys two perks, a third is refused, and it sees enemies burning | Done | `tests/net/shop_smoke.gd` |

Protocol 8 (enemy snapshots +1 byte for status flags, bullets +1 byte for their effects).

### Known limitations

- Balance is a first guess (all numbers in `weapons/data/*.tres`, `upgrades/data/perk_*.tres`).
- Players have no status component yet: in Gun Game burn, chill and shred do nothing to
  players (arcs and blasts still hit them). Torch and Cryo Carbine are left off the ladder for
  that reason. Chilling players would also need the slow in the owner's prediction.
- Arcs and blasts use where foes are now (not lag-compensated) and go through walls.
- Each Torch shot is 2 reliable bullet events, so a full lobby of Torches adds traffic (#43).
- **Not verified:** playing it in a window (shop layout, effect rings, arcs, blasts), how the
  guns feel, two PCs.

## Foundations: refactors for clarity ✅ (in review, issue #44)

Branch `refactor-clarity`. No behaviour or network format change (protocol stays 7).

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

## Foundations: guides for Claude ✅ (in review, issue #50)

Branch `ai-guides`. Makes the project quick for Claude (and new readers) to work in without
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

## Faster checks ✅ (in review, issue #71)

The smoke scenarios A-E (behaviour only) run at the same time, each on its own port; F (stress), G (latency) and H (fairness) measure timing and still run alone afterwards. Stress measures 12 s (was 20), fairness plays 20 s (was 30). `.\tools\check.ps1 -Smoke` went from about 4.5 minutes to about 2 minutes on Alex's PC; `-Scenarios A,E` runs only some (`run_smoke.ps1 -Only`).

