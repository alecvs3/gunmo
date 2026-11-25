---
name: tune-wave-difficulty
description: Change how hard Waves mode is (the 0–10 wave difficulty score, its target curve, or its categories). Use when asked to make waves harder or easier, reshape the curve, change how a boss wave stands out, add a difficulty category, or recalibrate the score.
---

# Tune wave difficulty

Area: `modes/waves/difficulty/`, `enemies/enemy_stats.gd` (no fixed owner; say what you're
changing). How it works: `modes/CLAUDE.md`, "Wave difficulty".

Every change ends the same way: run `.\tools\wave_report.ps1` before and after and paste both
into the PR (the Target, Difficulty and H M P R S columns), then `.\tools\check.ps1 -Changed`.

## Make the game harder or easier, or reshape the curve (data only)
Edit the `DifficultyCurve` sub-resource in `modes/waves/data/default_waves.tres`:
- `first` / `last`: the trend's value in wave 1 and the last wave. "15% harder" = both × 1.15.
- `power`: 1 = straight; above 1 = easy start, steep end.
- `boss_bonus`, `last_wave_bonus`: how far a boss wave (and the final wave) sits above the trend.
- `after_boss`: how far the 1st, 2nd... wave after a boss dips. Keep a boss wave only a little
  above the next wave (`tests/modes/waves/difficulty/test_difficulty_curve.gd` checks < 0.6).
- `tolerance`: how close a wave must land to its target.
- `overrides`: pin a wave's target (`overrides[w - 1]`, 0 = use the curve).

## Limit or require enemies, or make a themed wave (data only)
Append to `rules` in `default_waves.tres` (each has `from_wave`, `to_wave`, 0 = to the end):
- `EnemyLimit`: `enemy`, `min_count`, `max_count` (-1 = none). "At most 3 Tanks before wave 18".
- `AxisLimit`: `axis` (index into the model's `axes`: 0 H, 1 M, 2 P, 3 R, 4 S), `max_share`
  (a pick that takes the axis past it is refused) and `min_share` (below it, types that add to
  the axis are `push` times likelier): "wave 14 is a ranged wave".
`test_every_default_wave_lands_near_its_target` (`tests/modes/waves/test_wave_composer.gd`) fails
when rules make a target unreachable.

## Credits
More enemies pay more bounty. `test_credits_by_wave_22_stay_where_the_balance_pass_left_them`
keeps a player's credits by wave 22 near 8,650 (balance pass #139). If a harder curve breaks it,
lower the `bounty` values in `enemies/data/` by the same factor rather than widening the test.

## Weigh a category more or less (data only)
In `modes/waves/data/difficulty_model.tres`, each axis has a `weight` (how much it counts) and a
`reference` (the raw amount that scores 10). A bigger reference makes the same enemies score
lower on that axis. `exponent` (0.7) softens growth on every axis.

## Add a category (an axis)
1. **Script:** `modes/waves/difficulty/<name>_axis.gd`, `extends DifficultyAxis`, overriding
   `raw(sheet, modifier)`: read summed stats with `sheet.total(EnemyStats.<KEY>)` and apply the
   modifiers that touch it (`toughness(modifier)` for health, `modifier.speed_multiplier`, ...).
   Knobs the axis needs are `@export`s on it (like `PressureAxis.reference_speed`).
2. **Stat (if no existing key fits):** add a `const` key to `enemies/enemy_stats.gd` and set it
   where it comes from: in `EnemyStats.of()` for `EnemyData` numbers, or in the attack's
   `add_stats()` for what an attack does (times `weight`, per second via `cycle_seconds()`).
3. **Data:** append a sub-resource to `axes` in `difficulty_model.tres` with `display_name`, a
   one-letter `short_name` (the report column), `weight`, and a `reference`. To pick the
   reference, print the axis's raw amount for wave 24 (a hard normal wave) and start there.
4. **Test:** a case in `tests/modes/waves/difficulty/test_difficulty_model.gd` for what the new
   axis counts and which modifier moves it. `test_the_default_model_has_named_axes` checks the
   axis count: update it.
5. Adding an axis lowers every wave's score a little (the length averages over more weights).
   Recalibrate the references, or the curve, so wave 25 stays near 10.

## A new attack behaviour
Override `add_stats(stats, weight)` in it (see `MeleeAttack`, `VolleyAttack`, `SummonAttack`).
Without it the score can't see the attack: `tests/enemies/test_enemy_stats.gd`
(`test_every_enemy_does_something_the_score_sees`) fails for any enemy that uses it.

## Recalibrate
The model is a guess until people play it. After a playtest, if a wave felt harder or easier than
its score says, find the axis that's off in the report and change that axis's `reference` or
`weight`, not the curve. Note in the PR which waves felt wrong and why.
