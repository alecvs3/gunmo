---
name: add-upgrade
description: Add a new shop upgrade (a stat players buy levels of between waves). Use when asked to add or design an upgrade.
---

# Add an upgrade

Area: **Alex** (`upgrades/`).

## On an existing stat (data only)
1. **Create `upgrades/data/<name>.tres`** (an `UpgradeData`, `upgrades/upgrade_data.gd`):
   `display_name`, `description`, `stat`, `per_level` (0.1 = +10% per level), `max_level`,
   `base_cost`, `cost_growth`.
2. **Append it to `upgrades`** in `upgrades/data/shop_catalog.tres`. Never reorder: levels
   travel by index. There's room for `ShopCatalog.MAX_UPGRADES` (16).
3. **Tests:** stacking is covered in `tests/upgrades/test_player_stats.gd`. Add a case if it
   stacks with another upgrade on the same stat. Pricing rules are in `tests/upgrades/test_shop_rules.gd`.

## A perk (adds hit effects to your bullets)
An upgrade with `effects` set is a perk (`UpgradeData.is_perk()`). A player may own only
`max_perks` different perks (`upgrades/data/shop_catalog.tres`), and that choice is their build.
1. Create `upgrades/data/perk_<name>.tres` with `effects` = a `HitEffects` sub-resource. Copy
   `upgrades/data/perk_incendiary.tres`. Each level adds those effects once.
2. Append it to `upgrades` in the catalog, like any upgrade.
3. A new kind of effect (not burn, chill, shock, shred or blast) is bigger: see "Hit effects and
   perks" in `weapons/CLAUDE.md`.
4. Tests: `tests/upgrades/test_perks.gd` (owning, the perk limit, stacking).

## On a new stat
1. Add the stat to `UpgradeData.Stat` (append at the end; the enum value is saved in `.tres` files).
2. Apply it in `upgrades/player_stats.gd` (`effective_weapon` or `effective_player`). It must
   stay pure and deterministic, because the host and the predicting owner both compute it.
3. Use the effective number where it matters (`player/player_loadout.gd` hands out the effective
   `WeaponData` and `PlayerData`).
4. Add a test in `tests/upgrades/test_player_stats.gd`.

Upgrade levels are already in the player's snapshot, so no network change is needed.
Run `.\tools\check.ps1 -Smoke` (scenario D is the shop) and update `docs/PROGRESS.md`.
