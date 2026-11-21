class_name UpgradeData
extends Resource
## One shop upgrade: which stat it improves, by how much per level, how many levels, and what
## each level costs. Real values live in upgrades/data/*.tres (listed in the ShopCatalog).
## An upgrade with effects is a perk: every level adds those HitEffects to your bullets, and
## a player can only own ShopCatalog.max_perks different perks (that choice is the build).

enum Stat { DAMAGE, FIRE_RATE, MAGAZINE, RELOAD_SPEED, MOVE_SPEED, MAX_HEALTH, KNOCKBACK }

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stat: Stat = Stat.DAMAGE
## Added to the stat's multiplier per level (0.1 = +10% per level). Levels add up: level 3 of a
## +10% upgrade is +30%, applied once to the base value.
@export_range(0.0, 5.0) var per_level: float = 0.0
@export_range(1, 255) var max_level: int = 1
## Price of the first level; each further level costs cost_growth times more.
@export_range(0, 100000) var base_cost: int = 0
@export_range(1.0, 10.0) var cost_growth: float = 1.0
## Perks only: added to every bullet once per level.
@export var effects: HitEffects


## Price of the next level when the player already has `current_level`.
func cost(current_level: int) -> int:
	return roundi(base_cost * pow(cost_growth, current_level))


func is_perk() -> bool:
	return effects != null and not effects.is_empty()
