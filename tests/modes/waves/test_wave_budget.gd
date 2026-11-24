extends GutTest

const DEFAULT_SCHEDULE: String = "res://modes/waves/data/default_waves.tres"

var schedule: WaveSchedule
var cheap: EnemyData
var pricey: EnemyData
var late: EnemyData


func _type(cost: float, first_wave: int, weight: float) -> EnemyData:
	var type := EnemyData.new()
	type.cost = cost
	type.first_wave = first_wave
	type.spawn_weight = weight
	return type


func before_each() -> void:
	schedule = WaveSchedule.new()
	schedule.total_waves = 25
	schedule.base_budget = 6.0
	schedule.budget_growth = 2.0
	schedule.budget_curve = 1.0
	cheap = _type(1.0, 1, 1.0)
	pricey = _type(4.0, 1, 1.0)
	late = _type(2.0, 5, 1.0)
	schedule.enemy_types.assign([cheap, pricey, late])


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _cost(enemies: Array[EnemyData]) -> float:
	var total: float = 0.0
	for enemy in enemies:
		total += enemy.cost
	return total


func test_budget_curve() -> void:
	assert_eq(WaveBudget.budget(schedule, 1), 6.0)
	assert_eq(WaveBudget.budget(schedule, 2), 8.0)
	schedule.budget_curve = 2.0
	assert_eq(WaveBudget.budget(schedule, 4), 6.0 + 2.0 * 9.0)


func test_plan_spends_budget_and_leaves_less_than_cheapest() -> void:
	for wave in range(1, 26):
		var plan: Array[EnemyData] = WaveBudget.plan(schedule, wave, _rng(wave))
		var spent: float = _cost(plan)
		assert_lte(spent, WaveBudget.budget(schedule, wave) + 0.0001)
		assert_lt(WaveBudget.budget(schedule, wave) - spent, 1.0, "nothing affordable left")


func test_plan_respects_first_wave() -> void:
	for wave in range(1, 5):
		assert_does_not_have(WaveBudget.plan(schedule, wave, _rng(1)), late, "wave %d" % wave)
	assert_has(WaveBudget.available(schedule, 5), late)


func test_same_seed_same_wave() -> void:
	var a: Array[EnemyData] = WaveBudget.plan(schedule, 10, _rng(42))
	var b: Array[EnemyData] = WaveBudget.plan(schedule, 10, _rng(42))
	assert_eq(a, b)


func test_zero_weight_is_never_picked() -> void:
	pricey.spawn_weight = 0.0
	assert_does_not_have(WaveBudget.plan(schedule, 20, _rng(3)), pricey)


func test_nothing_affordable_gives_empty_wave() -> void:
	schedule.base_budget = 0.5
	assert_eq(WaveBudget.plan(schedule, 1, _rng(1)).size(), 0)


func test_spawn_interval_blends_across_waves() -> void:
	schedule.first_spawn_interval = 1.0
	schedule.last_spawn_interval = 0.2
	assert_eq(schedule.spawn_interval(1), 1.0)
	assert_almost_eq(schedule.spawn_interval(25), 0.2, 0.0001)
	assert_almost_eq(schedule.spawn_interval(13), 0.6, 0.0001)


func test_default_schedule_shape() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	assert_eq(real.total_waves, 25)
	assert_eq(real.enemy_types.size(), 8)
	var first: int = WaveBudget.plan(real, 1, _rng(1)).size()
	var last: int = WaveBudget.plan(real, 25, _rng(1), 2.0).size()
	assert_between(first, 4, 8, "wave 1 is a handful of grunts")
	assert_between(last, 30, 90, "wave 25 is a crowd")
	var previous: float = 0.0
	for wave in range(1, 26):
		assert_gt(WaveBudget.budget(real, wave), previous, "budgets grow every wave")
		previous = WaveBudget.budget(real, wave)


func test_wave_seed_is_match_seed_and_wave() -> void:
	assert_eq(WaveBudget.wave_seed(99, 7), hash([99, 7]), "same seed as before: replays unchanged")
	assert_ne(WaveBudget.wave_seed(99, 7), WaveBudget.wave_seed(99, 8))


