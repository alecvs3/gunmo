extends GutTest

const DEFAULT_SCHEDULE: String = "res://modes/waves/data/default_waves.tres"
const DEFAULT_MATCH: String = "res://modes/data/default_match.tres"

var schedule: WaveSchedule
var model: DifficultyModel
var none := WaveModifier.new()
var grunt: EnemyData
var runner: EnemyData
var swarmer: EnemyData
var shooter: EnemyData


func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _plan(wave: int, seed_value: int = 7, modifier: WaveModifier = none) -> Array[EnemyData]:
	return WaveComposer.plan(schedule, model, wave, _rng(seed_value), modifier)


func _score(enemies: Array[EnemyData], modifier: WaveModifier = none) -> float:
	return model.difficulty(model.sheet_for(enemies), modifier)


func before_each() -> void:
	model = DifficultyModel.load_default()
	grunt = load("res://enemies/data/grunt.tres")
	runner = load("res://enemies/data/runner.tres")
	swarmer = load("res://enemies/data/swarmer.tres").duplicate()
	swarmer.first_wave = 1
	shooter = load("res://enemies/data/shooter.tres").duplicate()
	shooter.first_wave = 1
	schedule = WaveSchedule.new()
	schedule.total_waves = 5
	schedule.difficulty = DifficultyCurve.new()
	schedule.difficulty.first = 2.0
	schedule.difficulty.last = 5.0
	schedule.difficulty.tolerance = 0.3
	schedule.enemy_types.assign([grunt, runner])


func test_a_wave_lands_within_tolerance_of_its_target() -> void:
	for wave in range(1, 6):
		var target: float = schedule.difficulty.target(wave, schedule)
		assert_almost_eq(_score(_plan(wave)), target, 0.3, "wave %d" % wave)


func test_same_seed_same_wave() -> void:
	assert_eq(_plan(3, 11), _plan(3, 11))


func test_first_wave_is_respected() -> void:
	runner.first_wave = 4
	assert_false(_plan(2).has(runner))
	runner.first_wave = 3


func test_a_tougher_wave_needs_fewer_enemies() -> void:
	var tough := WaveModifier.new()
	tough.health_multiplier = 2.0
	tough.speed_multiplier = 1.4
	assert_lt(_plan(5, 7, tough).size(), _plan(5, 7).size())
	assert_almost_eq(
		_score(_plan(5, 7, tough), tough), schedule.difficulty.target(5, schedule), 0.3
	)


func test_the_boss_comes_first() -> void:
	var boss: EnemyData = load("res://enemies/data/bosses/brood_mother.tres")
	schedule.boss_waves = PackedInt32Array([5])
	schedule.bosses.assign([boss])
	schedule.difficulty.last = 8.0
	var enemies: Array[EnemyData] = _plan(5)
	assert_eq(enemies[0], boss)
	assert_eq(enemies.count(boss), 1)


func test_groups_stay_together() -> void:
	schedule.enemy_types.assign([swarmer])
	var enemies: Array[EnemyData] = _plan(5)
	assert_gt(enemies.size(), 0)
	assert_eq(enemies.size() % swarmer.group_size, 0, "whole groups when they fit")


func test_an_enemy_limit_caps_and_requires() -> void:
	var cap := EnemyLimit.new()
	cap.enemy = runner
	cap.max_count = 1
	var need := EnemyLimit.new()
	need.enemy = grunt
	need.min_count = 3
	schedule.rules.assign([cap, need])
	for seed_value in 10:
		var enemies: Array[EnemyData] = _plan(5, seed_value)
		assert_lte(enemies.count(runner), 1)
		assert_gte(enemies.count(grunt), 3)


func test_a_limit_only_counts_in_its_waves() -> void:
	var cap := EnemyLimit.new()
	cap.enemy = runner
	cap.max_count = 0
	cap.to_wave = 2
	schedule.rules.assign([cap])
	assert_false(_plan(2).has(runner))
	var later: int = 0
	for seed_value in 10:
		later += _plan(5, seed_value).count(runner)
	assert_gt(later, 0, "allowed again after wave 2")


func test_an_axis_limit_caps_its_share() -> void:
	var cap := AxisLimit.new()
	cap.axis = 2
	cap.max_share = 0.4
	schedule.rules.assign([cap])
	for seed_value in 5:
		var sheet: WaveSheet = model.sheet_for(_plan(5, seed_value))
		var shares: PackedFloat32Array = model.shares(model.scores(sheet, none))
		assert_lte(shares[2], 0.4 + 0.05, "seed %d" % seed_value)


func test_role_shares_pull_toward_their_role() -> void:
	schedule.enemy_types.assign([grunt, shooter])
	schedule.shares_first = PackedFloat32Array([0.0, 1.0, 0.0, 0.0])
	schedule.shares_last = schedule.shares_first
	var shooters: int = 0
	var grunts: int = 0
	for seed_value in 10:
		var enemies: Array[EnemyData] = _plan(4, seed_value)
		shooters += enemies.count(shooter)
		grunts += enemies.count(grunt)
	assert_gt(shooters, grunts, "the ranged role gets most of the wave")


