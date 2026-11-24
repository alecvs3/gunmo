---
name: add-wave-modifier
description: Add a wave modifier (a rule applied to every enemy of a wave, like armored, fast or regenerating). Use when asked to add or design a modifier.
---

# Add a wave modifier

Area: `modes/waves/` (no fixed owner for now; say what you're changing).

## Using the existing knobs (data only)
1. **Create `modes/waves/data/modifiers/<name>.tres`** (a `WaveModifier`,
   `modes/waves/wave_modifier.gd`): `display_name`, `color` (enemies are tinted toward it),
   `health_multiplier`, `speed_multiplier`, `damage_taken_multiplier`, `regen_per_second`
   (times each enemy's `heal_received`, so bosses barely regenerate),
   and `conflicts_with` (display names it never shares a wave with, e.g. Frenzied and Fast).
2. **Append it to `modifiers`** in `modes/waves/data/modifier_catalog.tres`. Active modifiers
   travel as a one-byte mask by index, so append and never reorder. There's room for 8
   (`ModifierCatalog.MAX_MODIFIERS`).
3. When modifiers start is set by `first_modifier_wave` / `double_modifier_wave` /
   `triple_modifier_wave` in `modes/waves/data/default_waves.tres`. However many stack, the
   merged numbers stay within the catalog's caps (`max_health_multiplier`, ...).
4. **Tests:** `tests/modes/waves/test_modifier_catalog.gd` (combining, names, the default catalog).
5. **Wave report:** run `.\tools\wave_report.ps1` before and after, and paste both into the PR
   (the Effective column shows armor; regeneration isn't in it).

## A new kind of effect
Modifiers should create strategy by combining (CLAUDE.md: systems that combine, not scripted
scenarios).
1. Add an `@export` to `WaveModifier`, and say how two of them combine in
   `ModifierCatalog.combined()`: multiply, add or average.
2. Apply it in the enemy (`enemies/chaser.gd` `_apply_modifiers`), on the host for anything that
   matters. Every peer may apply looks.
3. Add a test for how it combines.
4. More than 8 modifiers means a wider mask: a network format change that bumps
   `Handshake.PROTOCOL` (`shared/network/handshake.gd`).

Run `.\tools\check.ps1 -Changed` (scenario D checks modifiers reach the client) and update `docs/PROGRESS.md`.
