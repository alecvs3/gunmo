extends GutTest


func test_protection_lasts_its_seconds() -> void:
	var until: int = SpawnProtection.until_after_spawn(100, 0.5)
	assert_eq(until, 100 + roundi(0.5 * NetClock.tick_rate()))
	assert_true(SpawnProtection.is_on(100, until))
	assert_true(SpawnProtection.is_on(until - 1, until))
	assert_false(SpawnProtection.is_on(until, until))


func test_firing_ends_it_at_once() -> void:
	var until: int = SpawnProtection.until_after_spawn(100, 2.0)
	var after_shot: int = SpawnProtection.until_after_shot(until, 110)
	assert_false(SpawnProtection.is_on(110, after_shot), "fired on tick 110: no longer protected")
	assert_eq(SpawnProtection.until_after_shot(105, 200), 105, "a shot never extends it")
