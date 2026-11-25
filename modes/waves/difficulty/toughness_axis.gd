class_name ToughnessAxis
extends DifficultyAxis
## Effective health of the whole wave (armor and splits included).


func raw(sheet: WaveSheet, modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.HEALTH) * toughness(modifier)
