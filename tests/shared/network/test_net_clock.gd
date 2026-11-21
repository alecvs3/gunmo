extends GutTest


func test_first_observation_snaps() -> void:
	assert_eq(NetClock.corrected(0.0, 500.0, false, 10.0, 0.1), 500.0)


func test_small_error_is_corrected_gradually() -> void:
	var next: float = NetClock.corrected(100.0, 102.0, true, 10.0, 0.1)
	assert_almost_eq(next, 100.2, 0.0001)


func test_big_error_snaps() -> void:
	assert_eq(NetClock.corrected(100.0, 150.0, true, 10.0, 0.1), 150.0)


func test_repeated_observations_converge() -> void:
	var estimate: float = 100.0
	for i in 100:
		estimate = NetClock.corrected(estimate, 105.0, true, 10.0, 0.1)
	assert_almost_eq(estimate, 105.0, 0.01)


func test_tick_helpers_match_project_settings() -> void:
	assert_eq(NetClock.tick_rate(), Engine.physics_ticks_per_second)
	assert_almost_eq(NetClock.tick_delta(), 1.0 / Engine.physics_ticks_per_second, 1e-9)
