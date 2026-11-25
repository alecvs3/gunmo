extends GutTest
## CounterProfile: which damage type a planned wave is weakest to.

const K: int = DamageType.Type.KINETIC
const P: int = DamageType.Type.PIERCE
const B: int = DamageType.Type.BLAST

var catalog: ModifierCatalog
var none := WaveModifier.new()
var grunt: EnemyData
var swarmer: EnemyData
var tank: EnemyData


func before_each() -> void:
	catalog = ModifierCatalog.load_default()
	grunt = load("res://enemies/data/grunt.tres")
	swarmer = load("res://enemies/data/swarmer.tres")
	tank = load("res://enemies/data/tank.tres")


func _wave(parts: Array) -> Array[EnemyData]:
	var planned: Array[EnemyData] = []
	for i in range(0, parts.size(), 2):
		for n in int(parts[i + 1]):
			planned.append(parts[i])
	return planned


func _modifier_named(display_name: String) -> int:
	for i in catalog.modifiers.size():
		if catalog.modifiers[i].display_name == display_name:
			return 1 << i
	return 0


func test_an_empty_wave_has_no_counter() -> void:
	var profile: CounterProfile = CounterProfile.of(_wave([]), none)
	for type in DamageType.COUNT:
		assert_eq(profile.multiplier(type), 1.0)
	assert_eq(profile.best_type(), K)


func test_a_plain_wave_is_kinetic() -> void:
	assert_eq(CounterProfile.of(_wave([grunt, 10]), none).best_type(), K, "ties go to Kinetic")


func test_an_armored_wave_wants_pierce() -> void:
	var armored: WaveModifier = catalog.combined(_modifier_named("Armored"))
	var profile: CounterProfile = CounterProfile.of(_wave([grunt, 10]), armored)
	assert_eq(profile.best_type(), P)
	assert_almost_eq(profile.multiplier(P), 1.3, 1e-6)
	assert_almost_eq(profile.multiplier(K), 0.6, 1e-6)
	assert_almost_eq(profile.multiplier(B), 0.7, 1e-6)


func test_a_swarm_wave_wants_blast() -> void:
	var profile: CounterProfile = CounterProfile.of(_wave([swarmer, 12]), none)
	assert_eq(profile.best_type(), B)
	assert_almost_eq(profile.multiplier(B), 1.5, 1e-6)


func test_enemies_count_by_their_health() -> void:
	var grunts: int = roundi(tank.max_health / float(grunt.max_health))
	var health_tank: float = tank.max_health
	var health_grunts: float = grunts * grunt.max_health
	var expected: float = (health_tank * 1.3 + health_grunts) / (health_tank + health_grunts)
	var profile: CounterProfile = CounterProfile.of(_wave([tank, 1, grunt, grunts]), none)
	assert_almost_eq(profile.multiplier(P), expected, 1e-6)


func test_a_few_swarmers_only_tip_it_without_an_edge() -> void:
	var profile: CounterProfile = CounterProfile.of(_wave([grunt, 10, swarmer, 6]), none)
	assert_eq(profile.best_type(), B, "any edge at all")
	assert_eq(profile.best_type(0.2), K, "not worth switching guns for")


func test_splits_count_with_their_own_traits() -> void:
	var splitter: EnemyData = load("res://enemies/data/splitter.tres")
	var profile: CounterProfile = CounterProfile.of(_wave([splitter, 1]), none)
	assert_gt(profile.multiplier(B), 1.0, "its Splitlings are a swarm")


func test_every_default_armored_wave_wants_pierce() -> void:
	var schedule: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	var model: DifficultyModel = DifficultyModel.load_default()
	var armored_bit: int = _modifier_named("Armored")
	var seen: int = 0
	for wave in range(1, schedule.total_waves + 1):
		var mask: int = catalog.pick_for_wave(schedule, 1, wave)
		if mask & armored_bit == 0:
			continue
		var combined: WaveModifier = catalog.combined(mask)
		var rng := RandomNumberGenerator.new()
		rng.seed = WaveComposer.wave_seed(1, wave)
		var planned: Array[EnemyData] = WaveComposer.plan(schedule, model, wave, rng, combined)
		assert_eq(CounterProfile.of(planned, combined).best_type(0.1), P, "wave %d" % wave)
		seen += 1
	assert_gt(seen, 0, "seed 1 has Armored waves")
