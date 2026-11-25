---
name: add-weapon
description: Add a new gun to the game (shop, Gun Game ladder or both). Use when asked to add, create or design a weapon.
---

# Add a weapon

Area: **Alex** (`weapons/`, `upgrades/`). A weapon is data only, unless it needs a new mechanic.

1. **Create `weapons/data/<name>.tres`** (a `WeaponData`, `weapons/weapon_data.gd`). Copy the
   closest existing weapon and change its numbers: `display_name`, `pose` (GUN, MACHINE or
   SILENCER: how the character holds it), `price`, `pellets`, `pierce`, `damage`, `fire_rate`,
   `bullet_speed`, `bullet_lifetime`, `spread`, `magazine_size`, `reload_time`, `bullet_radius`,
   `knockback`, and what each upgrade level adds to it: `damage_per_level`,
   `fire_rate_per_level`, `magazine_per_level`, `reload_per_level`, `knockback_per_level`
   (and `blast_damage_per_level` if it explodes). Every one must be above 0, so every level
   does something (`tests/upgrades/test_player_stats.gd` checks). No numbers in code (rule 6).
2. **Add it to the shop catalog:** append it to `weapons` in `upgrades/data/shop_catalog.tres`.
   Every peer names weapons by **catalog index**, so append and never reorder. Index 0 must stay
   the free starting pistol. The shop lists it automatically (`ui/shop_panel.gd`), and the build
   fingerprint covers the new file, so nothing else needs registering.
3. **Gun Game:** to use it on the ladder, add it to `ladder` in `modes/data/gun_game_match.tres`.
   It must also be in the catalog (step 2).
   - **Explodes?** Set `blast_radius` and `blast_damage` (see `weapons/data/rocket_launcher.tres`).
   - **Looks:** every gun gets a `held_model`, a scene of Polygon2D shapes drawn at the muzzle
     that covers the gun painted into the character picture (copy one from `weapons/models/`
     and check it on every character). `projectile` (BULLET, ROCKET, PELLET or RIFLE_ROUND)
     picks what flies. A new projectile look = a new scene, a new value at the END of
     `WeaponData.Projectile` and an entry in `PROJECTILE_SCENES` (`weapons/projectile_system.gd`).
   - **Sound:** set `fire_sound` to a `SoundCue` in `shared/feedback/data/guns/` (a new kind of
     gun can share one, e.g. any rifle uses `rifle_shot.tres`). A new sound file goes in
     `assets/pixabay_sounds/` with its source in that folder's README. Every shop gun needs one
     (`tests/shared/feedback/test_sounds.gd` checks).
4. **Needs a new mechanic** (burst, charge...)?
   - Add an `@export` field to `WeaponData` and use it in `shared/components/weapon_component.gd`
     or `weapons/bullet.gd`.
   - Keep `Player.simulate()` deterministic: randomness comes from `WeaponComponent.shot_seed`.
   - If the shot announcement must carry it, change the event in `weapons/projectile_system.gd`
     and bump `Handshake.PROTOCOL` (`shared/network/handshake.gd`).
   - If it changes stats under upgrades, update `upgrades/player_stats.gd` and its tests.
5. **Tests:**
   - Add what makes it different to `tests/weapons/test_weapon_set.gd`.
   - `tests/test_project_consistency.gd` already checks every `.tres` loads.
   - A new mechanic gets its own unit test in `tests/weapons/`.
6. **Run** `.\tools\check.ps1 -Changed` and note it in `docs/PROGRESS.md`.

Don't forget: a fourth pose would need a picture in every look (`player/looks/*.tres`,
`player/character_look.gd`). Use an existing pose unless art for a new one exists.
