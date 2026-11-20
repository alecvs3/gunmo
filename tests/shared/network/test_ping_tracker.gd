extends GutTest

var config: NetworkConfig


func before_each() -> void:
	config = NetworkConfig.new()
	config.ping_good_ms = 80
	config.ping_ok_ms = 150


func test_quality_thresholds() -> void:
	assert_eq(PingTracker.quality(0, config), PingTracker.Quality.GOOD)
	assert_eq(PingTracker.quality(80, config), PingTracker.Quality.GOOD)
	assert_eq(PingTracker.quality(81, config), PingTracker.Quality.OK)
	assert_eq(PingTracker.quality(150, config), PingTracker.Quality.OK)
	assert_eq(PingTracker.quality(151, config), PingTracker.Quality.BAD)


func test_offline_tracker_reports_nothing() -> void:
	var tracker := PingTracker.new()
	tracker.config = config
	add_child_autofree(tracker)
	watch_signals(tracker)
	tracker._process(config.ping_interval + 0.1)
	assert_signal_not_emitted(tracker, "stats_updated")
	assert_eq(tracker.own_ping_ms, 0)


func test_default_config_resource_is_sane() -> void:
	var cfg: NetworkConfig = load("res://shared/network/default_network_config.tres")
	assert_lt(cfg.ping_good_ms, cfg.ping_ok_ms)
	assert_lt(cfg.peer_timeout_min_ms, cfg.peer_timeout_max_ms)
	assert_gt(cfg.max_players, 1)
