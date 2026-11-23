extends GutTest
## RateLimiter and NetChannel's client limits: normal play passes, a flood is cut off.


func test_a_burst_passes_then_the_rest_is_dropped() -> void:
	var limit := RateLimiter.new(10.0, 5.0)
	var allowed: int = 0
	for i in 20:
		allowed += 1 if limit.allow(2, 0.0) else 0
	assert_eq(allowed, 5, "the burst, nothing more at the same moment")
	assert_eq(limit.dropped, 15)


func test_tokens_refill_over_time() -> void:
	var limit := RateLimiter.new(10.0, 5.0)
	for i in 5:
		limit.allow(2, 0.0)
	assert_false(limit.allow(2, 0.0))
	assert_true(limit.allow(2, 0.1), "one token back after 1/10 s")
	assert_false(limit.allow(2, 0.1))


func test_a_steady_sender_at_the_rate_is_never_dropped() -> void:
	var limit := RateLimiter.new(120.0, 40.0)
	for tick in 600:  # 10 s of one command packet per 60 Hz tick
		limit.allow(2, tick / 60.0)
	assert_eq(limit.dropped, 0)


func test_peers_have_their_own_buckets() -> void:
	var limit := RateLimiter.new(1.0, 2.0)
	limit.allow(2, 0.0)
	limit.allow(2, 0.0)
	assert_false(limit.allow(2, 0.0), "peer 2 used its burst")
	assert_true(limit.allow(3, 0.0), "peer 3 is not affected")


func test_a_peer_that_left_starts_fresh() -> void:
	var limit := RateLimiter.new(1.0, 1.0)
	limit.allow(2, 0.0)
	assert_false(limit.allow(2, 0.0))
	limit.forget(2)
	assert_true(limit.allow(2, 0.0))


func test_time_going_backwards_gives_nothing_extra() -> void:
	var limit := RateLimiter.new(10.0, 1.0)
	limit.allow(2, 5.0)
	assert_false(limit.allow(2, 1.0))


func test_channel_drops_a_command_flood_but_not_normal_play() -> void:
	var channel: NetChannel = autofree(NetChannel.new())
	channel.configure(NetworkManager.DEFAULT_CONFIG)
	var normal: int = 0
	for tick in 120:
		normal += 1 if channel.accepts_commands(2, roundi(tick * 1000.0 / 60.0)) else 0
	assert_eq(normal, 120, "60 packets a second all pass")
	var flood: int = 0
	for i in 1000:
		flood += 1 if channel.accepts_commands(3, 5000) else 0
	assert_lt(flood, 100, "1000 packets at once: only the burst passes")


func test_channel_drops_request_floods_and_oversized_requests() -> void:
	var channel: NetChannel = autofree(NetChannel.new())
	var config: NetworkConfig = NetworkManager.DEFAULT_CONFIG
	channel.configure(config)
	var small := PackedByteArray([1, 2])
	var passed: int = 0
	for i in 200:
		passed += 1 if channel.accepts_request(2, small, 0) else 0
	assert_eq(passed, int(config.request_burst))
	var big := PackedByteArray()
	big.resize(config.max_request_bytes + 1)
	assert_false(channel.accepts_request(4, big, 0), "too big, even with a full bucket")
	assert_true(channel.accepts_request(4, small, 0))
