# weapons/: guns, shots and bullets

Owner: **Alex**. Weapon numbers live in `data/*.tres` (`WeaponData`). Firing rate, ammo and
reloading are `shared/components/weapon_component.gd`.

## A shot's life
1. `Player.simulate()` decides to fire and builds one `Shot` per pellet (`shot.gd`): origin,
   direction with seeded spread, the weapon's numbers, `fire_tick` and `view_tick`.
2. Host: EventBus `shot_fired` → `projectile_system.gd` spawns an AUTHORITATIVE `Bullet` and
   announces it to everyone except the shooter (reliable event, `EVENT_FIRED`).
   Owner client: `shot_predicted` → a PREDICTED bullet, shown at once, deals nothing.
   Other clients: a REMOTE bullet, drawn on their render timeline.
3. The host's bullet sweeps along its path each tick (`bullet.gd`). Human shots are tested
   with lag compensation (what the shooter saw). A bot's shots are tested against remote humans
   on their own timeline (`timeline_hits.gd`, fair dodging).
4. On a hit the host applies damage and knockback, then tells the shooter (`EVENT_HIT`) and
   the victim (`EVENT_HURT`). When the bullet ends, everyone is told where and when
   (`EVENT_ENDED`).

## Rules that aren't obvious
- **Only AUTHORITATIVE bullets deal damage.**
- A REMOTE bullet that passes near your own player catches up to the present over 0.2 s, so a
  bullet that hits you visibly reaches you.
- Weapons are referred to by **index in the shop catalog** (`upgrades/data/shop_catalog.tres`)
  everywhere on the network. Gun Game ladder entries must be in that catalog.
- Changing an event's payload is a network format change: bump `Handshake.PROTOCOL`.

## Recipes
`add-weapon` (in `.claude/skills/`).

## Tests
`tests/weapons/` (`test_bullet.gd`, `test_shot.gd`, `test_weapon_set.gd`, `test_tier1_latency.gd`),
`tests/shared/components/test_weapon_component.gd`, and smoke scenarios A, E and H.
