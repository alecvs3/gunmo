extends GutTest

const TYPES: Array[String] = [
	"grunt", "runner", "brute", "shooter", "tank", "swarmer", "splitter", "support"
]
## Types the waves never buy directly (they come from others).
const SPAWNED_ONLY: Array[String] = ["splitling"]


func _load(type_name: String) -> EnemyData:
	return load("res://enemies/data/%s.tres" % type_name)


func test_every_type_is_complete() -> void:
	for type_name in TYPES + SPAWNED_ONLY:
		var data: EnemyData = _load(type_name)
		assert_false(data.display_name.is_empty(), type_name)
		assert_gt(data.max_health, 0, type_name)
		assert_gt(data.move_speed, 0.0, type_name)
		assert_gt(data.spawn_weight, 0.0, type_name)
		assert_gt(data.bounty, 0, type_name)


func test_types_play_differently() -> void:
	var grunt: EnemyData = _load("grunt")
	var runner: EnemyData = _load("runner")
	var brute: EnemyData = _load("brute")
	assert_gt(runner.move_speed, grunt.move_speed, "runner is faster")
	assert_lt(runner.max_health, grunt.max_health, "runner is fragile")
	assert_gt(brute.max_health, grunt.max_health, "brute is tougher")
	assert_lt(brute.knockback_taken, grunt.knockback_taken, "brute is hard to push")
	var model: DifficultyModel = DifficultyModel.load_default()
	assert_gt(model.solo(brute), model.solo(runner), "brute counts for more")
	assert_eq(grunt.first_wave, 1)
	assert_gt(brute.first_wave, runner.first_wave)
	assert_gt(brute.bounty, runner.bounty, "tougher enemies pay more")
	assert_gt(runner.bounty, grunt.bounty)


func test_roles() -> void:
	var grunt: EnemyData = _load("grunt")
	var shooter: EnemyData = _load("shooter")
	var tank: EnemyData = _load("tank")
	var swarmer: EnemyData = _load("swarmer")
	assert_true(shooter.attack is RangedAttack, "shooter fires")
	assert_true(shooter.movement is KeepDistanceMovement, "shooter keeps its distance")
	assert_lt(tank.move_speed, grunt.move_speed, "tank is slow")
	assert_lt(tank.taken(DamageType.Type.KINETIC), 1.0, "tank is armored")
	assert_gt(tank.taken(DamageType.Type.PIERCE), 1.0, "pierce beats the tank's armor")
	assert_gt(swarmer.taken(DamageType.Type.BLAST), 1.0, "blast beats a swarm")
	assert_lt(tank.knockback_taken, 0.1, "tank barely moves when shot")
	assert_gt(swarmer.group_size, 1, "swarmers come in groups")
	var model: DifficultyModel = DifficultyModel.load_default()
	assert_lt(model.solo(swarmer), model.solo(grunt), "one swarmer counts for little")
	assert_gt(swarmer.move_speed, grunt.move_speed, "swarmers are fast")


func test_every_type_is_in_the_default_schedule() -> void:
	var schedule: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	for type_name in TYPES:
		assert_has(schedule.enemy_types, _load(type_name), type_name)


func test_splitter_and_support() -> void:
	var splitter: EnemyData = _load("splitter")
	assert_eq(splitter.split_into, _load("splitling"))
	assert_eq(splitter.split_count, 2, "dies into two small ones")
	assert_lt(splitter.split_into.max_health, splitter.max_health)
	assert_null(splitter.split_into.split_into, "splitlings don't split again")
	var support: EnemyData = _load("support")
	assert_true(support.attack is HealPulseAttack, "support heals")
	assert_true(support.movement is KeepDistanceMovement, "support hangs back")


func test_received_heal_scales_and_rounds() -> void:
	var data := EnemyData.new()
	assert_eq(data.received_heal(714), 714, "heals fully by default")
	data.heal_received = 0.1
	assert_eq(data.received_heal(714), 71)
	assert_eq(data.received_heal(9), 1, "rounds to the nearest point")
	data.heal_received = 0.0
	assert_eq(data.received_heal(714), 0, "0 = never heals")
