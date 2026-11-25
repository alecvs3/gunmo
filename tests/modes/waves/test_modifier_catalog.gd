extends GutTest

const ARMORED_TRAIT: String = "res://enemies/data/traits/armored.tres"

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


func _with_traits(name: String, taken: float, traits: Array) -> WaveModifier:
	var modifier: WaveModifier = _modifier(name, 1.0, 1.0, taken, 0.0)
	modifier.adds_traits.assign(traits)
	return modifier


func test_added_traits_are_all_kept_and_stack() -> void:
	var armored: EnemyTrait = load(ARMORED_TRAIT)
	var swarm: EnemyTrait = load("res://enemies/data/traits/swarm.tres")
	var traited := ModifierCatalog.new()
	traited.min_damage_taken_multiplier = 0.1
	(
		traited
		. modifiers
		. assign(
			[
				_with_traits("Armored", 1.0, [armored]),
				_with_traits("Swarming", 1.0, [swarm]),
				_with_traits("Frenzied", 1.15, []),
			]
		)
	)
	var all: WaveModifier = traited.combined(0b111)
	assert_eq(all.adds_traits.size(), 2)
	assert_almost_eq(all.taken(DamageType.Type.KINETIC), 1.15 * 0.6, 1e-6)
	assert_almost_eq(all.taken(DamageType.Type.BLAST), 1.15 * 0.7 * 1.5, 1e-6)
	assert_almost_eq(all.taken(DamageType.Type.PIERCE), 1.15 * 1.3 * 0.7, 1e-6)
	assert_true(traited.combined(0b100).adds_traits.is_empty())


func test_the_damage_taken_floor_holds_for_every_type() -> void:
	var armored: EnemyTrait = load(ARMORED_TRAIT)
	var doubled := ModifierCatalog.new()
	doubled.min_damage_taken_multiplier = 0.4
	doubled.modifiers.assign([_with_traits("A", 1.0, [armored]), _with_traits("B", 1.0, [armored])])
	var both: WaveModifier = doubled.combined(0b11)
	assert_almost_eq(both.taken(DamageType.Type.KINETIC), 0.4, 1e-6, "0.36 raised to the floor")
	assert_almost_eq(both.taken(DamageType.Type.PIERCE), 1.69 * 0.4 / 0.36, 1e-6, "all types rise")
	assert_almost_eq(both.taken(DamageType.Type.BLAST), 0.49 * 0.4 / 0.36, 1e-6)


func test_floored_taken_leaves_values_above_the_floor_alone() -> void:
	var none: Array[EnemyTrait] = []
	assert_eq(ModifierCatalog.floored_taken(0.6, none, 0.4), 0.6)
	assert_eq(ModifierCatalog.floored_taken(0.3, none, 0.4), 0.4)


func test_default_armored_adds_the_armored_trait_with_the_same_kinetic_armor() -> void:
	var real: ModifierCatalog = ModifierCatalog.load_default()
	var armored: WaveModifier = real.modifiers[0]
	assert_eq(armored.display_name, "Armored")
	assert_eq(armored.damage_taken_multiplier, 1.0, "no flat armor: the trait is the armor")
	assert_eq(armored.adds_traits.size(), 1)
	assert_almost_eq(armored.taken(DamageType.Type.KINETIC), 0.6, 1e-6, "as before for Kinetic")
	assert_gt(armored.taken(DamageType.Type.PIERCE), 1.0, "Pierce beats it now")


func test_enemy_traits_and_wave_traits_stack() -> void:
	var real: ModifierCatalog = ModifierCatalog.load_default()
	var tank: EnemyData = load("res://enemies/data/tank.tres")
	var wave: WaveModifier = real.combined(0b1)
	var kinetic: int = DamageType.Type.KINETIC
	assert_almost_eq(tank.taken(kinetic) * wave.taken(kinetic), 0.36, 1e-6, "a Tank in Armored")
	var health := HealthComponent.new()
	health.max_health = 1000
	add_child_autofree(health)
	health.damage_taken_multiplier = wave.damage_taken_multiplier * tank.damage_taken
	health.type_multipliers = EnemyTrait.profile(tank.traits + wave.adds_traits)
	health.take_damage(100, 1, DamageType.Type.PIERCE)
	assert_eq(health.current_health, 1000 - 169, "Pierce: 1.3 x 1.3")


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
