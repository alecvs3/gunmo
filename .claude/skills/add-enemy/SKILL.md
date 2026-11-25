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
   `display_name`, `role` (frontline / ranged / swarm / support: the schedule gives each role a
   share of each wave), `color`, `visual_scale`, `max_health`, `damage_taken` (armor),
   `heal_received` (how much healing it gets; 1.0 for normal enemies),
   `move_speed`, `repath_interval`, the Behaviours group
   (`movement`: `chase.tres` or a `KeepDistanceMovement`; `attack`), knockback, and the Waves
   group (`first_wave`, `spawn_weight`, `group_size` for swarms, `bounty`). There is no cost:
   its own stats decide how much it adds to a wave, and bots rank it by that too.
   `split_into` + `split_count` make it die into other enemies (Splitter → Splitling); a
   `HealPulseAttack` makes a support that heals enemies near it (they find each other through
   the `Groups.ENEMIES` group). It **must** live in `enemies/data/`: clients only load enemy data from
   `Chaser.DATA_FOLDER`.
2. **Let the waves buy it:** add it to `enemy_types` in `modes/waves/data/default_waves.tres`
   (`WaveSchedule`). `first_wave` decides when it can show up and `spawn_weight` how often; the
   composer (`modes/waves/wave_composer.gd`) adds it while the wave is under its target
   difficulty. To keep it rare or make it required, add an `EnemyLimit` to the schedule's
   `rules` (recipe `tune-wave-difficulty`).
3. **Tests:** `tests/enemies/test_enemy_data.gd` checks every type is complete and that types
   play differently. Add to it. `tests/modes/waves/test_wave_composer.gd` checks every default wave still lands on its target and that credits by wave 22 stay put (lower `bounty` values if they don't).
4. **Wave report:** run `.\tools\wave_report.ps1` before and after, and paste both into the PR.
   The Difficulty and H M P R S columns show what the new type adds to its waves.

## A boss
A boss is an `EnemyData` in `enemies/data/bosses/` with `phases` (`BossPhase`: a health
threshold, a movement, an attack, a speed multiplier; first phase at 1.0, then lower), a big
`body_scale`, and an entry in the schedule's `boss_waves` + `bosses`. Give its attacks a
`windup` (telegraph: every peer sees a ring fill before it fires). `VolleyAttack` fires fans or
rings, `SummonAttack` calls enemies. `ends_wave_on_death` makes its death end the wave (the
final boss). The HUD's boss bar (`ui/boss_bar.gd`) finds it through `Groups.BOSSES`.
Give it a low `heal_received` (the bosses use 0.1): support pulses and Regenerating heal a
share of max health, so a boss at 1.0 out-heals the players. Add it to `BOSSES` in
`tests/enemies/test_bosses.gd`, which checks this.

## A new behaviour (keeps distance, ranged, ...)
- **Movement:** extend `EnemyMovement` (`enemies/behaviours/enemy_movement.gd`) and override
  `goal(own, target)`: the point to walk to (the enemy paths there). Pure, stateless.
- **Attack:** extend `EnemyAttack` and override `wants_to_attack(cooldown_left, distance,
  can_see)` (pure) and `perform(enemy, target, touching)` (host; return true to restart the
  cooldown). Tuning goes in the behaviour's `@export`s, not in `EnemyData`.
- Put a GUT test for its pure decisions in `tests/enemies/test_enemy_behaviours.gd`.
- Override `add_stats(stats, weight)` so the wave difficulty score sees what the attack does
  (damage, healing or summons per second; recipe `tune-wave-difficulty`).
- **AI runs only on the host** (rule 3). Clients only draw it.
- Shots go through EventBus `shot_fired` like a player's, so `ProjectileSystem` handles them.
- Death fires EventBus `enemy_killed`. Never call into the mode directly.
- Plan first: this is bigger than a data change, so list the files and wait for an OK.

Run `.\tools\check.ps1 -Changed` (scenario C plays the wave loop) and update `docs/PROGRESS.md`.
