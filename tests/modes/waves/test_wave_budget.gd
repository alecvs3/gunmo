extends GutTest

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
	var real: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	assert_eq(real.total_waves, 25)
	assert_eq(real.enemy_types.size(), 3)
	var first: int = WaveBudget.plan(real, 1, _rng(1)).size()
	var last: int = WaveBudget.plan(real, 25, _rng(1)).size()
	assert_between(first, 4, 8, "wave 1 is a handful of grunts")
	assert_between(last, 35, 90, "wave 25 is a crowd")
	var previous: float = 0.0
	for wave in range(1, 26):
		assert_gt(WaveBudget.budget(real, wave), previous, "budgets grow every wave")
		previous = WaveBudget.budget(real, wave)


func test_wave_seed_is_match_seed_and_wave() -> void:
	assert_eq(WaveBudget.wave_seed(99, 7), hash([99, 7]), "same seed as before: replays unchanged")
	assert_ne(WaveBudget.wave_seed(99, 7), WaveBudget.wave_seed(99, 8))
