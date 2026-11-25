---
name: add-damage-type
description: Add a damage type (like Kinetic, Pierce, Blast, Arcane) or an enemy trait that resists or fears one. Use when asked for a new kind of damage, a new resistance or weakness, or a new counter.
---

# Add a damage type or a trait

Area: `shared/components/` (both developers review), `enemies/`, `weapons/`. How counters work:
every hit has a damage type (`shared/components/damage_type.gd`), every enemy has traits
(`EnemyTrait`, `enemies/enemy_trait.gd`), and the host multiplies the damage by the target's
traits for that type (`HealthComponent.type_multipliers`, set by `enemies/chaser.gd`). The type
never travels on the network: the host takes it from its own `WeaponData` or `PetData`.

## A new trait (data only)
1. **Create `enemies/data/traits/<name>.tres`** (an `EnemyTrait`): `display_name` and one
   multiplier per type (`kinetic`, `pierce`, `blast`, `arcane`; 1.0 = normal). Give it a clear
   weakness and a clear strength, so one damage type answers it.
2. **Use it:** on an enemy (`traits` in `enemies/data/<enemy>.tres`, recipe `add-enemy`) or on a
   whole wave (`adds_traits` on a `WaveModifier`, recipe `add-wave-modifier`).
3. **Keep the difficulty score where it is** if you mean to: the score is Kinetic-based, so a
   trait with `kinetic` ≠ 1.0 changes the Toughness axis (and the composer then gives its waves
   fewer or more enemies). A trait that only moves the other types leaves the wave report as it
   was. Either way, paste `.\tools\wave_report.ps1` before and after into the PR.
4. **Tests:** add its row to `test_every_type_against_every_trait` in
   `tests/enemies/test_enemy_trait.gd`, and a `CounterProfile` case
   (`tests/modes/waves/difficulty/test_counter_profile.gd`) for the type that should beat it.

## A new damage type
1. **Append it** to `DamageType.Type` and `DamageType.NAMES`, and raise `DamageType.COUNT`
   (`shared/components/damage_type.gd`). Append only: `.tres` files store the type as a number.
2. **Give every trait a multiplier for it:** an `@export` on `EnemyTrait` (default 1.0) and a
   branch in `EnemyTrait.multiplier()`. Set it in each file in `enemies/data/traits/`.
3. **Something must deal it:** a gun (`damage_type` in `weapons/data/<gun>.tres`, recipe
   `add-weapon`) or a pet (`damage_type` in `pets/data/<pet>.tres`). A new source of damage
   passes the type to `HitboxComponent.hit(damage, source_id, push, damage_type)`.
4. No network change: the type is host only. If a client ever needs to see it (a hit colour),
   that is a network format change: bump `Handshake.PROTOCOL`.
5. **Tests:** `tests/enemies/test_enemy_trait.gd` (`test_every_type_has_a_name` and the table),
   and whatever deals it (`tests/weapons/test_weapon_set.gd` `test_damage_types`, or
   `tests/pets/test_pets.gd`).

The forecast reads `CounterProfile` (`modes/waves/difficulty/counter_profile.gd`), which loops
over every type, so it can name the new one ("Bring: <type>") without changes.

Run `.\tools\check.ps1 -Changed` (a `shared/` change runs every smoke scenario; scenario E checks
rockets deal Blast on the host) and update `docs/PROGRESS.md`.
