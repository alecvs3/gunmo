class_name ShopCatalog
extends Resource
## Everything the shop sells, in a fixed order. Players refer to items by index (indices travel
## in snapshots and purchase requests), so every peer must use the same catalog: the default
## one at DEFAULT_PATH. The build fingerprint check guarantees all peers have the same file.

const DEFAULT_PATH: String = "res://upgrades/data/shop_catalog.tres"
## Upgrade levels travel as a fixed-size list; the catalog may not hold more upgrades.
const MAX_UPGRADES: int = 16

## Weapon 0 is what every player starts with.
@export var weapons: Array[WeaponData] = []
## At most MAX_UPGRADES.
@export var upgrades: Array[UpgradeData] = []
## How many different perks one player may own.
@export_range(0, 16) var max_perks: int = 2


static func load_default() -> ShopCatalog:
	return load(DEFAULT_PATH)


func weapon(index: int) -> WeaponData:
	return weapons[clampi(index, 0, weapons.size() - 1)]


func is_upgrade_index(index: int) -> bool:
	return index >= 0 and index < mini(upgrades.size(), MAX_UPGRADES)


func is_weapon_index(index: int) -> bool:
	return index >= 0 and index < weapons.size()
