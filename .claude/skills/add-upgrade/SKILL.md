---
name: add-upgrade
description: Add a new shop upgrade (a stat players buy levels of between waves). Use when asked to add or design an upgrade.
---

# Add an upgrade

Area: **Alex** (`upgrades/`).

## How much a level gives
- **Gun stats** (damage, fire rate, magazine, reload speed, knockback): each gun sets what one
  level adds to it, in its `.tres` ("Per upgrade level" in `WeaponData`). Leave `per_level` at 0.
- **Player stats** (move speed, max health): `per_level` on the upgrade (0.1 = +10% per level).

## On an existing stat (data only)
1. **Create `upgrades/data/<name>.tres`** (an `UpgradeData`, `upgrades/upgrade_data.gd`):
   `display_name`, `description`, `stat`, `per_level` (player stats only), `max_level`,
   `base_cost`, `cost_growth`.
2. **Append it to `upgrades`** in `upgrades/data/shop_catalog.tres`. Never reorder: levels
   travel by index. There's room for `ShopCatalog.MAX_UPGRADES` (16).
3. **Tests:** stacking is covered in `tests/upgrades/test_player_stats.gd`. Add a case if it
   stacks with another upgrade on the same stat. Pricing rules are in `tests/upgrades/test_shop_rules.gd`.

## On a new stat
1. Add the stat to `UpgradeData.Stat` (append at the end; the enum value is saved in `.tres` files).
2. Apply it in `upgrades/player_stats.gd` (`effective_weapon` or `effective_player`). A gun
   stat needs a `<stat>_per_level` field on every gun (`weapons/weapon_data.gd`), an entry in
   `UpgradeData.is_weapon_stat`, and a line in `ShopPanel.gain_text` (`ui/shop_panel.gd`). It must
   stay pure and deterministic, because the host and the predicting owner both compute it.
3. Use the effective number where it matters (`player/player_loadout.gd` hands out the effective
   `WeaponData` and `PlayerData`).
4. Add a test in `tests/upgrades/test_player_stats.gd`.

Upgrade levels are already in the player's snapshot, so no network change is needed.
Run `.\tools\check.ps1 -Changed` (scenario D is the shop) and update `docs/PROGRESS.md`.
