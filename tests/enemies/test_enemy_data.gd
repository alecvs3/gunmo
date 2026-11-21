extends GutTest

const TYPES: Array[String] = ["grunt", "runner", "brute"]


func _load(type_name: String) -> EnemyData:
	return load("res://enemies/data/%s.tres" % type_name)


func test_every_type_is_complete() -> void:
	for type_name in TYPES:
		var data: EnemyData = _load(type_name)
		assert_false(data.display_name.is_empty(), type_name)
		assert_gt(data.max_health, 0, type_name)
		assert_gt(data.move_speed, 0.0, type_name)
		assert_gt(data.cost, 0.0, type_name)
		assert_gt(data.spawn_weight, 0.0, type_name)


func test_types_play_differently() -> void:
	var grunt: EnemyData = _load("grunt")
	var runner: EnemyData = _load("runner")
	var brute: EnemyData = _load("brute")
	assert_gt(runner.move_speed, grunt.move_speed, "runner is faster")
	assert_lt(runner.max_health, grunt.max_health, "runner is fragile")
	assert_gt(brute.max_health, grunt.max_health, "brute is tougher")
	assert_lt(brute.knockback_taken, grunt.knockback_taken, "brute is hard to push")
	assert_gt(brute.cost, runner.cost)
	assert_eq(grunt.first_wave, 1)
	assert_gt(brute.first_wave, runner.first_wave)
