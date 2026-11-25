class_name PressureAxis
extends DifficultyAxis
## Bodies closing in: each body's speed (times its size) over `reference_speed`, summed, so
## many fast enemies press hardest.

## A body moving this fast (px/s) counts as 1.
@export_range(1.0, 2000.0) var reference_speed: float = 140.0


func raw(sheet: WaveSheet, modifier: WaveModifier) -> float:
	return sheet.total(EnemyStats.MOVE) * modifier.speed_multiplier / reference_speed
