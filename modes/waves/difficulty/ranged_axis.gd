class_name RangedAxis
extends DifficultyAxis
## Projectile damage per second that can reach a player, summed over the wave.


func raw(sheet: WaveSheet, _modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.RANGED_DPS)


## Summed projectile damage per second the team's health survives for a whole clear.
func handled(team: TeamPower, model: ProgressionModel) -> float:
	return team.ranged_health / (model.clear_seconds * model.ranged_hit_share)
