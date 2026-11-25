extends GutTest
## Path effects: StatEffect through PlayerStats, EconomyEffect on prices and boss Cores, and the
## real tree's data.

const FORTITUDE: int = 0
const QUICK_HANDS: int = 1
const QUARTERMASTER: int = 2
const SCAVENGER: int = 3
const FLEET_FOOT: int = 4

var tree: PathTree = PathTree.load_default()
var catalog: ShopCatalog = ShopCatalog.load_default()
var levels := PackedByteArray()


func before_each() -> void:
	levels.resize(ShopCatalog.MAX_UPGRADES)
	levels.fill(0)


func _stat(stat: UpgradeData.Stat, amount: float) -> StatEffect:
	var effect := StatEffect.new()
	effect.stat = stat
	effect.amount = amount
	return effect


func test_stat_effect_only_touches_its_stat() -> void:
	var effect: StatEffect = _stat(UpgradeData.Stat.MAX_HEALTH, 0.1)
	assert_almost_eq(effect.stat_bonus(UpgradeData.Stat.MAX_HEALTH), 0.1, 1e-6)
	assert_eq(effect.stat_bonus(UpgradeData.Stat.DAMAGE), 0.0)
	assert_eq(effect.shop_price_multiplier(), 1.0)
	assert_eq(effect.extra_boss_cores(), 0)


func test_player_stat_bonus_joins_the_upgrade_multiplier() -> void:
	var base := PlayerData.new()
	base.max_health = 100
	base.move_speed = 200.0
	var bonuses := PackedFloat32Array()
	bonuses.resize(UpgradeData.Stat.size())
	bonuses[UpgradeData.Stat.MAX_HEALTH] = 0.1
	bonuses[UpgradeData.Stat.MOVE_SPEED] = 0.1
	assert_eq(PlayerStats.effective_player(base, catalog, levels, bonuses).max_health, 110)
	var health: int = catalog.upgrades.find_custom(
		func(u: UpgradeData) -> bool: return u.stat == UpgradeData.Stat.MAX_HEALTH
	)
	levels[health] = 1
	var per_level: float = catalog.upgrades[health].per_level
	var both: PlayerData = PlayerStats.effective_player(base, catalog, levels, bonuses)
	assert_eq(both.max_health, roundi(100 * (1.0 + per_level + 0.1)), "added, not multiplied")
	assert_almost_eq(both.move_speed, 220.0, 1e-3)


func test_gun_stat_bonus_scales_the_upgraded_gun() -> void:
	var gun := WeaponData.new()
	gun.damage = 20
	gun.fire_rate = 4.0
	gun.magazine_size = 10
	gun.reload_time = 1.2
	gun.knockback = 100.0
	var bonuses := PackedFloat32Array()
	bonuses.resize(UpgradeData.Stat.size())
	bonuses.fill(0.5)
	var better: WeaponData = PlayerStats.effective_weapon(gun, catalog, levels, bonuses)
	assert_eq(better.damage, 30)
	assert_almost_eq(better.fire_rate, 6.0, 1e-6)
	assert_eq(better.magazine_size, 15)
	assert_almost_eq(better.reload_time, 0.8, 1e-6, "reload speed +50% = time / 1.5")
	assert_almost_eq(better.knockback, 150.0, 1e-6)
	assert_eq(gun.damage, 20, "base untouched")
	var plain: WeaponData = PlayerStats.effective_weapon(gun, catalog, levels)
	assert_eq(plain.damage, 20, "no bonuses = no change")


func test_tree_sums_only_owned_nodes() -> void:
	var none: PackedFloat32Array = tree.stat_bonuses(0)
	assert_eq(none.size(), UpgradeData.Stat.size())
	assert_eq(none[UpgradeData.Stat.MAX_HEALTH], 0.0)
	var owned: int = 1 << FORTITUDE | 1 << QUICK_HANDS
	var some: PackedFloat32Array = tree.stat_bonuses(owned)
	assert_almost_eq(some[UpgradeData.Stat.MAX_HEALTH], 0.1, 1e-6, "Fortitude")
	assert_almost_eq(some[UpgradeData.Stat.RELOAD_SPEED], 0.2, 1e-6, "Quick hands")


func test_economy_effects() -> void:
	assert_eq(tree.shop_price_multiplier(0), 1.0)
	assert_almost_eq(tree.shop_price_multiplier(1 << QUARTERMASTER), 0.9, 1e-6)
	assert_eq(tree.extra_boss_cores(1 << SCAVENGER), 1)
	var upgrade: UpgradeData = catalog.upgrades[0]
	var discount: float = tree.shop_price_multiplier(1 << QUARTERMASTER)
	assert_eq(upgrade.cost(0, discount), roundi(upgrade.base_cost * 0.9))
	assert_eq(
		ShopRules.price(catalog, ShopRules.KIND_UPGRADE, 0, 0, discount), upgrade.cost(0, 0.9)
	)
	var short: int = upgrade.cost(0, discount)
	assert_eq(ShopRules.check_upgrade(true, catalog, 0, 0, short, discount), "")
	assert_ne(ShopRules.check_upgrade(true, catalog, 0, 0, short), "", "full price without it")
	assert_eq(ShopRules.price(catalog, ShopRules.KIND_WEAPON, 1, 0, 0.5), catalog.weapons[1].price)


func test_starter_branch_data() -> void:
	assert_eq(tree.nodes.size(), 5)
	assert_lte(tree.nodes.size(), PathTree.MAX_NODES)
	assert_eq(tree.branches(), ["Logistics"] as Array[String])
	for path_node in tree.nodes:
		assert_false(path_node.display_name.is_empty())
		assert_false(path_node.effects.is_empty(), path_node.display_name)
		for needed in path_node.requires + path_node.excludes:
			assert_ne(tree.index_of(needed), -1, "%s links into the tree" % path_node.display_name)
		for needed in path_node.requires:
			assert_lt(needed.tier, path_node.tier, "requirements sit on earlier tiers")
	assert_eq(tree.nodes[FLEET_FOOT].excludes, [tree.nodes[SCAVENGER]] as Array[PathNode])


func test_a_full_route_through_the_starter_branch() -> void:
	var progress := PathProgress.new()
	progress.cores = 8
	for index in [FORTITUDE, QUICK_HANDS, FLEET_FOOT]:
		PathRules.start_break(progress)
		assert_true(PathRules.take(tree, progress, index, true), tree.nodes[index].display_name)
	assert_eq(progress.cores, 2, "8 - 1 - 2 - 3")
	PathRules.start_break(progress)
	progress.cores = 10
	assert_true(PathRules.take(tree, progress, QUARTERMASTER, true))
	PathRules.start_break(progress)
	assert_string_contains(
		PathRules.check(tree, progress, SCAVENGER, true), "Locked out by Fleet foot"
	)
