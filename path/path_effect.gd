class_name PathEffect
extends Resource
## What owning a Path node does. Each kind of effect is a small subclass that overrides the
## hooks it changes; the base changes nothing. PathTree adds up the hooks over the nodes a
## player owns, so a new node is mostly data.


## Added to `stat`'s multiplier (0.1 = +10%). See StatEffect.
func stat_bonus(_stat: UpgradeData.Stat) -> float:
	return 0.0


## Shop upgrade prices are multiplied by this (0.9 = 10% cheaper).
func shop_price_multiplier() -> float:
	return 1.0


## Extra Cores for this player when a boss dies.
func extra_boss_cores() -> int:
	return 0
