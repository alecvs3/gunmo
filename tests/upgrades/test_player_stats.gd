extends GutTest

var catalog: ShopCatalog
var levels := PackedByteArray()


func _upgrade(stat: UpgradeData.Stat, per_level: float, max_level: int) -> UpgradeData:
	var upgrade := UpgradeData.new()
	upgrade.stat = stat
	upgrade.per_level = per_level
	upgrade.max_level = max_level
	upgrade.base_cost = 100
	upgrade.cost_growth = 1.5
	return upgrade


func before_each() -> void:
	catalog = ShopCatalog.new()
	var stat := UpgradeData.Stat
	(
		catalog
		. upgrades
		. assign(
			[
				_upgrade(stat.DAMAGE, 0.1, 5),
				_upgrade(stat.DAMAGE, 0.05, 5),
				_upgrade(stat.FIRE_RATE, 0.2, 5),
				_upgrade(stat.MOVE_SPEED, 0.1, 4),
				_upgrade(stat.MAX_HEALTH, 0.5, 3),
				_upgrade(stat.MAGAZINE, 0.25, 5),
				_upgrade(stat.RELOAD_SPEED, 1.0, 5),
			]
		)
	)
	catalog.weapons.assign([_weapon()])
	levels.resize(ShopCatalog.MAX_UPGRADES)
	levels.fill(0)


func _weapon() -> WeaponData:
	var weapon := WeaponData.new()
	weapon.damage = 20
	weapon.fire_rate = 4.0
	weapon.magazine_size = 12
	weapon.reload_time = 1.2
	return weapon


func test_no_levels_no_change() -> void:
	var base: WeaponData = _weapon()
	var weapon: WeaponData = PlayerStats.effective_weapon(base, catalog, levels)
	assert_eq([weapon.damage, weapon.fire_rate, weapon.magazine_size], [20, 4.0, 12])
	assert_ne(weapon, base, "a copy; the shared resource is never changed")


func test_levels_on_the_same_stat_add_up() -> void:
	levels[0] = 3
	levels[1] = 2
	assert_almost_eq(PlayerStats.multiplier(catalog, levels, UpgradeData.Stat.DAMAGE), 1.4, 1e-6)
	assert_eq(PlayerStats.effective_weapon(_weapon(), catalog, levels).damage, 28)


func test_each_stat_applies_to_its_number() -> void:
	levels[2] = 1
	levels[5] = 2
	levels[6] = 1
	var weapon: WeaponData = PlayerStats.effective_weapon(_weapon(), catalog, levels)
	assert_almost_eq(weapon.fire_rate, 4.8, 1e-6)
	assert_eq(weapon.magazine_size, 18)
	assert_almost_eq(weapon.reload_time, 0.6, 1e-6, "reload speed x2 halves the time")


func test_player_stats() -> void:
	var base := PlayerData.new()
	base.move_speed = 200.0
	base.max_health = 100
	levels[3] = 2
	levels[4] = 1
	var player: PlayerData = PlayerStats.effective_player(base, catalog, levels)
	assert_almost_eq(player.move_speed, 240.0, 1e-6)
	assert_eq(player.max_health, 150)
	assert_eq(base.max_health, 100, "base untouched")


func test_cost_grows_each_level() -> void:
	var upgrade: UpgradeData = catalog.upgrades[0]
	assert_eq(upgrade.cost(0), 100)
	assert_eq(upgrade.cost(1), 150)
	assert_eq(upgrade.cost(2), 225)


func test_default_catalog_fits_the_snapshot() -> void:
	var real: ShopCatalog = ShopCatalog.load_default()
	assert_between(real.upgrades.size(), 1, ShopCatalog.MAX_UPGRADES)
	for upgrade in real.upgrades:
		assert_false(upgrade.display_name.is_empty())
		assert_gt(upgrade.per_level, 0.0)
		assert_gt(upgrade.base_cost, 0)


func test_loadout_levels_cap_and_heal() -> void:
	var weapon := WeaponComponent.new()
	weapon.weapon_data = _weapon()
	var health := HealthComponent.new()
	var barrel := Polygon2D.new()
	var loadout := PlayerLoadout.new()
	loadout.weapon = weapon
	loadout.health = health
	loadout.barrel = barrel
	loadout.catalog = catalog
	for node: Node in [weapon, health, barrel, loadout]:
		add_child_autofree(node)
	var base := PlayerData.new()
	base.max_health = 100
	base.move_speed = 200.0
	loadout.configure(base)
	health.reset()
	health.take_damage(30)
	assert_true(loadout.add_level(4))
	assert_eq(health.max_health, 150)
	assert_eq(health.current_health, 120, "gaining 50 max health also heals 50")
	assert_true(loadout.add_level(4))
	assert_true(loadout.add_level(4))
	assert_false(loadout.add_level(4), "max level 3")
	loadout.reset()
	assert_eq(loadout.level(4), 0)
	assert_eq(health.max_health, 100)
