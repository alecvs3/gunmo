class_name WaveBudget
extends RefCounted
## How many points a wave may spend, and which enemies it buys with them.
## Pure functions with a caller-supplied random generator, so a seed gives the same wave.

## Leftover smaller than this is treated as spent (float rounding).
const EPSILON: float = 0.0001


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


## Buys random affordable enemies (weighted by spawn_weight) until nothing more fits. A type
## with group_size > 1 is bought as a group (as many of the group as the points still allow),
## listed one after another so the spawner releases them together.
static func plan(schedule: WaveSchedule, wave: int, rng: RandomNumberGenerator) -> Array[EnemyData]:
	var bought: Array[EnemyData] = []
	var left: float = budget(schedule, wave)
	var types: Array[EnemyData] = available(schedule, wave)
	while true:
		var affordable: Array[EnemyData] = []
		for type in types:
			if type.cost <= left + EPSILON and type.spawn_weight > 0.0:
				affordable.append(type)
		if affordable.is_empty():
			break
		var pick: EnemyData = _weighted_pick(affordable, rng)
		for member in pick.group_size:
			if member > 0 and pick.cost > left + EPSILON:
				break
			bought.append(pick)
			left -= pick.cost
	return bought


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
