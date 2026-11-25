extends GutTest

var schedule: WaveSchedule
var curve: DifficultyCurve


func before_each() -> void:
	curve = DifficultyCurve.new()
	curve.first = 1.0
	curve.last = 9.0
	curve.boss_bonus = 0.4
	curve.last_wave_bonus = 1.0
	curve.after_boss = PackedFloat32Array([0.3, 0.15])
	schedule = WaveSchedule.new()
	schedule.total_waves = 9
	schedule.boss_waves = PackedInt32Array([4])
	schedule.bosses.assign([EnemyData.new()])
	schedule.difficulty = curve


func test_the_trend_runs_from_first_to_last() -> void:
	assert_eq(curve.trend(1, 9), 1.0)
	assert_eq(curve.trend(5, 9), 5.0)
	assert_eq(curve.trend(9, 9), 9.0)
	curve.power = 2.0
	assert_eq(curve.trend(5, 9), 3.0, "a steeper climb late")


func test_a_boss_wave_is_a_little_above_the_waves_after_it() -> void:
	assert_almost_eq(curve.target(4, schedule), 4.4, 0.001)
	assert_almost_eq(curve.target(5, schedule), 4.7, 0.001)
	assert_almost_eq(curve.target(6, schedule), 5.85, 0.001)
	assert_almost_eq(curve.target(7, schedule), 7.0, 0.001, "back on the trend")
	assert_almost_eq(curve.target(9, schedule), 10.0, 0.001, "the last wave")


func test_an_override_pins_a_wave() -> void:
	curve.overrides = PackedFloat32Array([0.0, 7.5])
	assert_eq(curve.target(2, schedule), 7.5)
	assert_eq(curve.target(1, schedule), 1.0, "0 = use the curve")


func test_the_default_curve_rises_with_boss_bumps() -> void:
	var real: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	var targets: Array[float] = []
	for wave in range(1, real.total_waves + 1):
		targets.append(real.difficulty.target(wave, real))
	for wave in real.boss_waves:
		if wave < real.total_waves:
			assert_gt(targets[wave - 1], targets[wave], "boss wave %d above the next" % wave)
			assert_lt(targets[wave - 1] - targets[wave], 0.6, "but only a little")
	for i in range(2, targets.size()):
		if real.boss_for(i) == null and real.boss_for(i - 1) == null:
			assert_gt(targets[i], targets[i - 1] - 0.001, "wave %d keeps climbing" % (i + 1))
	assert_gt(targets.back(), targets[targets.size() - 2], "the last wave is the hardest")


func test_targets_grow_with_the_number_of_players() -> void:
	var plain: float = curve.target(5, schedule)
	assert_almost_eq(curve.target(5, schedule, 3), plain, 0.001, "no scale yet")
	curve.player_scale = PackedFloat32Array([0.6, 1.0, 1.3])
	assert_almost_eq(curve.target(5, schedule, 1), plain * 0.6, 0.001)
	assert_almost_eq(curve.target(5, schedule, 2), plain, 0.001)
	assert_almost_eq(curve.target(5, schedule, 8), plain * 1.3, 0.001, "past the list: the last")
	assert_almost_eq(curve.target(5, schedule, 0), plain, 0.001, "0 = unscaled")
