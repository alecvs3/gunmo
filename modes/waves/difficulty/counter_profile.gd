class_name CounterProfile
extends RefCounted
## Pure: which damage type works best against a planned wave. For each DamageType, the
## multiplier its hits get against the wave's enemies (their own traits and damage_taken, times
## the merged modifier's), weighted by each enemy's health, splits included. The difficulty
## score never reads it (it stays Kinetic-based and player-independent); the forecast does
## ("Bring: Pierce").

## Indexed by DamageType.Type: 1.0 = as good as against a plain enemy.
var multipliers := PackedFloat64Array()


## The profile of `planned` (WaveComposer.plan) under `modifier` (ModifierCatalog.combined).
## An empty wave scores 1.0 everywhere.
static func of(planned: Array[EnemyData], modifier: WaveModifier) -> CounterProfile:
	var sums := PackedFloat64Array()
	sums.resize(DamageType.COUNT)
	var total_health: float = 0.0
	for type in planned:
		for each in WaveReport.with_splits(type):
			var health: float = modifier.scaled_health(each.max_health)
			total_health += health
			for damage_type in DamageType.COUNT:
				sums[damage_type] += health * each.taken(damage_type) * modifier.taken(damage_type)
	var profile := CounterProfile.new()
	for damage_type in DamageType.COUNT:
		profile.multipliers.append(sums[damage_type] / total_health if total_health > 0.0 else 1.0)
	return profile


## What hits of `damage_type` (a DamageType.Type) are multiplied by against this wave, on average.
func multiplier(damage_type: int) -> float:
	return multipliers[damage_type]


## The type with the highest multiplier. Kinetic unless another beats it by more than
## `min_edge` (0.1 = a multiplier 0.1 above Kinetic's), so a wave with a few Swarmers doesn't ask
## for Blast. Ties go to the earlier type.
func best_type(min_edge: float = 0.0) -> int:
	var best: int = DamageType.Type.KINETIC
	for damage_type in DamageType.COUNT:
		if multiplier(damage_type) > multiplier(best):
			best = damage_type
	if multiplier(best) - multiplier(DamageType.Type.KINETIC) <= min_edge:
		return DamageType.Type.KINETIC
	return best
