extends GutTest

var model: DifficultyModel
var grunt: EnemyData
var none := WaveModifier.new()


func _axis(axis: DifficultyAxis, reference: float, weight: float = 1.0) -> DifficultyAxis:
	axis.reference = reference
	axis.weight = weight
	return axis


func _wave(type: EnemyData, count: int) -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	for i in count:
		enemies.append(type)
	return enemies


func before_each() -> void:
	grunt = load("res://enemies/data/grunt.tres")
	model = DifficultyModel.new()
	model.exponent = 1.0
	model.axes.assign([_axis(ToughnessAxis.new(), 600.0), _axis(MeleeAxis.new(), 200.0)])


func test_an_empty_wave_is_zero() -> void:
	assert_eq(model.difficulty(WaveSheet.new(), none), 0.0)


func test_every_axis_at_its_reference_is_ten() -> void:
	var sheet: WaveSheet = model.sheet_for(_wave(grunt, 10))
	assert_eq(model.scores(sheet, none), PackedFloat32Array([10.0, 10.0]))
	assert_almost_eq(model.difficulty(sheet, none), 10.0, 0.001)


func test_the_exponent_softens_growth() -> void:
	model.exponent = 0.5
	var sheet: WaveSheet = model.sheet_for(_wave(grunt, 40))
	assert_almost_eq(model.scores(sheet, none)[0], 20.0, 0.01, "4× the reference scores 2× 10")


func test_weights_decide_how_much_an_axis_counts() -> void:
	model.axes[1].weight = 0.0
	model.axes[0].reference = 300.0
	assert_almost_eq(model.difficulty(model.sheet_for(_wave(grunt, 10)), none), 20.0, 0.01)


func test_more_enemies_never_score_lower() -> void:
	var real: DifficultyModel = DifficultyModel.load_default()
	var types: Array[String] = ["grunt", "runner", "shooter", "tank", "swarmer", "support"]
	var enemies: Array[EnemyData] = []
	var last: float = 0.0
	for type_name in types:
		enemies.append(load("res://enemies/data/%s.tres" % type_name))
		var now: float = real.difficulty(real.sheet_for(enemies), none)
		assert_gt(now, last, "adding a %s" % type_name)
		last = now


func test_modifiers_move_the_axes_they_touch() -> void:
	var tough := WaveModifier.new()
	tough.health_multiplier = 1.4
	var sheet: WaveSheet = model.sheet_for(_wave(grunt, 10))
	assert_almost_eq(model.scores(sheet, tough)[0], 14.0, 0.01, "Tough: health")
	assert_almost_eq(model.scores(sheet, tough)[1], 10.0, 0.01, "not damage")


func test_pressure_counts_speed_and_bodies() -> void:
	var fast := WaveModifier.new()
	fast.speed_multiplier = 1.5
	var axis := PressureAxis.new()
	var sheet: WaveSheet = model.sheet_for(_wave(grunt, 4))
	assert_almost_eq(axis.raw(sheet, none), 4.0, 0.01, "4 grunts at the reference speed")
	assert_almost_eq(axis.raw(sheet, fast), 6.0, 0.01)


func test_sustain_counts_pulses_and_regeneration() -> void:
	var axis := SustainAxis.new()
	axis.allies_per_pulse = 2.0
	var support: EnemyData = load("res://enemies/data/support.tres")
	var pulse: HealPulseAttack = support.attack
	var sheet: WaveSheet = model.sheet_for([support] as Array[EnemyData])
	var expected: float = pulse.heal_share / pulse.cycle_seconds() * 2.0 * support.max_health
	assert_almost_eq(axis.raw(sheet, none), expected, 0.01)
	var regen := WaveModifier.new()
	regen.regen_per_second = 0.1
	assert_almost_eq(axis.raw(sheet, regen), expected + 9.0, 0.01, "10% of 90 health a second")


func test_the_default_model_has_named_axes() -> void:
	var real: DifficultyModel = DifficultyModel.load_default()
	assert_eq(real.axes.size(), 5)
	for axis in real.axes:
		assert_false(axis.short_name.is_empty(), axis.display_name)
		assert_gt(axis.reference, 0.0, axis.display_name)
