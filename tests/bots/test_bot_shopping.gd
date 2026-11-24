extends GutTest

var catalog: ShopCatalog


func _weapon(price: int) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.price = price
	return weapon


func _upgrade(base_cost: int) -> UpgradeData:
	var upgrade := UpgradeData.new()
	upgrade.base_cost = base_cost
	upgrade.max_level = 3
	return upgrade


func before_each() -> void:
	catalog = ShopCatalog.new()
	catalog.weapons.assign([_weapon(0), _weapon(300), _weapon(600)])
	catalog.upgrades.assign([_upgrade(200), _upgrade(100)])


func _levels(a: int, b: int) -> PackedByteArray:
	return PackedByteArray([a, b])


func test_buys_the_dearest_better_gun_it_can_afford() -> void:
	assert_eq(BotShopping.choose(catalog, 0, _levels(0, 0), 700), [ShopRules.KIND_WEAPON, 2])
	assert_eq(BotShopping.choose(catalog, 0, _levels(0, 0), 400), [ShopRules.KIND_WEAPON, 1])


func test_never_buys_a_cheaper_gun() -> void:
	var choice: Array[int] = BotShopping.choose(catalog, 2, _levels(0, 0), 350)
	assert_eq(choice[0], ShopRules.KIND_UPGRADE, "upgrades instead of downgrading")


func test_otherwise_the_cheapest_upgrade_it_can_afford() -> void:
	var cheapest: int = catalog.upgrades[1].cost(0)
	assert_eq(BotShopping.choose(catalog, 2, _levels(0, 0), cheapest), [ShopRules.KIND_UPGRADE, 1])
	assert_eq(BotShopping.choose(catalog, 2, _levels(0, 3), 5000)[1], 0, "maxed: the other")
	assert_eq(BotShopping.choose(catalog, 2, _levels(0, 0), 10), [] as Array[int], "too poor")


func test_every_choice_is_allowed_by_the_shop_rules() -> void:
	var real: ShopCatalog = ShopCatalog.load_default()
	var levels := PackedByteArray()
	levels.resize(ShopCatalog.MAX_UPGRADES)
	var weapon: int = 0
	for credits in [0, 150, 400, 900, 3000]:
		var choice: Array[int] = BotShopping.choose(real, weapon, levels, credits)
		if choice.is_empty():
			continue
		if choice[0] == ShopRules.KIND_WEAPON:
			assert_eq(ShopRules.check_weapon(true, real, choice[1], weapon, credits), "")
		else:
			var level: int = levels[choice[1]]
			assert_eq(ShopRules.check_upgrade(true, real, choice[1], level, credits), "")
