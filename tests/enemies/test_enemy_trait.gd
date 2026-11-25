extends GutTest
## Enemy traits: what each damage type does against each trait, and how traits stack.

const K: int = DamageType.Type.KINETIC
const P: int = DamageType.Type.PIERCE
const B: int = DamageType.Type.BLAST
const A: int = DamageType.Type.ARCANE

var armored: EnemyTrait
var swarm: EnemyTrait


func before_each() -> void:
	armored = load("res://enemies/data/traits/armored.tres")
	swarm = load("res://enemies/data/traits/swarm.tres")


func _traits(list: Array) -> Array[EnemyTrait]:
	var typed: Array[EnemyTrait] = []
	typed.assign(list)
	return typed


func test_every_type_against_every_trait() -> void:
	var expected: Dictionary = {
		"Armored": [0.6, 1.3, 0.7, 1.0],
		"Swarm": [1.0, 0.7, 1.5, 1.0],
	}
	for each: EnemyTrait in [armored, swarm]:
		var row: Array = expected[each.display_name]
		for type in DamageType.COUNT:
			assert_almost_eq(
				each.multiplier(type), float(row[type]), 1e-6, each.display_name + " " + str(type)
			)


func test_pierce_beats_armor_and_blast_beats_swarms() -> void:
	assert_gt(armored.multiplier(P), armored.multiplier(K))
	assert_lt(armored.multiplier(B), 1.0, "armor still blunts a blast")
	assert_lt(armored.multiplier(B), armored.multiplier(P))
	assert_gt(swarm.multiplier(B), swarm.multiplier(K))
	assert_lt(swarm.multiplier(P), swarm.multiplier(K))


func test_no_traits_take_every_type_normally() -> void:
	for type in DamageType.COUNT:
		assert_eq(EnemyTrait.product(_traits([]), type), 1.0)


func test_traits_multiply_and_a_repeat_counts_twice() -> void:
	assert_almost_eq(EnemyTrait.product(_traits([armored, armored]), K), 0.36, 1e-6)
	assert_almost_eq(EnemyTrait.product(_traits([armored, swarm]), B), 1.05, 1e-6)
	assert_almost_eq(EnemyTrait.product(_traits([armored, swarm]), P), 0.91, 1e-6)


func test_profile_has_one_entry_per_type() -> void:
	var profile: PackedFloat64Array = EnemyTrait.profile(_traits([armored]))
	assert_eq(profile.size(), DamageType.COUNT)
	assert_almost_eq(profile[P], 1.3, 1e-6)
	assert_almost_eq(profile[A], 1.0, 1e-6)


func test_enemy_data_taken_includes_its_flat_armor() -> void:
	var boss := EnemyData.new()
	boss.damage_taken = 0.8
	boss.traits = _traits([armored])
	assert_almost_eq(boss.taken(K), 0.48, 1e-6)
	assert_almost_eq(boss.taken(P), 1.04, 1e-6)


func test_every_type_has_a_name() -> void:
	assert_eq(DamageType.NAMES.size(), DamageType.COUNT)
	assert_eq(DamageType.name_of(DamageType.Type.PIERCE), "Pierce")
