# pets/: Waves pets

One pet per player in Waves (Healer, Wizard, Soldier). Each has five tiers bought with credits in
the Pets window (`ui/pet_panel.gd`, P). Every tier adds an ability and strengthens earlier ones.

## Key files
| File | Job |
|---|---|
| `pet_data.gd`, `pet_tier.gd`, `pet_catalog.gd` | What a pet is (name, role, colour, kind, five tiers with prices), and every pet by index |
| `data/*.tres` | The three pets and the catalog. Append new pets; never reorder (pets travel by index) |
| `pet_look.gd` | How a pet is drawn (shapes, no art), shared by the world and the menu |
| `pet_follower.gd` | Every peer draws a player's pet floating behind them, from the replicated loadout |
| `pet_powers.gd` | Host only: runs the abilities. WaveMode tells it when waves start and clear; it reads EventBus `enemy_damaged` |
| `pet_effects.gd` | Every peer (a child of each Level): draws what pets do. The host calls `PetEffects.broadcast()` (event topic 4) |
| `healer_data.gd`, `healer_rules.gd` | The Healer's numbers and its five tiers as pure rules |
| `soldier_data.gd`, `soldier_rules.gd`, `soldier_powers.gd` | The Soldier: numbers, pure rules, and the host side (kills, Rally, covering fire, Last Stand, airstrikes, everyone's buffs) |
| `wizard_data.gd`, `wizard_rules.gd`, `wizard_powers.gd` | The Wizard: numbers, pure rules, and the host side (arcs, runes, hexes, tempest) |

## Rules that aren't obvious
- **Ownership lives on the loadout:** `PlayerLoadout.pet_index` / `pet_tier`, bought with
  `ShopRules.KIND_PET` through WaveMode's purchase request (the host checks `check_pet`).
  A different pet starts again at tier 1. Both travel in the player snapshot (public too).
- **Abilities run on the host only** (rule 1). Effects others must see go through snapshots or
  `NetChannel` events, like bullets.
- Pets are Waves only: only the Waves shop sells them, so a Gun Game loadout never has one.
- Ability numbers belong in the pet's data (`.tres`), never in code (rule 6): each kind has its
  own data class (`HealerData extends PetData`) and a pure rules class that reads it.
- **Pet damage goes through the enemy's hitbox with the owner as the source**, so kills and
  bounties go to the owner. Its damage type is `PetData.damage_type` (the Wizard is Arcane, the
  others Kinetic), so enemy traits apply to it; `WizardPowers` ignores its own damage so arcs never arc again.
- Enemies' **status** (slowed, hexed: `enemies/enemy_status.gd`) is decided on the host; clients
  get two flags packed into the telegraph byte of the enemy snapshot.
- **Buffs that change `simulate()`** (fire rate, move speed) live on the loadout
  (`set_buffs`) and travel in the owner's snapshot (`buff_fire`, `buff_move`), so prediction
  matches the host. `SoldierPowers` sets everyone's buffs every tick. Damage bonuses are host
  only (`Player.damage_bonus`), since only the host's shots deal damage.
- **Team effects don't stack:** with two Healers, Wave's End heals by the stronger one, once.

## Tests
`tests/pets/`, the layout test for the menu (`tests/ui/test_ui_layout.gd`), and smoke D (a client
adopts the Wizard and buys tier 2 over the network).
