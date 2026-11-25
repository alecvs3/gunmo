class_name ToughnessAxis
extends DifficultyAxis
## Effective health of the whole wave (armor and splits included).


func raw(sheet: WaveSheet, modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.HEALTH) * toughness(modifier)


## The health the team's damage per second chews through in clear_seconds.
func handled(team: TeamPower, model: ProgressionModel) -> float:
	return team.dps * model.clear_seconds
