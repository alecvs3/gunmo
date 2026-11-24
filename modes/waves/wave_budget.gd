class_name WaveBudget
extends RefCounted
## How many points a wave may spend, and which enemies it buys with them.
## Pure functions with a caller-supplied random generator, so a seed gives the same wave.

## Leftover smaller than this is treated as spent (float rounding).
const EPSILON: float = 0.0001
const ROLE_COUNT: int = 4
## Roles buy in this order; frontline last, so it soaks up what the others could not spend.
const BUY_ORDER: Array[int] = [
	EnemyData.Role.SUPPORT, EnemyData.Role.RANGED, EnemyData.Role.SWARM, EnemyData.Role.FRONTLINE
]


## The seed for a wave's enemies: the match seed and the wave number, so a match replays exactly.
static func wave_seed(match_seed: int, wave: int) -> int:
	return hash([match_seed, wave])


static func budget(schedule: WaveSchedule, wave: int) -> float:
	var steps: float = maxf(wave - 1, 0)
	return schedule.base_budget + schedule.budget_growth * pow(steps, schedule.budget_curve)


## Enemy types allowed in this wave (first_wave reached, a real cost).
static func available(schedule: WaveSchedule, wave: int) -> Array[EnemyData]:
	var types: Array[EnemyData] = []
	for type in schedule.enemy_types:
		if type != null and type.first_wave <= wave and type.cost > 0.0:
			types.append(type)
	return types


## Buys the wave's enemies. The budget, divided by `threat` (how much tougher the wave's
## modifiers make each enemy, ModifierCatalog.threat, so a tougher wave buys fewer), is split
## between the roles by the schedule's shares (never below the cheapest type's cost, so a wave
## always buys at least one enemy). Each role buys random affordable types of its
## role (weighted by spawn_weight); what a role cannot spend passes to the next (frontline
## last), and anything left buys from every type. A group type is bought as a group (as many
## of it as the points still allow). The picks are shuffled, groups kept together, so the roles
## arrive mixed.
static func plan(
	schedule: WaveSchedule, wave: int, rng: RandomNumberGenerator, threat: float = 1.0
) -> Array[EnemyData]:
	var types: Array[EnemyData] = available(schedule, wave)
	var shares: PackedFloat32Array = role_shares(schedule, wave, types)
	var total: float = budget(schedule, wave) / maxf(threat, 0.01)
	if not types.is_empty():
		var cheapest: float = INF
		for type in types:
			cheapest = minf(cheapest, type.cost)
		total = maxf(total, minf(cheapest, budget(schedule, wave)))
	var picks: Array[Array] = []
	var carry: float = 0.0
	for role in BUY_ORDER:
		carry = _buy(picks, of_role(types, role), total * shares[role] + carry, rng)
	_buy(picks, types, carry, rng)
	return _shuffled(picks, rng)


## Each role's share of this wave's budget, counting only roles with a type available
## (they add up to 1, or are all 0 when no type is available).
static func role_shares(
	schedule: WaveSchedule, wave: int, types: Array[EnemyData]
) -> PackedFloat32Array:
	var shares := PackedFloat32Array()
	shares.resize(ROLE_COUNT)
	var sum: float = 0.0
	for role in ROLE_COUNT:
		if not of_role(types, role).is_empty():
			shares[role] = maxf(schedule.share(role, wave), 0.0)
			sum += shares[role]
	if sum > 0.0:
		for role in ROLE_COUNT:
			shares[role] /= sum
	elif not types.is_empty():
		shares[types[0].role] = 1.0
	return shares


static func of_role(types: Array[EnemyData], role: int) -> Array[EnemyData]:
	return types.filter(func(type: EnemyData) -> bool: return type.role == role)


## Buys from `types` until nothing fits in `left`; returns what is left.
static func _buy(
	picks: Array[Array], types: Array[EnemyData], left: float, rng: RandomNumberGenerator
) -> float:
	while true:
		var affordable: Array[EnemyData] = []
		for type in types:
			if type.cost <= left + EPSILON and type.spawn_weight > 0.0:
				affordable.append(type)
		if affordable.is_empty():
			return left
		var pick: EnemyData = _weighted_pick(affordable, rng)
		var group: Array[EnemyData] = []
		for member in pick.group_size:
			if member > 0 and pick.cost > left + EPSILON:
				break
			group.append(pick)
			left -= pick.cost
		picks.append(group)
	return left


static func _shuffled(picks: Array[Array], rng: RandomNumberGenerator) -> Array[EnemyData]:
	for i in range(picks.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Array = picks[i]
		picks[i] = picks[j]
		picks[j] = held
	var flat: Array[EnemyData] = []
	for group in picks:
		flat.append_array(group)
	return flat


static func _weighted_pick(types: Array[EnemyData], rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for type in types:
		total += type.spawn_weight
	var roll: float = rng.randf() * total
	for type in types:
		roll -= type.spawn_weight
		if roll <= 0.0:
			return type
	return types.back()
