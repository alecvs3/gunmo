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
3. The host's bullet sweeps along its path each tick (`bullet.gd`); the first sweep starts at
   `Shot.hit_origin` (a player's body; the muzzle for enemies). Human shots are tested
   with lag compensation (what the shooter saw). Bots' and enemies' shots (any negative
   shooter id; enemies use `Shot.enemy_shooter_id(net_id)`) are tested against remote humans
   on their own timeline (`timeline_hits.gd`, fair dodging).
   Ranged enemies fire through the same `shot_fired` (`enemies/behaviours/ranged_attack.gd`).
4. On a hit the host applies damage and knockback, then tells the shooter (`EVENT_HIT`) and
   the victim (`EVENT_HURT`). When the bullet ends, everyone is told where and when
   (`EVENT_ENDED`).

## Looks, rockets and explosions
- `WeaponData.projectile` picks the scene every peer draws (`bullet.tscn`, `rocket.tscn`,
  `pellet.tscn`, `rifle_round.tscn` or `enemy_bolt.tscn`, `PROJECTILE_SCENES` in `projectile_system.gd`, in enum
  order); the value travels with the shot, so new kinds go at the end. Bullets are bright with
  a dark outline and a fading tail so they show on any floor; the look is separate from
  `bullet_radius` (the hit size).
- `WeaponData.held_model` is a scene of Polygon2D shapes drawn over the character's hands with
  its front end at the muzzle (`models/*.tscn`: one per gun), set
  by `player/player_look.gd`. It must cover the gun painted into the character picture for
  its pose, on every character in `player/looks/`.
- `WeaponData.fire_sound` (a `SoundCue`, `shared/feedback/data/guns/`) plays once per trigger
  pull on every peer: `projectile_system.gd` emits EventBus `shot_shown` for each bullet it
  spawns, and the FeedbackSystem plays the shooter's gun for the first pellet only.
- `blast_radius` + `blast_damage`: where the shot lands (a hit, a wall or the end of its range)
  the host runs `explosion.gd` (everyone else in the radius takes the blast and is pushed
  away; never the shooter or teammates) and tells every peer (`EVENT_BLAST`), who draws
  `explosion_flash.tscn`.

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
`tests/weapons/` (bullets, shots, the weapon set, fair dodging),
`tests/shared/components/test_weapon_component.gd`, and smoke scenarios A, D, E and H.
