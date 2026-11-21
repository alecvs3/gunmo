extends GutTest

var catalog: ModifierCatalog


func _modifier(
	name: String, health: float, speed: float, taken: float, regen: float
) -> WaveModifier:
	var modifier := WaveModifier.new()
	modifier.display_name = name
	modifier.health_multiplier = health
	modifier.speed_multiplier = speed
	modifier.damage_taken_multiplier = taken
	modifier.regen_per_second = regen
	return modifier


func before_each() -> void:
	catalog = ModifierCatalog.new()
	(
		catalog
		. modifiers
		. assign(
			[
				_modifier("Armored", 1.0, 0.9, 0.6, 0.0),
				_modifier("Fast", 0.8, 1.5, 1.0, 0.0),
				_modifier("Regenerating", 1.0, 1.0, 1.0, 0.05),
			]
		)
	)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _bits(mask: int) -> int:
	var count: int = 0
	for i in 8:
		count += (mask >> i) & 1
	return count


func test_count_by_wave() -> void:
	assert_eq(ModifierCatalog.count_for_wave(5, 6, 16), 0)
	assert_eq(ModifierCatalog.count_for_wave(6, 6, 16), 1)
	assert_eq(ModifierCatalog.count_for_wave(15, 6, 16), 1)
	assert_eq(ModifierCatalog.count_for_wave(16, 6, 16), 2)


func test_pick_gives_distinct_modifiers() -> void:
	for seed_value in 30:
		assert_eq(_bits(catalog.pick(2, _rng(seed_value))), 2)
		assert_eq(_bits(catalog.pick(1, _rng(seed_value))), 1)
	assert_eq(catalog.pick(0, _rng(1)), 0)
	assert_eq(_bits(catalog.pick(9, _rng(1))), 3, "never more than exist")


func test_pick_is_deterministic() -> void:
	assert_eq(catalog.pick(2, _rng(77)), catalog.pick(2, _rng(77)))


func test_combined_multiplies_and_adds() -> void:
	var both: WaveModifier = catalog.combined(0b111)
	assert_almost_eq(both.health_multiplier, 0.8, 1e-6)
	assert_almost_eq(both.speed_multiplier, 1.35, 1e-6)
	assert_almost_eq(both.damage_taken_multiplier, 0.6, 1e-6)
	assert_almost_eq(both.regen_per_second, 0.05, 1e-6)
	var none: WaveModifier = catalog.combined(0)
	assert_eq(
		[none.health_multiplier, none.speed_multiplier, none.regen_per_second], [1.0, 1.0, 0.0]
	)


func test_names() -> void:
	assert_eq(catalog.names(0b011), "Armored · Fast")
	assert_eq(catalog.names(0), "")


func test_default_catalog_and_schedule() -> void:
	var real: ModifierCatalog = ModifierCatalog.load_default()
	assert_eq(real.modifiers.size(), 3)
	assert_lte(real.modifiers.size(), ModifierCatalog.MAX_MODIFIERS)
	var schedule: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	assert_eq([schedule.first_modifier_wave, schedule.double_modifier_wave], [6, 16])
