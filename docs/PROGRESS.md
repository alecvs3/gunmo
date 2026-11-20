# Progress

Update this file in the same PR that finishes a feature or adds/fixes a known limitation.

## Milestone 1 — playable multiplayer core ✅ (in review)

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

### Known limitations

- No client-side prediction: clients feel a small input delay.
- Enemies move straight at players and can snag on pillars (no pathfinding).
- Players don't collide with each other. No friendly fire.
- No HUD, no way to leave a match except closing the window.
- A failed join can take up to ~30 s to report (ENet timeout).

## Milestone 2 — wave loop (planned)

Issues go on the Projects board: GameMode base, MatchSettings, enemy cost + WaveConfig,
wave budget spawner, WaveMode state machine (25 waves), wave break with ready-up,
wave-mode death rules, game over/victory, HUD (health/ammo/wave), reload state sync,
enemy pathfinding, leave-match button, CI for tests + lint.
