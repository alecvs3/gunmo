class_name SustainAxis
extends DifficultyAxis
## Health the wave gets back or adds per second: support pulses (on `allies_per_pulse`
## average bodies), regeneration, and summons.

## How many enemies one support pulse is expected to reach.
@export_range(0.0, 20.0) var allies_per_pulse: float = 3.0


func raw(sheet: WaveSheet, modifier: WaveModifier) -> float:
	var bodies: float = sheet.total(EnemyStats.BODIES)
	var average: float = sheet.total(EnemyStats.BODY_HEALTH) / bodies if bodies > 0.0 else 0.0
	var pulses: float = sheet.total(EnemyStats.HEAL_SHARE) * allies_per_pulse * average
	var regen: float = sheet.total(EnemyStats.HEALABLE) * modifier.regen_per_second
	var summons: float = sheet.total(EnemyStats.SUMMONED_HEALTH)
	return (pulses + regen + summons) * toughness(modifier)
