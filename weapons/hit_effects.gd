class_name HitEffects
extends Resource
## What a bullet does to what it hits, on top of plain damage. A weapon can have some built in
## (WeaponData.effects) and perks add more (UpgradeData.effects, once per level). The host
## applies them (ImpactEffects); everyone else only sees the result.
##   Burn   damage over time; burning enemies don't regenerate
##   Chill  slows (each enemy has a cap, EnemyData.max_slow)
##   Shock  arcs from the target to nearby foes, one after another
##   Shred  the target takes more damage from every source for a while
##   Blast  damages every foe around the impact (also where the bullet stops)

## One bit per effect (Shot.effect_mask, the enemy snapshot's status flags).
const BURN: int = 1
const CHILL: int = 2
const SHOCK: int = 4
const SHRED: int = 8
const BLAST: int = 16

@export_group("Burn")
## Damage per second while burning. A target burns with the strongest burn it got.
@export_range(0.0, 1000.0) var burn_dps: float = 0.0
@export_range(0.0, 20.0) var burn_seconds: float = 0.0

@export_group("Chill")
## Share of speed taken away (0.25 = 25% slower).
@export_range(0.0, 1.0) var chill_slow: float = 0.0
@export_range(0.0, 20.0) var chill_seconds: float = 0.0

@export_group("Shock")
## How many foes the arc jumps to, one after another.
@export_range(0, 16) var shock_chains: int = 0
## Damage of each jump, as a share of the bullet's damage.
@export_range(0.0, 2.0) var shock_share: float = 0.0
## Longest jump (px).
@export_range(0.0, 1000.0) var shock_range: float = 0.0

@export_group("Shred")
## Extra damage the target takes from everything (0.2 = +20%).
@export_range(0.0, 5.0) var shred_bonus: float = 0.0
@export_range(0.0, 20.0) var shred_seconds: float = 0.0

@export_group("Blast")
## Damage to every other foe in the radius, as a share of the bullet's damage.
@export_range(0.0, 2.0) var blast_share: float = 0.0
@export_range(0.0, 1000.0) var blast_radius: float = 0.0


## Bullet color for a mix of effects (plain yellow without any).
static func tint(mask: int) -> Color:
	var colors: Dictionary = {
		BURN: Color(1.0, 0.45, 0.1),
		CHILL: Color(0.45, 0.85, 1.0),
		SHOCK: Color(0.75, 0.5, 1.0),
		SHRED: Color(1.0, 0.25, 0.35),
		BLAST: Color(1.0, 0.95, 0.75),
	}
	var total := Color(0, 0, 0, 0)
	var count: int = 0
	for bit: int in colors:
		if mask & bit:
			total += colors[bit]
			count += 1
	return Color(1.0, 0.85, 0.3) if count == 0 else total / float(count)


## Which effects actually do something.
func mask() -> int:
	var bits: int = 0
	bits |= BURN if burn_dps > 0.0 and burn_seconds > 0.0 else 0
	bits |= CHILL if chill_slow > 0.0 and chill_seconds > 0.0 else 0
	bits |= SHOCK if shock_chains > 0 and shock_share > 0.0 and shock_range > 0.0 else 0
	bits |= SHRED if shred_bonus > 0.0 and shred_seconds > 0.0 else 0
	bits |= BLAST if blast_share > 0.0 and blast_radius > 0.0 else 0
	return bits


func is_empty() -> bool:
	return mask() == 0


## A new HitEffects: these plus `other` `times` over (a perk at level 2 counts twice).
## Amounts add up; durations, ranges and radii take the larger value.
func plus(other: HitEffects, times: int = 1) -> HitEffects:
	var sum: HitEffects = duplicate()
	if other == null or times <= 0:
		return sum
	sum.burn_dps += other.burn_dps * times
	sum.burn_seconds = maxf(burn_seconds, other.burn_seconds)
	sum.chill_slow += other.chill_slow * times
	sum.chill_seconds = maxf(chill_seconds, other.chill_seconds)
	sum.shock_chains += other.shock_chains * times
	sum.shock_share = maxf(shock_share, other.shock_share)
	sum.shock_range = maxf(shock_range, other.shock_range)
	sum.shred_bonus += other.shred_bonus * times
	sum.shred_seconds = maxf(shred_seconds, other.shred_seconds)
	sum.blast_share += other.blast_share * times
	sum.blast_radius = maxf(blast_radius, other.blast_radius)
	return sum


## What an arc or a blast passes on to the foes it reaches: the timed effects only, so a
## secondary hit never sets off more arcs or blasts.
func carried() -> HitEffects:
	var copy: HitEffects = duplicate()
	copy.shock_chains = 0
	copy.blast_share = 0.0
	return copy
