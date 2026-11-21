extends "res://tests/net/smoke_script.gd"
## Smoke scenario G: measures the latency chain against shared/network/latency_budget.tres.
##   client  1. clean connection: ticks from an input to its own player moving, and how far
##              behind the host it draws remote objects (the adaptive smoothing delay)
##           2. the same with 80 ms ± 10 ms simulated latency and 2% loss
##   host    how many of the client's inputs it holds back (input buffer), and its own view
##           delay
## Prints "LATENCY METRIC name value" lines; fails when a number is over budget.
## Usage: -s res://tests/net/latency.gd -- <latencyhost|latencyclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 110.0
const SETTLE_SECONDS: float = 5.0
## After switching the simulated lag on (a sudden latency jump looks like jitter for a moment).
const LAGGED_SETTLE_SECONDS: float = 9.0
const MEASURE_SECONDS: float = 6.0
const BUDGET_PATH: String = "res://shared/network/latency_budget.tres"

var _budget: Resource


func _initialize() -> void:
	_boot("latencyhost", 7797, WATCHDOG_SECONDS)
	_metric_label = "LATENCY"


func _run() -> void:
	_budget = load(BUDGET_PATH)
	if _role == "latencyhost":
		await _run_host()
	else:
		await _run_client()
	_finish("")


func _run_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return net.peers.size() >= 2, 20.0)
	_check(net.peers.size() == 2, "client never joined")
	var client_id: int = net.peers[1] if net.peers[0] == 1 else net.peers[0]
	await create_timer(SETTLE_SECONDS).timeout
	var end_msec: int = Time.get_ticks_msec() + roundi(MEASURE_SECONDS * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		var report: RefCounted = net.stats.peer_inputs.get(client_id)
		if report != null:
			_add("buffer", report.buffer_ticks)
		await process_frame
	var buffer_p95: float = _percentile("buffer", 0.95)
	_metric("host_input_buffer_clean_p95_ticks", buffer_p95)
	_metric("host_view_delay_ms", net.clock.smoothing_delay() * 1000.0)
	_check(_samples.has("buffer"), "no input report for the client")
	_check(
		buffer_p95 <= _budget.host_input_buffer_clean_ticks,
		"host held back %.0f ticks of a clean connection's inputs" % buffer_p95
	)
	_check(net.clock.smoothing_delay() * 1000.0 <= _budget.host_view_delay_ms, "host view delay")
	await _wait_until(func() -> bool: return net.peers.size() < 2, 40.0)
	net.leave()
	await create_timer(0.5).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null, 15.0)
	await create_timer(SETTLE_SECONDS).timeout
	await _measure_phase(
		"clean", _budget.remote_smoothing_clean_ms, _budget.ran_dry_clean_per_minute
	)
	net.configure_simulator(80, 10, 0.02)
	await create_timer(LAGGED_SETTLE_SECONDS).timeout
	await _measure_phase(
		"lagged", _budget.remote_smoothing_lagged_ms, _budget.ran_dry_lagged_per_minute
	)
	net.leave()
	await create_timer(0.5).timeout


## Samples the view delay, its smoothing part and what the jitter calls for every frame and an
## input response every second, and counts how often drawing ran out of snapshots.
func _measure_phase(phase: String, buffer_budget_ms: float, dry_budget: float) -> void:
	var clock: Node = root.get_node("NetworkManager").clock
	var end_msec: int = Time.get_ticks_msec() + roundi(MEASURE_SECONDS * 1000.0)
	var dry_before: int = clock.ran_dry_count
	var direction: float = 1.0
	var next_input_msec: int = 0
	while Time.get_ticks_msec() < end_msec:
		_add("%s_delay" % phase, clock.smoothing_delay() * 1000.0)
		_add("%s_buffer" % phase, clock.buffer_delay() * 1000.0)
		_add("%s_needed" % phase, _needed_buffer_ms(clock))
		if Time.get_ticks_msec() >= next_input_msec:
			next_input_msec = Time.get_ticks_msec() + 1000
			direction = -direction
			_add("%s_response" % phase, await _input_response_ticks(direction))
		await process_frame
	var buffer_p95: float = _percentile("%s_buffer" % phase, 0.95)
	var response: float = _percentile("%s_response" % phase, 1.0)
	var dry_per_minute: float = (clock.ran_dry_count - dry_before) * 60.0 / MEASURE_SECONDS
	_metric("%s_remote_view_delay_avg_ms" % phase, _average("%s_delay" % phase))
	_metric("%s_smoothing_avg_ms" % phase, _average("%s_buffer" % phase))
	_metric("%s_smoothing_p95_ms" % phase, buffer_p95)
	_metric("%s_own_input_response_max_ticks" % phase, response)
	_metric("%s_snapshot_jitter_ms" % phase, clock.snapshot_jitter.jitter_seconds() * 1000.0)
	_metric("%s_ran_dry_per_minute" % phase, dry_per_minute)
	var excess: float = _average("%s_buffer" % phase) - _average("%s_needed" % phase)
	_metric("%s_smoothing_excess_ms" % phase, excess)
	_check(
		excess <= _budget.smoothing_excess_ms,
		"%s: buffer %.0f ms more than the jitter needs" % [phase, excess]
	)
	_check(buffer_p95 <= buffer_budget_ms, "%s: smoothing p95 %.0f ms" % [phase, buffer_p95])
	# A 6 s window can't resolve a per-minute budget below 10: one hitch would already be
	# 10/min. So one isolated hitch per phase is allowed, and the budget applies above that.
	var dry_events: int = clock.ran_dry_count - dry_before
	var allowed: float = maxf(dry_budget * MEASURE_SECONDS / 60.0, 1.0)
	_check(dry_events <= allowed, "%s: ran dry %.0f times/min" % [phase, dry_per_minute])
	_check(
		response <= _budget.own_input_response_ticks,
		"%s: own input took %.0f ticks" % [phase, response]
	)


## What the measured jitter calls for right now (NetClock.target_delay, no boost), in ms.
func _needed_buffer_ms(clock: Node) -> float:
	var config: Resource = root.get_node("NetworkManager").config
	var interval: float = config.snapshot_interval_ticks / float(Engine.physics_ticks_per_second)
	var jitter: float = clock.snapshot_jitter.jitter_seconds()
	return clock.get_script().target_delay(interval, jitter, 0.0, config) * 1000.0


## From standing still, starts walking in `direction` and counts physics ticks until our
## player has moved that way.
func _input_response_ticks(direction: float) -> float:
	var player: Node2D = _own_player()
	var input_source: Node = player.get_node("PlayerInputSource")
	input_source.scripted = _input_command_script.new()
	await create_timer(0.3).timeout
	var command: RefCounted = _input_command_script.new()
	command.move = Vector2(direction, 0.0)
	await physics_frame
	var start_x: float = player.position.x
	input_source.scripted = command
	var ticks: int = 0
	while ticks < 30:
		await physics_frame
		ticks += 1
		if (player.position.x - start_x) * direction > 0.0:
			break
	return ticks