func test_group_types_are_bought_together() -> void:
	var swarm: EnemyData = _type(0.5, 1, 1.0)
	swarm.group_size = 4
	schedule.enemy_types.assign([swarm])
	schedule.base_budget = 5.0
	var plan: Array[EnemyData] = WaveBudget.plan(schedule, 1, _rng(1))
	assert_eq(plan.size(), 10, "whole groups while the points last")
	schedule.base_budget = 1.0
	assert_eq(WaveBudget.plan(schedule, 1, _rng(1)).size(), 2, "a partial group at the end")


func test_role_shares_blend_and_skip_roles_without_types() -> void:
	schedule.shares_first = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	schedule.shares_last = PackedFloat32Array([0.5, 0.3, 0.2, 0.0])
	var ranged: EnemyData = _type(2.0, 1, 1.0)
	ranged.role = EnemyData.Role.RANGED
	schedule.enemy_types.assign([cheap, ranged])
	var types: Array[EnemyData] = WaveBudget.available(schedule, 25)
	var last: PackedFloat32Array = WaveBudget.role_shares(schedule, 25, types)
	assert_almost_eq(last[EnemyData.Role.FRONTLINE], 0.5 / 0.8, 1e-4, "no swarm type: its share")
	assert_almost_eq(last[EnemyData.Role.RANGED], 0.3 / 0.8, 1e-4, "goes to the others")
	assert_eq(last[EnemyData.Role.SWARM], 0.0)
	var first: PackedFloat32Array = WaveBudget.role_shares(schedule, 1, types)
	assert_almost_eq(first[EnemyData.Role.FRONTLINE], 1.0, 1e-4)


func test_no_shares_means_everything_frontline() -> void:
	var shares: PackedFloat32Array = WaveBudget.role_shares(
		schedule, 3, WaveBudget.available(schedule, 3)
	)
	assert_eq(shares[EnemyData.Role.FRONTLINE], 1.0)


func test_roles_get_their_share_of_the_points() -> void:
	schedule.base_budget = 200.0
	schedule.shares_first = PackedFloat32Array([0.5, 0.5, 0.0, 0.0])
	var ranged: EnemyData = _type(2.0, 1, 1.0)
	ranged.role = EnemyData.Role.RANGED
	schedule.enemy_types.assign([cheap, ranged])
	var plan: Array[EnemyData] = WaveBudget.plan(schedule, 1, _rng(5))
	assert_eq(plan.count(ranged), 50, "100 ranged points / 2")
	assert_eq(plan.count(cheap), 100)
	assert_ne(plan.slice(0, 50).count(ranged), 0, "shuffled, not all frontline first")


func test_a_threatening_wave_buys_fewer() -> void:
	var plain: int = WaveBudget.plan(schedule, 10, _rng(2)).size()
	var tough: Array[EnemyData] = WaveBudget.plan(schedule, 10, _rng(2), 2.0)
	assert_lt(tough.size(), plain)
	assert_lte(_cost(tough), WaveBudget.budget(schedule, 10) / 2.0 + 0.0001)


func test_default_curve_rises_every_wave_without_spikes() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	for seed_value in 20:
		var previous: float = 0.0
		for row in WaveReport.build(real, catalog, seed_value):
			var label: String = "seed %d wave %d" % [seed_value, row.wave]
			assert_gt(row.threat, previous, label + " rises")
			assert_gt(row.threat, row.budget - 3.0, label + " spends its budget (no dips)")
			previous = row.threat
	var step: float = 0.0
	for wave in range(2, 26):
		var grew: float = WaveBudget.budget(real, wave) - WaveBudget.budget(real, wave - 1)
		assert_gte(grew, step, "the budget's growth never slows (wave %d)" % wave)
		step = grew


func test_late_default_waves_have_every_role() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	for seed_value in 10:
		for row in WaveReport.build(real, catalog, seed_value).slice(19):
			for name in ["Shooter", "Swarmer", "Support"]:
				assert_gt(
					row.counts.get(name, 0), 0, "seed %d wave %d %s" % [seed_value, row.wave, name]
				)


func test_a_strong_threat_still_buys_one_enemy() -> void:
	schedule.base_budget = 4.0
	schedule.enemy_types.assign([pricey])
	assert_eq(WaveBudget.plan(schedule, 1, _rng(1), 3.0).size(), 1, "4 / 3 < 4, but one is bought")