func test_every_default_wave_lands_near_its_target() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	for seed_value in 20:
		for wave in range(1, real.total_waves + 1):
			var mask: int = catalog.pick_for_wave(real, seed_value, wave)
			var merged: WaveModifier = catalog.combined(mask)
			var rng := RandomNumberGenerator.new()
			rng.seed = WaveComposer.wave_seed(seed_value, wave)
			var enemies: Array[EnemyData] = WaveComposer.plan(real, model, wave, rng, merged)
			var target: float = real.difficulty.target(wave, real)
			var got: float = model.difficulty(model.sheet_for(enemies), merged)
			assert_almost_eq(
				got, target, real.difficulty.tolerance, "seed %d wave %d" % [seed_value, wave]
			)


func test_wave_seed_is_match_seed_and_wave() -> void:
	assert_eq(
		WaveComposer.wave_seed(99, 7), hash([99, 7]), "same seed as before: replays unchanged"
	)
	assert_ne(WaveComposer.wave_seed(99, 7), WaveComposer.wave_seed(99, 8))


func test_spawn_interval_blends_across_waves() -> void:
	schedule.total_waves = 25
	schedule.first_spawn_interval = 1.0
	schedule.last_spawn_interval = 0.2
	assert_eq(schedule.spawn_interval(1), 1.0)
	assert_almost_eq(schedule.spawn_interval(25), 0.2, 0.0001)
	assert_almost_eq(schedule.spawn_interval(13), 0.6, 0.0001)


func test_role_shares_blend_and_skip_roles_without_types() -> void:
	schedule.total_waves = 25
	schedule.shares_first = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	schedule.shares_last = PackedFloat32Array([0.5, 0.3, 0.2, 0.0])
	var types: Array[EnemyData] = [grunt, shooter]
	var last: PackedFloat32Array = WaveDraft.role_shares(schedule, 25, types)
	assert_almost_eq(last[EnemyData.Role.FRONTLINE], 0.5 / 0.8, 1e-4, "no swarm type: its share")
	assert_almost_eq(last[EnemyData.Role.RANGED], 0.3 / 0.8, 1e-4, "goes to the others")
	assert_eq(last[EnemyData.Role.SWARM], 0.0)
	assert_almost_eq(WaveDraft.role_shares(schedule, 1, types)[EnemyData.Role.FRONTLINE], 1.0, 1e-4)


func test_max_enemies_stops_an_unreachable_target() -> void:
	schedule.difficulty.overrides = PackedFloat32Array([1000.0])
	schedule.max_enemies = 30
	assert_eq(_plan(1).size(), 30)


func test_default_schedule_shape() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	assert_eq(real.total_waves, 25)
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	var rows: Array[WaveReport.Row] = WaveReport.build(real, catalog, model, 1)
	assert_between(rows[0].enemies, 4, 10, "wave 1 is a handful of grunts")
	assert_between(rows[24].enemies, 15, 90, "wave 25 is a crowd around its boss")


## Boss waves put much of their difficulty in the boss, so they may skip a role. Swarms have
## the smallest share (10%), so a late wave now and then has none.
func test_late_default_waves_have_every_role() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	var waves: int = 0
	var swarms: int = 0
	for seed_value in 10:
		for row in WaveReport.build(real, catalog, model, seed_value).slice(19):
			if real.boss_for(row.wave) != null:
				continue
			waves += 1
			swarms += 1 if row.counts.get("Swarmer", 0) > 0 else 0
			for name in ["Shooter", "Support"]:
				var label: String = "seed %d wave %d %s" % [seed_value, row.wave, name]
				assert_gt(row.counts.get(name, 0), 0, label)
	assert_gt(swarms, waves * 0.7, "most late waves have a swarm")


## Balance pass #139: a player earns about 10,000 credits by wave 22 (early calls and pets
## included), so maxing both upgrades (~9,500) and pets (~4,000) is impossible. Before the
## composer, two players each got about 8,650 from kills and clear bonuses by wave 22: keep it.
func test_credits_by_wave_22_stay_where_the_balance_pass_left_them() -> void:
	var real: WaveSchedule = load(DEFAULT_SCHEDULE)
	var settings: MatchSettings = load(DEFAULT_MATCH)
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	var totals: Array[float] = []
	for seed_value in 10:
		var credits: float = 0.0
		for row in WaveReport.build(real, catalog, model, seed_value).slice(0, 22):
			credits += row.bounty / 2.0
			credits += settings.wave_clear_bonus + settings.wave_clear_bonus_per_wave * row.wave
		totals.append(credits)
	totals.sort()
	assert_between(totals[5], 8000.0, 9300.0, "median credits per player by wave 22")


## Interest is paid at every clear but the last (wave 25 ends the match). A player who keeps a
## bank of 500 or more from wave 5 earns the cap each wave: about 1,000, never more.
func test_interest_from_a_bank_held_since_wave_5_adds_at_most_about_1000() -> void:
	var settings: MatchSettings = load(DEFAULT_MATCH)
	var last_paid: int = settings.wave_schedule.total_waves - 1
	var held: int = 0
	var hoarded: int = 0
	for _wave in range(5, last_paid + 1):
		held += Interest.amount(500, settings)
		hoarded += Interest.amount(100000, settings)
	assert_between(held, 900, 1100, "interest on 500 held from wave 5 to wave 25")
	assert_eq(hoarded, held, "holding more than 500 pays no more")
