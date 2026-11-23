---
name: add-enemy
description: Add a new enemy type to wave mode. Use when asked to add, create or design an enemy.
---

# Add an enemy

Area: `enemies/`, `modes/waves/` (no fixed owner for now; say what you're changing).

## A new enemy type (data only)
One scene, `enemies/chaser.tscn`, plays every `EnemyData`. An enemy type is a combination of
a **movement** behaviour (`enemies/behaviours/`, e.g. `enemies/behaviours/data/chase.tres`) and an **attack**
behaviour (e.g. a `MeleeAttack` sub-resource with its damage, interval and knockback, or a
`RangedAttack` with a bullet `WeaponData` such as `enemies/behaviours/data/enemy_bolt.tres`,
a range and a lead).
1. **Create `enemies/data/<name>.tres`** (an `EnemyData`, `enemies/enemy_data.gd`). Copy the
   closest type (grunt, runner, brute, shooter, tank, swarmer) and change its numbers:
   `display_name`, `color`, `visual_scale`, `max_health`, `damage_taken` (armor),
   `move_speed`, `repath_interval`, the Behaviours group
   (`movement`: `chase.tres` or a `KeepDistanceMovement`; `attack`), knockback, and the Waves
   group (`cost`, `first_wave`, `spawn_weight`, `group_size` for swarms, `bounty`). It **must** live in `enemies/data/`: clients only load enemy data from
   `Chaser.DATA_FOLDER`.
2. **Let the waves buy it:** add it to `enemy_types` in `modes/waves/data/default_waves.tres`
   (`WaveSchedule`). `cost` and `first_wave` decide when it shows up (`modes/waves/wave_budget.gd`).
3. **Tests:** `tests/enemies/test_enemy_data.gd` checks every type is complete and that types
   play differently. Add to it. If wave budgets change, check `tests/modes/waves/test_wave_budget.gd`.
4. **Wave report:** run `.\tools\wave_report.ps1` before and after, and paste both into the PR.

## A new behaviour (keeps distance, ranged, ...)
- **Movement:** extend `EnemyMovement` (`enemies/behaviours/enemy_movement.gd`) and override
  `goal(own, target)`: the point to walk to (the enemy paths there). Pure, stateless.
- **Attack:** extend `EnemyAttack` and override `wants_to_attack(cooldown_left, distance,
  can_see)` (pure) and `perform(enemy, target, touching)` (host; return true to restart the
  cooldown). Tuning goes in the behaviour's `@export`s, not in `EnemyData`.
- Put a GUT test for its pure decisions in `tests/enemies/test_enemy_behaviours.gd`.
- **AI runs only on the host** (rule 3). Clients only draw it.
- Shots go through EventBus `shot_fired` like a player's, so `ProjectileSystem` handles them.
- Death fires EventBus `enemy_killed`. Never call into the mode directly.
- Plan first: this is bigger than a data change, so list the files and wait for an OK.

Run `.\tools\check.ps1 -Smoke` (scenario C plays the wave loop) and update `docs/PROGRESS.md`.
