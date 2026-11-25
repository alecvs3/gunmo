class_name MeleeAxis
extends DifficultyAxis
## Contact damage per second, summed over the wave.


func raw(sheet: WaveSheet, _modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.MELEE_DPS)
