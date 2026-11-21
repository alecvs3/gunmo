class_name ShopRules
extends RefCounted
## When a purchase is allowed. Pure, so every rule is unit-tested; the host runs these on
## every purchase request (clients only use them to grey out buttons).

const KIND_UPGRADE: int = 0
const KIND_WEAPON: int = 1


## "" if the next level may be bought, otherwise why not. `perks_owned` is how many different
## perks the buyer has (PlayerStats.perks_owned); a new perk needs a free slot.
static func check_upgrade(
	shop_open: bool,
	catalog: ShopCatalog,
	index: int,
	level: int,
	credits: int,
	perks_owned: int = 0,
) -> String:
	if not shop_open:
		return "The shop is only open between waves."
	if not catalog.is_upgrade_index(index):
		return "No such upgrade."
	var upgrade: UpgradeData = catalog.upgrades[index]
	if level >= upgrade.max_level:
		return "Already at the highest level."
	if upgrade.is_perk() and level == 0 and perks_owned >= catalog.max_perks:
		return "No free perk slot (%d of %d used)." % [perks_owned, catalog.max_perks]
	if credits < upgrade.cost(level):
		return "Not enough credits."
	return ""


## "" if the weapon may be bought, otherwise why not.
static func check_weapon(
	shop_open: bool, catalog: ShopCatalog, index: int, current_index: int, credits: int
) -> String:
	if not shop_open:
		return "The shop is only open between waves."
	if not catalog.is_weapon_index(index):
		return "No such weapon."
	if index == current_index:
		return "Already equipped."
	if credits < catalog.weapons[index].price:
		return "Not enough credits."
	return ""


## Credits the purchase costs (assumes it was allowed).
static func price(catalog: ShopCatalog, kind: int, index: int, level: int) -> int:
	if kind == KIND_UPGRADE:
		return catalog.upgrades[index].cost(level)
	return catalog.weapons[index].price
