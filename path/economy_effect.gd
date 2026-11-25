class_name EconomyEffect
extends PathEffect
## Pays off later instead of in a fight: cheaper shop upgrades, more Cores from bosses.

## Shop upgrade prices are multiplied by this (0.9 = 10% cheaper). Several multiply together.
@export_range(0.1, 1.0) var price_multiplier: float = 1.0
## Extra Cores for this player each time a boss dies (on top of MatchSettings.cores_per_boss).
@export_range(0, 10) var boss_cores: int = 0


func shop_price_multiplier() -> float:
	return price_multiplier


func extra_boss_cores() -> int:
	return boss_cores
