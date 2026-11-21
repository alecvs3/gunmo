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
	weapon.knockback = 100.0
	weapon.damage_per_level = 3
	weapon.fire_rate_per_level = 0.5
	weapon.magazine_per_level = 2
	weapon.reload_per_level = 0.3
	weapon.knockback_per_level = 10.0
	return weapon


func test_no_levels_no_change() -> void:
	var base: WeaponData = _weapon()
	var weapon: WeaponData = PlayerStats.effective_weapon(base, catalog, levels)
	assert_eq([weapon.damage, weapon.fire_rate, weapon.magazine_size], [20, 4.0, 12])
	assert_ne(weapon, base, "a copy; the shared resource is never changed")


func test_levels_on_the_same_stat_add_up() -> void:
	levels[0] = 3
	levels[1] = 2
	assert_eq(PlayerStats.levels_on(catalog, levels, UpgradeData.Stat.DAMAGE), 5)
	assert_eq(PlayerStats.effective_weapon(_weapon(), catalog, levels).damage, 35, "20 + 5 x 3")


func test_each_gun_stat_adds_the_guns_own_amount() -> void:
	levels[2] = 1
	levels[5] = 2
	levels[6] = 1
	var weapon: WeaponData = PlayerStats.effective_weapon(_weapon(), catalog, levels)
	assert_almost_eq(weapon.fire_rate, 4.5, 1e-6)
	assert_eq(weapon.magazine_size, 16)
	assert_almost_eq(weapon.reload_time, 0.9, 1e-6)


func test_every_magazine_level_adds_ammo() -> void:
	var rocket: WeaponData = _weapon()
	rocket.magazine_size = 3
	rocket.magazine_per_level = 1
	var sizes: Array[int] = []
	for level in 6:
		levels[5] = level
		sizes.append(PlayerStats.effective_weapon(rocket, catalog, levels).magazine_size)
	assert_eq(sizes, [3, 4, 5, 6, 7, 8] as Array[int])


func test_reload_never_drops_below_the_minimum() -> void:
	levels[6] = 5
	var weapon: WeaponData = PlayerStats.effective_weapon(_weapon(), catalog, levels)
	assert_eq(weapon.reload_time, PlayerStats.MIN_RELOAD_TIME, "1.2 - 5 x 0.3 would be negative")


func test_damage_levels_also_grow_the_blast() -> void:
	var rocket: WeaponData = _weapon()
	rocket.blast_damage = 40
	rocket.blast_damage_per_level = 6
	levels[0] = 2
	assert_eq(PlayerStats.effective_weapon(rocket, catalog, levels).blast_damage, 52)


func test_levels_carry_over_and_give_the_new_guns_amounts() -> void:
	levels[5] = 2
	var smg: WeaponData = _weapon()
	smg.magazine_size = 30
	smg.magazine_per_level = 6
	assert_eq(PlayerStats.effective_weapon(_weapon(), catalog, levels).magazine_size, 16)
	assert_eq(PlayerStats.effective_weapon(smg, catalog, levels).magazine_size, 42)


func test_every_shop_gun_gains_on_every_gun_upgrade() -> void:
	for weapon in ShopCatalog.load_default().weapons:
		var label: String = weapon.display_name
		assert_gt(weapon.damage_per_level, 0, label + " damage")
		assert_gt(weapon.fire_rate_per_level, 0.0, label + " fire rate")
		assert_gt(weapon.magazine_per_level, 0, label + " magazine")
		assert_gt(weapon.reload_per_level, 0.0, label + " reload")
		assert_gt(weapon.knockback_per_level, 0.0, label + " knockback")
		if weapon.explodes():
			assert_gt(weapon.blast_damage_per_level, 0, label + " blast")
		var five_levels: float = weapon.reload_time - weapon.reload_per_level * 5
		assert_gt(five_levels, PlayerStats.MIN_RELOAD_TIME, label + " reload stays above the floor")


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
		if not UpgradeData.is_weapon_stat(upgrade.stat):
			assert_gt(upgrade.per_level, 0.0, upgrade.display_name)
		assert_gt(upgrade.base_cost, 0)


func test_loadout_levels_cap_and_heal() -> void:
	var weapon := WeaponComponent.new()
	weapon.weapon_data = _weapon()
	var health := HealthComponent.new()
	var look := PlayerLook.new()
	var loadout := PlayerLoadout.new()
	loadout.weapon = weapon
	loadout.health = health
	loadout.look = look
	loadout.catalog = catalog
	for node: Node in [weapon, health, look, loadout]:
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
