class_name RangedAxis
extends DifficultyAxis
## Projectile damage per second that can reach a player, summed over the wave.


func raw(sheet: WaveSheet, _modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.RANGED_DPS)
