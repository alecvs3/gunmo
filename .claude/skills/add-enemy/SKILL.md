---
name: add-enemy
description: Add a new enemy type to wave mode. Use when asked to add, create or design an enemy.
---

# Add an enemy

Area: `enemies/`, `modes/waves/` (no fixed owner for now; say what you're changing).

## A new chaser type (data only)
One scene, `enemies/chaser.tscn`, plays every `EnemyData`.
1. **Create `enemies/data/<name>.tres`** (an `EnemyData`, `enemies/enemy_data.gd`). Copy the
   closest type (grunt, runner, brute) and change its numbers: `display_name`, `color`,
   `visual_scale`, `max_health`, `move_speed`, `repath_interval`, `contact_damage`,
   `contact_interval`, knockback, and the Waves group (`cost`, `first_wave`, `spawn_weight`,
   `bounty`). It **must** live in `enemies/data/`: clients only load enemy data from
   `Chaser.DATA_FOLDER`.
2. **Let the waves buy it:** add it to `enemy_types` in `modes/waves/data/default_waves.tres`
   (`WaveSchedule`). `cost` and `first_wave` decide when it shows up (`modes/waves/wave_budget.gd`).
3. **Tests:** `tests/enemies/test_enemy_data.gd` checks every type is complete and that types
   play differently. Add to it. If wave budgets change, check `tests/modes/waves/test_wave_budget.gd`.
4. **Wave report:** run `.\tools\wave_report.ps1` before and after, and paste both into the PR.

## A new behaviour (ranged, splitting, exploding...)
- Make a new scene and script in `enemies/`, built from the shared components (Health, Hitbox,
  Knockback; `WeaponComponent` if it shoots). Give it a `NetEntity` (kind `ENEMY`) and
  `capture_net_state()` / `apply_net_state()` like `enemies/chaser.gd`.
- **AI runs only on the host** (rule 3). Clients only draw it.
- New tuning goes in `EnemyData` as `@export`s.
- Its shots go through EventBus `shot_fired` like a player's, so `ProjectileSystem` handles them.
- Add the scene to the level's enemy `MultiplayerSpawner`, and keep that `.tscn` diff small.
- Death fires EventBus `enemy_killed`. Never call into the mode directly.
- Plan first: this is bigger than a data change, so list the files and wait for an OK.

Run `.\tools\check.ps1 -Smoke` (scenario C plays the wave loop) and update `docs/PROGRESS.md`.
