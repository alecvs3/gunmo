extends GutTest

const DATA: String = "res://modes/waves/data/progression/"

var model: ProgressionModel
var difficulty: DifficultyModel
var settings: MatchSettings
var average: PlayerArchetype


func before_each() -> void:
	model = ProgressionModel.load_default()
	difficulty = DifficultyModel.load_default()
	settings = load("res://modes/data/default_match.tres")
	average = load(DATA + "average.tres")


func test_gun_dps_counts_reloads() -> void:
	var pistol: WeaponData = ShopCatalog.load_default().weapon(0)
	# 12 shots of 20 at 4/s take 3 s, then a 1.2 s reload: 240 damage every 4.2 s.
	assert_almost_eq(PlayerPower.gun_dps(pistol, model), 240.0 / 4.2, 0.01)


func test_kill_shares_add_up_and_favour_the_stronger() -> void:
	var strong := PlayerPower.new()
	strong.dps = 30.0
	var weak := PlayerPower.new()
	weak.dps = 10.0
	var team := TeamPower.of([strong, weak] as Array[PlayerPower])
	var shares: PackedFloat32Array = team.kill_shares(1.3)
	assert_almost_eq(shares[0] + shares[1], 1.0, 0.0001)
	assert_gt(shares[0], 0.75, "more damage also steals more last hits")


func test_team_effects_count_once() -> void:
	var first := PlayerPower.new()
	first.dps = 10.0
	first.team_fire_rate = 0.1
	var second := PlayerPower.new()
	second.dps = 10.0
	second.team_fire_rate = 0.05
	var team := TeamPower.of([first, second] as Array[PlayerPower])
	assert_almost_eq(team.dps, 22.0, 0.001, "the stronger Rally only")


func test_buyer_never_overspends_and_a_saver_keeps_its_interest() -> void:
	var waves: Array[WaveReport.Row] = _waves()
	var greedy := SimPlayer.make(average, 2)
	greedy.credits = 1000.0
	Buyer.take_break(greedy, waves[1], difficulty, model, settings)
	assert_gte(greedy.credits, 0.0)
	assert_almost_eq(greedy.credits + greedy.spent, 1000.0, 0.001)
	var saver := SimPlayer.make(load(DATA + "expert.tres"), 2)
	saver.credits = 1000.0
	Buyer.take_break(saver, waves[1], difficulty, model, settings)
	assert_gte(saver.credits, 500.0, "keeps enough for the most interest")


func test_a_run_grows_stronger_and_pays_the_clear_bonus() -> void:
	var team: TeamSetup = load(DATA + "average_duo.tres")
	var schedule: WaveSchedule = settings.wave_schedule
	var rows := ProgressionRun.run(team, _waves(), schedule, settings, difficulty, model)
	assert_eq(rows.size(), schedule.total_waves)
	assert_gt(rows[-1].progression, rows[0].progression)
	var standing: float = 1.0 - average.down_chance
	var clear: float = (settings.wave_clear_bonus + settings.wave_clear_bonus_per_wave) * standing
	assert_almost_eq(rows[0].income[SimPlayer.CLEAR], clear, 0.01)


func test_strain_only_counts_the_axes_a_wave_pushes() -> void:
	var wave := PackedFloat32Array([5.0, 0.0, 0.0, 0.0, 0.0])
	var team := PackedFloat32Array([3.0, 0.0, 0.0, 9.0, 0.0])
	assert_almost_eq(ProgressionRun.strain(wave, team, difficulty), 20.0, 0.001)


func test_strain_curve_bends_up_after_the_knee_and_measures_misses() -> void:
	var curve: StrainCurve = model.strain
	assert_almost_eq(curve.target(1, 25), curve.first, 0.001)
	assert_almost_eq(curve.target(25, 25), curve.last, 0.001)
	assert_almost_eq(curve.target(curve.knee_wave, 25), curve.knee_value, 0.001)
	var early: float = curve.target(curve.knee_wave, 25) - curve.target(curve.knee_wave - 1, 25)
	var after: float = curve.target(curve.knee_wave + 1, 25) - curve.target(curve.knee_wave, 25)
	assert_almost_eq(after, early, 1.0, "no sudden step at the knee")
	assert_gt(curve.target(25, 25) - curve.target(24, 25), 3.0 * early, "the end climbs fastest")
	assert_eq(curve.miss(curve.first + curve.band, 1, 25), 0.0, "the band's edge is on target")
	assert_almost_eq(curve.miss(curve.first + curve.band + 3.0, 1, 25), 3.0, 0.001)


func _waves() -> Array[WaveReport.Row]:
	var schedule: WaveSchedule = settings.wave_schedule
	return WaveReport.build(schedule, ModifierCatalog.load_default(), difficulty, 1)
