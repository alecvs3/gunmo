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
	var gun := WeaponData.new()
	gun.damage_per_level = 4
	assert_eq(ShopPanel.upgrade_label(catalog.upgrades[0], 1, gun), "Damage 1/2 · +4 dmg · 200")
	assert_eq(ShopPanel.upgrade_label(catalog.upgrades[0], 2, gun), "Damage 2/2 (max)")


func test_gain_text_follows_the_held_gun() -> void:
	var rocket := WeaponData.new()
	rocket.damage_per_level = 10
	rocket.blast_damage_per_level = 6
	rocket.magazine_per_level = 1
	rocket.reload_per_level = 0.22
	var upgrade := UpgradeData.new()
	upgrade.stat = UpgradeData.Stat.DAMAGE
	assert_eq(ShopPanel.gain_text(upgrade, rocket), "+10 dmg, +6 blast")
	upgrade.stat = UpgradeData.Stat.MAGAZINE
	assert_eq(ShopPanel.gain_text(upgrade, rocket), "+1 ammo")
	upgrade.stat = UpgradeData.Stat.RELOAD_SPEED
	assert_eq(ShopPanel.gain_text(upgrade, rocket), "-0.22 s")
	upgrade.stat = UpgradeData.Stat.MAX_HEALTH
	upgrade.per_level = 0.15
	assert_eq(ShopPanel.gain_text(upgrade, rocket), "+15%", "player stats stay a percentage")
