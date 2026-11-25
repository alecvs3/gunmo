class_name ShopRules
extends RefCounted
## When a purchase is allowed. Pure, so every rule is unit-tested; the host runs these on
## every purchase request (clients only use them to grey out buttons).

const KIND_UPGRADE: int = 0
const KIND_WEAPON: int = 1
## Buy a pet's next tier (a different pet starts again at tier 1).
const KIND_PET: int = 2


## "" if the next level may be bought, otherwise why not. `discount` multiplies upgrade prices
## (the Path's EconomyEffects; 1 = full price).
static func check_upgrade(
	shop_open: bool,
	catalog: ShopCatalog,
	index: int,
	level: int,
	credits: int,
	discount: float = 1.0
) -> String:
	if not shop_open:
		return "The shop is only open between waves."
	if not catalog.is_upgrade_index(index):
		return "No such upgrade."
	var upgrade: UpgradeData = catalog.upgrades[index]
	if level >= upgrade.max_level:
		return "Already at the highest level."
	if credits < upgrade.cost(level, discount):
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


## Credits the purchase costs (assumes it was allowed); `discount` applies to upgrades only.
static func price(
	catalog: ShopCatalog, kind: int, index: int, level: int, discount: float = 1.0
) -> int:
	if kind == KIND_UPGRADE:
		return catalog.upgrades[index].cost(level, discount)
	return catalog.weapons[index].price


## "" if the pet's next tier may be bought, otherwise why not. `current_pet` and `tier` are
## the pet you have now (-1 and 0 = none); another pet starts again at its first tier.
static func check_pet(
	shop_open: bool, pets: PetCatalog, index: int, current_pet: int, tier: int, credits: int
) -> String:
	if not shop_open:
		return "The shop is only open between waves."
	if not pets.is_pet_index(index):
		return "No such pet."
	var price: int = pet_price(pets, index, current_pet, tier)
	if price < 0:
		return "Already at the highest tier."
	if credits < price:
		return "Not enough credits."
	return ""


## Credits the pet's next tier costs (-1 = all bought).
static func pet_price(pets: PetCatalog, index: int, current_pet: int, tier: int) -> int:
	var owned: int = tier if index == current_pet else 0
	return pets.pets[index].next_price(owned)
