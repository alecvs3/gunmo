extends GutTest
## The low-latency setup stays in place: project display/input settings, and network and
## player settings that fit the latency budget (shared/network/latency_budget.tres). The
## measured numbers are checked by smoke scenario G (tests/net/latency.gd).

var budget: LatencyBudget
var config: NetworkConfig


func before_each() -> void:
	budget = LatencyBudget.load_default()
	config = load("res://shared/network/default_network_config.tres")


func test_display_and_input_settings_keep_delay_low() -> void:
	assert_eq(
		ProjectSettings.get_setting("display/window/vsync/vsync_mode"),
		DisplayServer.VSYNC_ADAPTIVE,
		"adaptive V-Sync: no tearing, never waits when a frame is late"
	)
	assert_eq(
		ProjectSettings.get_setting("rendering/rendering_device/vsync/swapchain_image_count"),
		2,
		"the shortest swapchain (least input delay)"
	)
	assert_true(
		ProjectSettings.get_setting("input_devices/buffering/agile_event_flushing"),
		"input is read as late as possible each frame"
	)
	assert_eq(ProjectSettings.get_setting("physics/common/physics_jitter_fix"), 0.0)
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))


func test_network_config_fits_the_budget() -> void:
	var tick_ms: float = 1000.0 / NetClock.tick_rate()
	assert_lte(config.host_view_delay_ticks * tick_ms, budget.host_view_delay_ms)
	assert_lte(config.max_input_buffer_ticks, budget.max_input_buffer_ticks)
	assert_lte(config.min_interpolation_delay * 1000.0, budget.remote_smoothing_clean_ms)
	var interval: float = config.snapshot_interval_ticks / float(NetClock.tick_rate())
	var clean_ms: float = NetClock.target_delay(interval, 0.0, 0.0, config) * 1000.0
	assert_lte(clean_ms, budget.remote_smoothing_clean_ms, "no-jitter buffer fits")


func test_own_player_is_drawn_ahead() -> void:
	var player_data: PlayerData = load("res://player/data/default_player.tres")
	assert_eq(player_data.draw_ahead, budget.own_draw_ahead)
