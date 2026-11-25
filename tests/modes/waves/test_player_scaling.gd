extends GutTest

const DEFAULT_SCHEDULE: String = "res://modes/waves/data/default_waves.tres"

var schedule: WaveSchedule
var model: DifficultyModel
var catalog: ModifierCatalog


func before_each() -> void:
	schedule = load(DEFAULT_SCHEDULE)
	model = DifficultyModel.load_default()
	catalog = ModifierCatalog.load_default()


func test_a_bigger_team_gets_a_bigger_wave_on_target() -> void:
	var duo: Array[EnemyData] = WaveComposer.plan_wave(schedule, model, catalog, 3, 12, 2)
	var squad: Array[EnemyData] = WaveComposer.plan_wave(schedule, model, catalog, 3, 12, 4)
	assert_gt(squad.size(), duo.size())
	var merged: WaveModifier = catalog.combined(catalog.pick_for_wave(schedule, 3, 12))
	var score: float = model.difficulty(model.sheet_for(squad), merged)
	var target: float = WaveComposer.target_for(schedule, 12, 4)
	assert_almost_eq(score, target, WaveComposer.tolerance_for(schedule) + 0.01)


func test_a_duo_keeps_the_waves_it_had() -> void:
	var unscaled: Array[EnemyData] = WaveComposer.plan_wave(schedule, model, catalog, 3, 12)
	var duo: Array[EnemyData] = WaveComposer.plan_wave(schedule, model, catalog, 3, 12, 2)
	assert_eq(duo, unscaled)


func test_the_forecast_remembers_its_team_size() -> void:
	var forecast: WaveForecast = WaveForecast.of(schedule, model, catalog, 3, 12, 4)
	assert_eq(forecast.players, 4)
	var squad: Array[EnemyData] = WaveComposer.plan_wave(schedule, model, catalog, 3, 12, 4)
	var merged: WaveModifier = catalog.combined(forecast.modifier_mask)
	assert_eq(forecast.scores, model.scores(model.sheet_for(squad), merged), "exact for 4")
