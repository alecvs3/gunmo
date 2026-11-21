class_name ShopCatalog
extends Resource
## Everything the shop sells, in a fixed order. Players refer to items by index (indices travel
## in snapshots and purchase requests), so every peer must use the same catalog: the default
## one at DEFAULT_PATH. The build fingerprint check guarantees all peers have the same file.

const DEFAULT_PATH: String = "res://upgrades/data/shop_catalog.tres"

## Weapon 0 is what every player starts with.
@export var weapons: Array[WeaponData] = []


static func load_default() -> ShopCatalog:
	return load(DEFAULT_PATH)


func weapon(index: int) -> WeaponData:
	return weapons[clampi(index, 0, weapons.size() - 1)]


func is_weapon_index(index: int) -> bool:
	return index >= 0 and index < weapons.size()
