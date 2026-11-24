class_name WizardRules
extends RefCounted
## The Wizard's tiers as pure rules (numbers from WizardData). `tier` = tiers owned.

const ARC: int = 1
const RUNE: int = 2
const CONDUCTION: int = 3
const HEX: int = 4
const TEMPEST: int = 5


## Tier 1: the chance a hit arcs (0 = not owned), more from tier 2.
static func arc_chance(data: WizardData, tier: int) -> float:
	if tier < ARC:
		return 0.0
	return data.arc_chance_upgraded if tier >= RUNE else data.arc_chance


## How many enemies an arc jumps to; from tier 3 a slowed first enemy passes it on further.
static func arc_jumps(data: WizardData, tier: int, slowed_source: bool) -> int:
	var jumps: int = data.arc_jumps_upgraded if tier >= RUNE else data.arc_jumps
	if tier >= CONDUCTION and slowed_source:
		jumps += data.conduction_extra_jumps
	return jumps


## The damage one arc deals for a hit of `hit`; from tier 3 more to a slowed enemy.
static func arc_damage(data: WizardData, tier: int, hit: int, target_slowed: bool) -> int:
	var share: float = data.arc_damage_share
	if tier >= CONDUCTION and target_slowed:
		share *= 1.0 + data.conduction_bonus
	return maxi(roundi(hit * share), 1)


## Which of `candidates` the arc jumps to, in order: each jump to the nearest not yet hit within
## `radius` of the last one, starting from `origin`. Returns their indices.
static func chain(
	origin: Vector2, candidates: Array[Vector2], jumps: int, radius: float
) -> Array[int]:
	var picked: Array[int] = []
	var from: Vector2 = origin
	for i in jumps:
		var best: int = -1
		var best_distance: float = radius
		for j in candidates.size():
			var distance: float = from.distance_to(candidates[j])
			if not picked.has(j) and distance <= best_distance and distance > 0.5:
				best = j
				best_distance = distance
		if best < 0:
			break
		picked.append(best)
		from = candidates[best]
	return picked


## Seconds between runes (0 = none before tier 2), faster from tier 4.
static func rune_interval(data: WizardData, tier: int) -> float:
	if tier < RUNE:
		return 0.0
	return data.rune_interval_upgraded if tier >= HEX else data.rune_interval


## Seconds between hexes (0 = none before tier 4), faster from tier 5.
static func hex_interval(data: WizardData, tier: int) -> float:
	if tier < HEX:
		return 0.0
	return data.hex_interval_upgraded if tier >= TEMPEST else data.hex_interval


static func tempest_interval(data: WizardData, tier: int) -> float:
	return data.tempest_interval if tier >= TEMPEST else 0.0


## The point among `points` with the most others within `radius` (where the rune lands), or
## INF when there are none.
static func densest(points: Array[Vector2], radius: float) -> Vector2:
	var best := Vector2.INF
	var best_count: int = -1
	for at in points:
		var count: int = 0
		for other in points:
			if at.distance_to(other) <= radius:
				count += 1
		if count > best_count:
			best = at
			best_count = count
	return best


## Of the enemies' health and boss flags, the toughest to hex: a boss first, then the most health.
static func toughest(healths: Array[int], bosses: Array[bool]) -> int:
	var best: int = -1
	for i in healths.size():
		if best < 0:
			best = i
			continue
		if bosses[i] != bosses[best]:
			best = i if bosses[i] else best
		elif healths[i] > healths[best]:
			best = i
	return best


## Tempest damage to an enemy with `max_health` (a smaller share on bosses).
static func tempest_damage(data: WizardData, max_health: int, boss: bool) -> int:
	return maxi(roundi(max_health * (data.tempest_boss_share if boss else data.tempest_share)), 1)
