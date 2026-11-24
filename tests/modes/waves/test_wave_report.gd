extends GutTest

const MATCH_SEED: int = 1234

var schedule: WaveSchedule
var catalog: ModifierCatalog
var imp: EnemyData
var ogre: EnemyData


func _type(name: String, cost: float, health: int) -> EnemyData:
	var type := EnemyData.new()
	type.display_name = name
	type.cost = cost
	type.max_health = health
	return type


func _modifier(name: String, health: float, taken: float) -> WaveModifier:
	var modifier := WaveModifier.new()
	modifier.display_name = name
	modifier.health_multiplier = health
	modifier.damage_taken_multiplier = taken
	return modifier


func before_each() -> void:
	schedule = WaveSchedule.new()
	schedule.total_waves = 3
	schedule.base_budget = 4.0
	schedule.budget_growth = 3.0
	schedule.first_spawn_interval = 1.0
	schedule.last_spawn_interval = 0.5
	schedule.max_alive = 5
	schedule.first_modifier_wave = 2
	schedule.double_modifier_wave = 3
	imp = _type("Imp", 1.0, 10)
	ogre = _type("Ogre", 3.0, 101)
	schedule.enemy_types.assign([imp, ogre])
	catalog = ModifierCatalog.new()
	catalog.modifiers.assign([_modifier("Tough", 1.5, 1.0), _modifier("Armored", 1.0, 0.5)])


func _plan(wave: int) -> Array[EnemyData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = WaveBudget.wave_seed(MATCH_SEED, wave)
	return WaveBudget.plan(schedule, wave, rng)


func test_one_row_per_wave() -> void:
	var rows: Array[WaveReport.Row] = WaveReport.build(schedule, catalog, MATCH_SEED)
	assert_eq(rows.size(), 3)
	assert_eq(rows.map(func(r: WaveReport.Row) -> int: return r.wave), [1, 2, 3])


func test_rows_match_budget_and_spawner() -> void:
	for row in WaveReport.build(schedule, catalog, MATCH_SEED):
		assert_eq(row.budget, WaveBudget.budget(schedule, row.wave))
		var spawner := WaveSpawner.new()
		var seed_value: int = WaveBudget.wave_seed(MATCH_SEED, row.wave)
		spawner.start_wave(null, schedule, row.wave, seed_value, row.modifier_mask)
		assert_eq(row.enemies, spawner.remaining(), "wave %d: the spawner's queue" % row.wave)
		spawner.free()
		var planned: Array[EnemyData] = _plan(row.wave)
		assert_eq(row.counts.get("Imp", 0), planned.count(imp), "wave %d imps" % row.wave)
		assert_eq(row.counts.get("Ogre", 0), planned.count(ogre), "wave %d ogres" % row.wave)


func test_modifiers_match_the_game_pick() -> void:
	var rows: Array[WaveReport.Row] = WaveReport.build(schedule, catalog, MATCH_SEED)
	assert_eq(rows[0].modifier_mask, 0, "wave 1 has none")
	assert_eq(rows[0].modifiers, "")
	for row in rows:
		assert_eq(row.modifier_mask, catalog.pick_for_wave(schedule, MATCH_SEED, row.wave))
		assert_eq(row.modifiers, catalog.names(row.modifier_mask))
	assert_eq(rows[2].modifier_mask, 0b11, "wave 3 has both")


func test_health_uses_the_wave_modifiers() -> void:
	var row: WaveReport.Row = WaveReport.row(schedule, catalog, MATCH_SEED, 3)
	var expected: int = 0
	for type in _plan(3):
		expected += roundi(type.max_health * 1.5)
	assert_eq(row.total_health, expected, "Tough: 1.5x health, rounded per enemy")
	assert_eq(row.effective_health, expected * 2, "Armored: half damage taken")
	var plain: WaveReport.Row = WaveReport.row(schedule, catalog, MATCH_SEED, 1)
	assert_eq(plain.total_health, plain.effective_health)


func test_peak_alive_is_the_cap_and_spawn_time_follows_the_interval() -> void:
	schedule.max_alive = 2
	var row: WaveReport.Row = WaveReport.row(schedule, catalog, MATCH_SEED, 3)
	assert_gt(row.enemies, 2)
	assert_eq(row.peak_alive, 2)
	assert_almost_eq(row.spawn_seconds, (row.enemies - 1) * 0.5, 1e-4)
	schedule.max_alive = 500
	assert_eq(WaveReport.row(schedule, catalog, MATCH_SEED, 3).peak_alive, row.enemies)


func test_format_has_a_line_per_wave_and_a_column_per_type() -> void:
	var rows: Array[WaveReport.Row] = WaveReport.build(schedule, catalog, MATCH_SEED)
	var lines: PackedStringArray = WaveReport.format(schedule, rows).split("\n")
	assert_eq(lines.size(), 2 + 3, "header, rule, 3 waves")
	assert_string_contains(lines[0], "| Imp | Ogre |")
	assert_string_starts_with(lines[2], "| 1 | 4.0 | ")
	assert_string_ends_with(lines[2], "| - |")


func test_every_default_wave_has_enemies() -> void:
	var real: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	var real_catalog: ModifierCatalog = ModifierCatalog.load_default()
	for seed_value in 20:
		for row in WaveReport.build(real, real_catalog, seed_value):
			assert_gt(row.enemies, 0, "seed %d wave %d is empty" % [seed_value, row.wave])
			assert_gt(row.total_health, 0)
	assert_eq(WaveReport.build(real, real_catalog, 1).size(), 25)


func test_effective_health_counts_an_enemy_s_own_armor() -> void:
	ogre.damage_taken = 0.5
	var row: WaveReport.Row = WaveReport.row(schedule, catalog, MATCH_SEED, 1)
	var expected: float = 0.0
	for type in _plan(1):
		expected += type.max_health / type.damage_taken
	assert_eq(row.effective_health, roundi(expected))


func test_health_includes_what_an_enemy_splits_into() -> void:
	var small: EnemyData = _type("Small", 1.0, 7)
	ogre.split_into = small
	ogre.split_count = 2
	assert_eq(WaveReport.with_splits(ogre).size(), 3)
	var row: WaveReport.Row = WaveReport.row(schedule, catalog, MATCH_SEED, 1)
	var expected: int = 0
	for type in _plan(1):
		expected += type.max_health + (14 if type == ogre else 0)
	assert_eq(row.total_health, expected)
	assert_eq(row.enemies, _plan(1).size(), "the enemy count is what the wave buys")
