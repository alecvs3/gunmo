class_name BotShopping
extends RefCounted
## What a bot buys between waves, by simple rules (pure, tested): the dearest gun it can afford
## that costs more than the one it holds; otherwise the cheapest next upgrade level it can
## afford. Every choice is a purchase ShopRules allows. The host sends it through the same
## purchase path as a human's.


## [kind, index] to buy (ShopRules.KIND_*), or [] for nothing.
static func choose(
	catalog: ShopCatalog, weapon_index: int, levels: PackedByteArray, credits: int
) -> Array[int]:
	var weapon: int = _best_weapon(catalog, weapon_index, credits)
	if weapon >= 0:
		return [ShopRules.KIND_WEAPON, weapon]
	var upgrade: int = _cheapest_upgrade(catalog, levels, credits)
	if upgrade >= 0:
		return [ShopRules.KIND_UPGRADE, upgrade]
	return []


static func _best_weapon(catalog: ShopCatalog, current: int, credits: int) -> int:
	var held_price: int = catalog.weapons[current].price if catalog.is_weapon_index(current) else 0
	var best: int = -1
	var best_price: int = held_price
	for index in catalog.weapons.size():
		if not ShopRules.check_weapon(true, catalog, index, current, credits).is_empty():
			continue
		var price: int = catalog.weapons[index].price
		if price > best_price:
			best = index
			best_price = price
	return best


static func _cheapest_upgrade(catalog: ShopCatalog, levels: PackedByteArray, credits: int) -> int:
	var best: int = -1
	var best_price: int = 0
	for index in catalog.upgrades.size():
		var level: int = levels[index] if index < levels.size() else 0
		if not ShopRules.check_upgrade(true, catalog, index, level, credits).is_empty():
			continue
		var price: int = ShopRules.price(catalog, ShopRules.KIND_UPGRADE, index, level)
		if best < 0 or price < best_price:
			best = index
			best_price = price
	return best
