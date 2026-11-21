extends GutTest
## Perks: upgrades that add HitEffects, limited by ShopCatalog.max_perks (the build choice).

var catalog: ShopCatalog
var levels := PackedByteArray()


func _perk(name: String, burn_dps: float) -> UpgradeData:
	var perk := UpgradeData.new()
	perk.display_name = name
	perk.max_level = 3
	perk.base_cost = 100
	perk.effects = HitEffects.new()
	perk.effects.burn_dps = burn_dps
	perk.effects.burn_seconds = 3.0
	return perk


func before_each() -> void:
	catalog = ShopCatalog.new()
	var damage := UpgradeData.new()
	damage.stat = UpgradeData.Stat.DAMAGE
	damage.per_level = 0.5
	damage.max_level = 3
	damage.base_cost = 100
	catalog.upgrades = [damage, _perk("A", 4.0), _perk("B", 1.0), _perk("C", 2.0)]
	catalog.max_perks = 2
	levels = PackedByteArray()
	levels.resize(ShopCatalog.MAX_UPGRADES)


func test_only_upgrades_with_effects_are_perks() -> void:
	assert_false(catalog.upgrades[0].is_perk())
	assert_true(catalog.upgrades[1].is_perk())
	var empty := UpgradeData.new()
	empty.effects = HitEffects.new()
	assert_false(empty.is_perk(), "effects that do nothing don't make a perk")


func test_perk_levels_add_to_the_weapon_effects() -> void:
	var weapon := WeaponData.new()
	weapon.damage = 10
	weapon.effects = HitEffects.new()
	weapon.effects.burn_dps = 10.0
	weapon.effects.burn_seconds = 1.0
	levels[1] = 2
	var effects: HitEffects = PlayerStats.effective_weapon(weapon, catalog, levels).effects
	assert_eq(effects.burn_dps, 18.0, "10 built in + 4 x 2 levels")
	assert_eq(effects.burn_seconds, 3.0)
	assert_eq(weapon.effects.burn_dps, 10.0, "the shared file is never changed")


func test_plain_weapon_gets_perk_effects() -> void:
	var weapon := WeaponData.new()
	weapon.damage = 10
	assert_true(PlayerStats.effective_weapon(weapon, catalog, levels).effects.is_empty())
	levels[3] = 1
	assert_eq(PlayerStats.effective_weapon(weapon, catalog, levels).effects.burn_dps, 2.0)


func test_perks_owned_counts_different_perks() -> void:
	levels[0] = 3
	assert_eq(PlayerStats.perks_owned(catalog, levels), 0, "stat upgrades are not perks")
	levels[1] = 3
	levels[2] = 1
	assert_eq(PlayerStats.perks_owned(catalog, levels), 2)


func test_new_perk_needs_a_free_slot() -> void:
	assert_eq(ShopRules.check_upgrade(true, catalog, 3, 0, 1000, 1), "")
	assert_eq(
		ShopRules.check_upgrade(true, catalog, 3, 0, 1000, 2), "No free perk slot (2 of 2 used)."
	)


func test_owned_perk_can_still_level_up_with_full_slots() -> void:
	assert_eq(ShopRules.check_upgrade(true, catalog, 1, 1, 1000, 2), "")


func test_stat_upgrades_ignore_perk_slots() -> void:
	assert_eq(ShopRules.check_upgrade(true, catalog, 0, 0, 1000, 2), "")


func test_default_catalog_has_perks_and_new_guns() -> void:
	var real: ShopCatalog = ShopCatalog.load_default()
	var perks: int = 0
	for upgrade in real.upgrades:
		perks += 1 if upgrade.is_perk() else 0
	assert_eq(perks, 5)
	assert_eq(real.max_perks, 2)
	assert_eq(real.weapons.size(), 10)
	assert_eq(real.weapons[0].display_name, "Pistol", "existing weapon indices are kept")
	assert_eq(real.weapons[2].display_name, "Shotgun")
