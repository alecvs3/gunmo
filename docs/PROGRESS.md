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
| Bullets spawned by the host, replicated by spawn data only | Done, tested | `weapons/bullet.gd`, `weapons/projectile_spawner.gd` |
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
| Smoothing for remote players and enemies | Done, tested | `shared/components/net_smoother.gd` |
| Esc menu: Resume / Leave match (host: end match for everyone) | Done | `ui/game_menu.*` |
| Dev launch args `-- --host [port]`, `-- --join ip[:port]` | Done, tested | `shared/network/launch_args.gd`, `main.gd` |
| Host validates client input (non-finite values ignored) | Done | `player/player.gd` |
| Network log lines (`[net hh:mm:ss] ...`) | Done | `shared/network/net_log.gd` |
| Network tuning in a Resource | Done | `shared/network/default_network_config.tres` |
| Three-process smoke test (host, client, wrong-build client) | Done | `tests/net/run_smoke.ps1` |

**Verified:** 56 GUT tests; smoke test passes; killing the host is detected by the client in ~6 s;
joining nobody fails after 8 s with a clear message; launch args host/join with no errors.
**Not yet verified:** the overlay and Esc menu visually, play between two computers.

### Known limitations

- No client-side prediction yet (#7): clients feel a small input delay, and their own player
  can still stutter slightly because it follows the host's updates directly.
- Enemies move straight at players and can snag on pillars (no pathfinding).
- Players don't collide with each other. No friendly fire.
- No HUD yet (health, ammo, wave).

## Movement feel ✅ (merged, issue #6)

| Feature | Status | Where |
|---|---|---|
| Physics interpolation on: no more blur/ghosting on 120-180 Hz screens | Done | `project.godot` |
| Teleports (respawn, big network corrections) skip interpolation | Done | `player/player.gd`, `shared/components/net_smoother.gd` |
| Camera updates on physics ticks so it stays in step with the player | Done | `player/player.tscn` |
| Acceleration 0.12 s, deceleration 0.08 s, top speed 300 -> 220 px/s | Done, tested | `player/player_motor.gd`, `player/data/default_player.tres` |
| Client's own player glides (rate 30) instead of jumping to each update: less stutter until #7 | Done, tested | `shared/components/net_smoother.gd` |

**Not yet verified:** that the blur is gone and the movement feels right (needs a real window).
Still to come: client prediction (#7), knockback (#8).

## Milestone 2 — wave loop (planned)

Issues go on the Projects board: GameMode base, MatchSettings, enemy cost + WaveConfig,
wave budget spawner, WaveMode state machine (25 waves), wave break with ready-up,
wave-mode death rules, game over/victory, HUD (health/ammo/wave), reload state sync,
enemy pathfinding, CI for tests + lint (the leave-match button is done).
