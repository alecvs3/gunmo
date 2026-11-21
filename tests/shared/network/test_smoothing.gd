extends GutTest
## Latency smoothing: the jitter meter, the client's adaptive delay, the host's view delay
## sampling, the own player's draw-ahead lead and the input report's wire format.


func test_even_arrivals_have_no_jitter() -> void:
	var meter := JitterMeter.new()
	for i in 30:
		meter.observe(i * 0.033, 5.0 + i * 0.033)
	assert_almost_eq(meter.jitter_seconds(), 0.0, 0.0001, "a constant delay is not jitter")


func test_uneven_arrivals_measure_the_spread() -> void:
	var meter := JitterMeter.new()
	for i in 40:
		var late: float = 0.02 if i % 4 == 0 else 0.0
		meter.observe(i * 0.033, 5.0 + i * 0.033 + late)
	assert_almost_eq(meter.jitter_seconds(), 0.02, 0.0001)


func test_jitter_forgets_old_arrivals() -> void:
	var meter := JitterMeter.new()
	meter.window_seconds = 1.0
	meter.observe(0.0, 0.0)
	meter.observe(0.1, 0.5)
	assert_almost_eq(meter.jitter_seconds(), 0.4, 0.0001)
	for i in 20:
		meter.observe(2.0 + i * 0.05, 2.0 + i * 0.05)
	assert_almost_eq(meter.jitter_seconds(), 0.0, 0.0001, "the bad patch is forgotten")


func test_target_delay_covers_interval_and_jitter_within_limits() -> void:
	var settings := NetworkConfig.new()
	settings.jitter_scale = 1.5
	settings.smoothing_margin = 0.01
	settings.min_interpolation_delay = 0.035
	settings.max_interpolation_delay = 0.25
	assert_almost_eq(NetClock.target_delay(0.033, 0.0, 0.0, settings), 0.043, 0.0001)
	assert_almost_eq(NetClock.target_delay(0.033, 0.02, 0.0, settings), 0.073, 0.0001)
	assert_almost_eq(NetClock.target_delay(0.0, 0.0, 0.0, settings), 0.035, 0.0001, "min")
	assert_almost_eq(NetClock.target_delay(0.033, 1.0, 0.0, settings), 0.25, 0.0001, "max")
	assert_almost_eq(NetClock.target_delay(0.033, 0.0, 0.033, settings), 0.076, 0.0001, "boost")


func test_delay_rises_fast_and_falls_slowly_never_past_the_target() -> void:
	assert_almost_eq(NetClock.stepped_delay(0.05, 0.2, 0.1, 0.15, 0.02), 0.065, 0.0001)
	assert_almost_eq(NetClock.stepped_delay(0.1, 0.05, 0.1, 0.15, 0.02), 0.098, 0.0001)
	assert_almost_eq(NetClock.stepped_delay(0.06, 0.061, 1.0, 0.15, 0.02), 0.061, 0.0001)
	assert_almost_eq(NetClock.stepped_delay(0.06, 0.059, 1.0, 0.15, 0.02), 0.059, 0.0001)


func test_display_delay_sample_blends_back_in_time() -> void:
	var history: Array = [Vector2(30, 0), Vector2(20, 0), Vector2(10, 0), Vector2(0, 0)]
	assert_eq(DisplayDelay.sample(history, 0.0), Vector2(30, 0), "newest")
	assert_eq(DisplayDelay.sample(history, 2.0), Vector2(10, 0), "two ticks back")
	assert_eq(DisplayDelay.sample(history, 1.5), Vector2(15, 0), "between ticks")
	assert_eq(DisplayDelay.sample(history, 9.0), Vector2(0, 0), "holds the oldest")
	var aims: Array = [0.4, 0.2, 0.0]
	assert_almost_eq(float(DisplayDelay.sample(aims, 0.5)), 0.3, 0.0001)
	assert_null(DisplayDelay.sample([], 1.0))


func test_draw_ahead_lead_is_last_ticks_motion_capped() -> void:
	assert_eq(OwnPlayerDrawing.lead(Vector2(10, 0), Vector2(13, 4), 10.0), Vector2(3, 4))
	assert_eq(OwnPlayerDrawing.lead(Vector2.ZERO, Vector2(300, 0), 6.0), Vector2(6, 0), "cap")
	assert_eq(OwnPlayerDrawing.lead(Vector2(5, 5), Vector2(5, 5), 6.0), Vector2.ZERO, "still")


func test_peer_input_round_trips_and_rejects_garbage() -> void:
	var input := NetStats.PeerInput.new()
	input.jitter_ms = 3.14159
	input.buffer_ticks = 2
	input.late_per_second = 5
	var back := NetStats.PeerInput.from_array(input.to_array())
	assert_almost_eq(back.jitter_ms, 3.1, 0.0001)
	assert_eq([back.buffer_ticks, back.late_per_second], [2, 5])
	var garbage := NetStats.PeerInput.from_array("not an array")
	assert_eq([garbage.jitter_ms, garbage.buffer_ticks, garbage.late_per_second], [0.0, 0, 0])
	var huge := NetStats.PeerInput.from_array([1e9, 9999, -4])
	assert_eq([huge.buffer_ticks, huge.late_per_second], [255, 0], "clamped")
