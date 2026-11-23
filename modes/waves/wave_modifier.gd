class_name WaveModifier
extends Resource
## A rule a wave can add to all its enemies ("armored", "fast", "regenerating"...). Real
## values live in modes/waves/data/modifiers/*.tres, listed in the ModifierCatalog. Several can
## be active at once; their multipliers multiply and their regeneration adds up.

@export var display_name: String = ""
## Enemies are tinted toward this color so players can read the wave at a glance.
@export var color: Color = Color.WHITE
@export_range(0.1, 10.0) var health_multiplier: float = 1.0
@export_range(0.1, 10.0) var speed_multiplier: float = 1.0
## Damage enemies take is multiplied by this (0.6 = they take 40% less).
@export_range(0.05, 10.0) var damage_taken_multiplier: float = 1.0
## Share of max health healed per second (0.05 = 5%).
@export_range(0.0, 1.0) var regen_per_second: float = 0.0


## An enemy's max health under this modifier (whole points, at least 1).
func scaled_health(base_health: int) -> int:
	return maxi(roundi(base_health * health_multiplier), 1)
