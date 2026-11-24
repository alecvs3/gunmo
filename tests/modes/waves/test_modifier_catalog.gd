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
	assert_eq(real.modifiers.size(), 5)
	assert_lte(real.modifiers.size(), ModifierCatalog.MAX_MODIFIERS)
	var schedule: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	assert_eq(
		[
			schedule.first_modifier_wave,
			schedule.double_modifier_wave,
			schedule.triple_modifier_wave
		],
		[6, 16, 21]
	)


func test_pick_for_wave_uses_the_schedule_and_its_own_seed() -> void:
	var schedule := WaveSchedule.new()
	schedule.first_modifier_wave = 6
	schedule.double_modifier_wave = 16
	assert_eq(catalog.pick_for_wave(schedule, 5, 5), 0)
	for wave in [6, 16, 25]:
		var count: int = ModifierCatalog.count_for_wave(wave, 6, 16)
		var expected: int = catalog.pick(count, _rng(hash([5, wave, "modifiers"])))
		assert_eq(catalog.pick_for_wave(schedule, 5, wave), expected, "wave %d" % wave)


func test_scaled_health_rounds_and_never_hits_zero() -> void:
	assert_eq(_modifier("x", 1.5, 1.0, 1.0, 0.0).scaled_health(101), 152)
	assert_eq(_modifier("x", 0.1, 1.0, 1.0, 0.0).scaled_health(1), 1)


func test_three_modifiers_from_the_triple_wave() -> void:
	assert_eq(ModifierCatalog.count_for_wave(20, 6, 16, 21), 2)
	assert_eq(ModifierCatalog.count_for_wave(21, 6, 16, 21), 3)
	assert_eq(ModifierCatalog.count_for_wave(25, 6, 16, 21), 3)
	assert_eq(ModifierCatalog.count_for_wave(25, 6, 16), 2, "no triple wave = at most two")


func test_stacking_order_does_not_matter() -> void:
	var a: WaveModifier = _modifier("A", 1.3, 1.1, 0.8, 0.01)
	var b: WaveModifier = _modifier("B", 1.2, 1.2, 0.9, 0.02)
	var c: WaveModifier = _modifier("C", 0.9, 1.05, 1.1, 0.0)
	var forward := ModifierCatalog.new()
	forward.modifiers.assign([a, b, c])
	var backward := ModifierCatalog.new()
	backward.modifiers.assign([c, b, a])
	var one: WaveModifier = forward.combined(0b111)
	var two: WaveModifier = backward.combined(0b111)
	assert_almost_eq(one.health_multiplier, two.health_multiplier, 1e-6)
	assert_almost_eq(one.speed_multiplier, two.speed_multiplier, 1e-6)
	assert_almost_eq(one.damage_taken_multiplier, two.damage_taken_multiplier, 1e-6)
	assert_almost_eq(one.regen_per_second, two.regen_per_second, 1e-6)


func test_caps_hold_however_many_stack() -> void:
	var huge := ModifierCatalog.new()
	(
		huge
		. modifiers
		. assign(
			[
				_modifier("X", 2.0, 1.6, 0.5, 0.06),
				_modifier("Y", 2.0, 1.6, 0.5, 0.06),
				_modifier("Z", 2.0, 1.6, 0.5, 0.06),
			]
		)
	)
	var all: WaveModifier = huge.combined(0b111)
	assert_eq(all.health_multiplier, huge.max_health_multiplier)
	assert_eq(all.speed_multiplier, huge.max_speed_multiplier)
	assert_eq(all.damage_taken_multiplier, huge.min_damage_taken_multiplier)
	assert_eq(all.regen_per_second, huge.max_regen_per_second)


func test_conflicting_modifiers_never_share_a_wave() -> void:
	var real: ModifierCatalog = ModifierCatalog.load_default()
	var fast: int = -1
	var frenzied: int = -1
	for i in real.modifiers.size():
		if real.modifiers[i].display_name == "Fast":
			fast = i
		if real.modifiers[i].display_name == "Frenzied":
			frenzied = i
	assert_true(real.modifiers[frenzied].conflicts(real.modifiers[fast]), "either side counts")
	assert_true(real.modifiers[fast].conflicts(real.modifiers[frenzied]))
	var both: int = (1 << fast) | (1 << frenzied)
	for seed_value in 300:
		var mask: int = real.pick(3, _rng(seed_value))
		assert_ne(mask & both, both, "seed %d picked Fast and Frenzied" % seed_value)
		assert_eq(_bits(mask), 3, "still three from five")


func test_conflicts_can_leave_fewer() -> void:
	var tight := ModifierCatalog.new()
	var a: WaveModifier = _modifier("A", 1.0, 1.0, 1.0, 0.0)
	var b: WaveModifier = _modifier("B", 1.0, 1.0, 1.0, 0.0)
	a.conflicts_with = PackedStringArray(["B"])
	tight.modifiers.assign([a, b])
	assert_eq(_bits(tight.pick(2, _rng(1))), 1)


func test_threat_of_a_wave_s_modifiers() -> void:
	assert_eq(catalog.threat(0), 1.0, "no modifiers")
	var armored: float = (1.0 / 0.6) * (1.0 + catalog.speed_threat * (0.9 - 1.0))
	assert_almost_eq(catalog.threat(0b001), armored, 1e-4)
	assert_almost_eq(catalog.threat(0b100), 1.0 + catalog.regen_threat * 0.05, 1e-4)
	assert_gt(catalog.threat(0b101), catalog.threat(0b001), "more modifiers, more threat")
