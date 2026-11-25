extends GutTest

const DEFAULT_SCHEDULE: String = "res://modes/waves/data/default_waves.tres"

var schedule: WaveSchedule
var model: DifficultyModel
var catalog: ModifierCatalog


func before_each() -> void:
	schedule = load(DEFAULT_SCHEDULE)
	model = DifficultyModel.load_default()
	catalog = ModifierCatalog.load_default()


## The forecast is the wave that comes: the same as the report, which uses the game's functions.
func test_the_forecast_is_the_wave_that_spawns() -> void:
	for seed_value in [1, 7, 42]:
		for row in WaveReport.build(schedule, catalog, model, seed_value):
			var forecast: WaveForecast = WaveForecast.of(
				schedule, model, catalog, seed_value, row.wave
			)
			var label: String = "seed %d wave %d" % [seed_value, row.wave]
			assert_eq(forecast.modifier_mask, row.modifier_mask, label)
			assert_eq(forecast.scores, row.axis_scores, label)
			assert_eq(forecast.boss, schedule.boss_for(row.wave) != null, label)


func test_spawner_queue_matches_the_forecast_plan() -> void:
	var merged: WaveModifier = catalog.combined(catalog.pick_for_wave(schedule, 5, 12))
	var spawner := WaveSpawner.new()
	spawner.start_wave(null, schedule, 12, WaveComposer.wave_seed(5, 12), 0, merged)
	var planned: Array[EnemyData] = WaveComposer.plan_wave(schedule, model, catalog, 5, 12)
	assert_eq(spawner.remaining(), planned.size())
	spawner.free()


func test_top_axes_biggest_first_without_empty_ones() -> void:
	var scores := PackedFloat32Array([2.0, 0.0, 6.0, 4.0, 0.0])
	assert_eq(WaveForecast.top_axes(model, scores), [2, 3])
	assert_eq(WaveForecast.top_axes(model, scores, 5), [2, 3, 0])
	assert_eq(WaveForecast.top_axes(model, PackedFloat32Array([0, 0, 0, 0, 0])), [])


func test_scores_travel_in_tenths() -> void:
	assert_eq(WaveForecast.to_byte(6.24), 62)
	assert_eq(WaveForecast.from_byte(62), 6.2)
	assert_eq(WaveForecast.to_byte(40.0), 255, "capped at 25.5")
	assert_eq(WaveForecast.to_byte(-1.0), 0)


func test_the_match_state_carries_it() -> void:
	var forecast: WaveForecast = WaveForecast.of(schedule, model, catalog, 3, 10)
	var state := MatchNetState.new()
	state.set_forecast(forecast)
	var buffer := StreamPeerBuffer.new()
	state.encode(buffer)
	assert_eq(buffer.data_array.size(), state.byte_size())
	buffer.seek(0)
	var back := MatchNetState.new()
	back.decode(buffer)
	assert_true(back.forecast)
	assert_true(back.forecast_boss, "wave 10 is a boss wave")
	assert_eq(back.forecast_modifier_mask, forecast.modifier_mask)
	for i in forecast.scores.size():
		assert_almost_eq(back.forecast_axis_scores()[i], forecast.scores[i], 0.051)
	state.set_forecast(null)
	assert_false(state.forecast)
