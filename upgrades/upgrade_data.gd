class_name UpgradeData
extends Resource
## One shop upgrade: which stat it improves, how many levels, and what each level costs. Real
## values live in upgrades/data/*.tres (listed in the ShopCatalog).
## Gun stats (damage, fire rate, magazine, reload speed, knockback): what a level adds is set by
## each gun (WeaponData "Per upgrade level"), so it fits that gun. Player stats (move speed,
## max health) use per_level here, the same for everyone.

enum Stat { DAMAGE, FIRE_RATE, MAGAZINE, RELOAD_SPEED, MOVE_SPEED, MAX_HEALTH, KNOCKBACK }

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stat: Stat = Stat.DAMAGE
## Player stats only: added to the stat's multiplier per level (0.1 = +10% per level). Levels
## add up: level 3 of a +10% upgrade is +30%, applied once to the base value.
@export_range(0.0, 5.0) var per_level: float = 0.0
@export_range(1, 255) var max_level: int = 1
## Price of the first level; each further level costs cost_growth times more.
@export_range(0, 100000) var base_cost: int = 0
@export_range(1.0, 10.0) var cost_growth: float = 1.0


## Whether `stat` is a gun stat (its per-level amount comes from the gun).
static func is_weapon_stat(stat: Stat) -> bool:
	return stat not in [Stat.MOVE_SPEED, Stat.MAX_HEALTH]


## Price of the next level when the player already has `current_level`.
func cost(current_level: int) -> int:
	return roundi(base_cost * pow(cost_growth, current_level))
