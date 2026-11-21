extends GutTest

var simulator: NetSimulator


func before_each() -> void:
	simulator = NetSimulator.new()
	simulator.set_seed(1)


func test_inactive_by_default() -> void:
	assert_false(simulator.is_active())


func test_latency_delays_release() -> void:
	simulator.configure(100, 0, 0.0)
	simulator.push(1000, "a", true)
	assert_eq(simulator.pop_ready(1099), [])
	assert_eq(simulator.pop_ready(1100), ["a"])


func test_release_order_follows_time() -> void:
	simulator.configure(0, 0, 0.0)
	simulator.latency_ms = 50
	simulator.push(1000, "late", true)
	simulator.latency_ms = 10
	simulator.push(1000, "early", true)
	assert_eq(simulator.pop_ready(2000), ["early", "late"])


func test_jitter_stays_in_range() -> void:
	simulator.configure(100, 20, 0.0)
	for i in 50:
		simulator.push(0, i, true)
	assert_eq(simulator.pop_ready(79).size(), 0)
	assert_eq(simulator.pop_ready(120).size(), 50)


func test_loss_drops_roughly_the_share_but_never_reliable() -> void:
	simulator.configure(0, 0, 0.5)
	for i in 1000:
		simulator.push(0, i, true)
	var kept: int = simulator.pop_ready(0).size()
	assert_between(kept, 400, 600)
	for i in 100:
		simulator.push(0, i, false)
	assert_eq(simulator.pop_ready(0).size(), 100, "reliable events are delayed, never dropped")
