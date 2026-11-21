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

- Enemies move straight at players and can snag on pillars (no pathfinding).
- Players don't collide with each other. No friendly fire in co-op (by team).
- No HUD yet (health, ammo, wave).
- The host sees remote players move in small steps when their commands arrive unevenly.
- GUT prints Godot leak warnings at exit on this branch (the game itself shuts down cleanly);
  traced to engine/GUT shutdown order with the Replicator node, not to a runtime leak.

## Display smoothness ✅ (in review, issue #16)

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

## Milestone 2 — wave loop (planned)

Issues go on the Projects board: GameMode base, MatchSettings, enemy cost + WaveConfig,
wave budget spawner, WaveMode state machine (25 waves), wave break with ready-up,
wave-mode death rules, game over/victory, HUD (health/ammo/wave), reload state sync,
enemy pathfinding, CI for tests + lint (the leave-match button is done).
