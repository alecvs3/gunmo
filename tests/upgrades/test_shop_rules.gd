extends GutTest

var catalog: ShopCatalog


func before_each() -> void:
	catalog = ShopCatalog.new()
	var pistol := WeaponData.new()
	var rifle := WeaponData.new()
	rifle.display_name = "Rifle"
	rifle.price = 400
	catalog.weapons.assign([pistol, rifle])
	var damage := UpgradeData.new()
	damage.display_name = "Damage"
	damage.max_level = 2
	damage.base_cost = 100
	damage.cost_growth = 2.0
	catalog.upgrades.assign([damage])


func test_upgrade_allowed() -> void:
	assert_eq(ShopRules.check_upgrade(true, catalog, 0, 0, 100), "")
	assert_eq(ShopRules.price(catalog, ShopRules.KIND_UPGRADE, 0, 1), 200)


func test_upgrade_refusals() -> void:
	assert_string_contains(ShopRules.check_upgrade(false, catalog, 0, 0, 999), "between waves")
	assert_string_contains(ShopRules.check_upgrade(true, catalog, 5, 0, 999), "No such")
	assert_string_contains(ShopRules.check_upgrade(true, catalog, 0, 2, 999), "highest")
	assert_string_contains(ShopRules.check_upgrade(true, catalog, 0, 1, 199), "credits")


func test_weapon_allowed_and_refusals() -> void:
	assert_eq(ShopRules.check_weapon(true, catalog, 1, 0, 400), "")
	assert_string_contains(ShopRules.check_weapon(true, catalog, 1, 0, 399), "credits")
	assert_string_contains(ShopRules.check_weapon(true, catalog, 1, 1, 999), "equipped")
	assert_string_contains(ShopRules.check_weapon(false, catalog, 1, 0, 999), "between waves")
	assert_string_contains(ShopRules.check_weapon(true, catalog, -1, 0, 999), "No such")
	assert_eq(ShopRules.check_weapon(true, catalog, 0, 1, 0), "", "switching back to a free gun")


func test_button_labels() -> void:
	assert_eq(ShopPanel.weapon_label(catalog.weapons[1], false), "Rifle · 400")
	assert_eq(ShopPanel.weapon_label(catalog.weapons[1], true), "Rifle (equipped)")
	catalog.weapons[0].display_name = "Pistol"
	assert_eq(ShopPanel.weapon_label(catalog.weapons[0], false), "Pistol · free")
	assert_eq(ShopPanel.upgrade_label(catalog.upgrades[0], 1), "Damage 1/2 · 200")
	assert_eq(ShopPanel.upgrade_label(catalog.upgrades[0], 2), "Damage 2/2 (max)")
