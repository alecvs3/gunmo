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

## Rules that aren't obvious
- **Ownership lives on the loadout:** `PlayerLoadout.pet_index` / `pet_tier`, bought with
  `ShopRules.KIND_PET` through WaveMode's purchase request (the host checks `check_pet`).
  A different pet starts again at tier 1. Both travel in the player snapshot (public too).
- **Abilities run on the host only** (rule 1). Effects others must see go through snapshots or
  `NetChannel` events, like bullets.
- Pets are Waves only: only the Waves shop sells them, so a Gun Game loadout never has one.
- Ability numbers belong in the pet's data (`.tres`), never in code (rule 6).

## Tests
`tests/pets/`, the layout test for the menu (`tests/ui/test_ui_layout.gd`), and smoke D (a client
adopts the Wizard and buys tier 2 over the network).
