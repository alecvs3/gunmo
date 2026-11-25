class_name MeleeAxis
extends DifficultyAxis
## Contact damage per second, summed over the wave.


func raw(sheet: WaveSheet, _modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.MELEE_DPS)


## Summed contact damage per second the team's health survives for a whole clear.
func handled(team: TeamPower, model: ProgressionModel) -> float:
	return team.melee_health / (model.clear_seconds * model.melee_hit_share)
