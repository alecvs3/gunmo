class_name WaveSheet
extends RefCounted
## A wave's enemies as the sum of their EnemyStats: what the difficulty axes read. Adding an
## enemy is cheap, so a wave can be built one enemy at a time.

var totals: Dictionary[StringName, float] = {}
var enemies: int = 0


func add(stats: EnemyStats, times: int = 1) -> void:
	for key in stats.values:
		totals[key] = total(key) + stats.values[key] * times
	enemies += times


func total(key: StringName) -> float:
	return totals.get(key, 0.0)
