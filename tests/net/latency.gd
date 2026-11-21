extends SceneTree
## Smoke scenario G: measures the latency chain against shared/network/latency_budget.tres.
##   client  1. clean connection: ticks from an input to its own player moving, and how far
##              behind the host it draws remote objects (the adaptive smoothing delay)
##           2. the same with 80 ms ± 10 ms simulated latency and 2% loss
##   host    how many of the client's inputs it holds back (input buffer), and its own view
##           delay
## Prints "LATENCY METRIC name value" lines; fails when a number is over budget.
## Usage: -s res://tests/net/latency.gd -- <latencyhost|latencyclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 90.0
const SETTLE_SECONDS: float = 5.0
const MEASURE_SECONDS: float = 6.0
const BUDGET_PATH: String = "res://shared/network/latency_budget.tres"

var _role: String = ""
var _port: int = 7797
var _failures := PackedStringArray()
var _finished: bool = false
var _budget: Resource
var _input_command_script: GDScript
var _samples: Dictionary = {}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "latencyhost"
	_port = args[1].to_int() if args.size() > 1 else _port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_budget = load(BUDGET_PATH)
	_input_command_script = load("res://shared/network/input_command.gd")
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
	await _measure_phase(
		"clean", _budget.remote_smoothing_clean_ms, _budget.ran_dry_clean_per_minute
	)
	net.configure_simulator(80, 10, 0.02)
	await _measure_phase(
		"lagged", _budget.remote_smoothing_lagged_ms, _budget.ran_dry_lagged_per_minute
	)
	net.leave()
	await create_timer(0.5).timeout


## Settles, then samples the view delay and its smoothing part every frame and an input
## response every second, and counts how often drawing ran out of snapshots.
func _measure_phase(phase: String, buffer_budget_ms: float, dry_budget: float) -> void:
	var clock: Node = root.get_node("NetworkManager").clock
	await create_timer(SETTLE_SECONDS).timeout
	var end_msec: int = Time.get_ticks_msec() + roundi(MEASURE_SECONDS * 1000.0)
	var dry_before: int = clock.ran_dry_count
	var direction: float = 1.0
	var next_input_msec: int = 0
	while Time.get_ticks_msec() < end_msec:
		_add("%s_delay" % phase, clock.smoothing_delay() * 1000.0)
		_add("%s_buffer" % phase, clock.buffer_delay() * 1000.0)
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
	_check(buffer_p95 <= buffer_budget_ms, "%s: smoothing p95 %.0f ms" % [phase, buffer_p95])
	_check(dry_per_minute <= dry_budget, "%s: ran dry %.0f times/min" % [phase, dry_per_minute])
	_check(
		response <= _budget.own_input_response_ticks,
		"%s: own input took %.0f ticks" % [phase, response]
	)


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


func _add(name: String, value: float) -> void:
	var values: PackedFloat64Array = _samples.get(name, PackedFloat64Array())
	values.append(value)
	_samples[name] = values


func _average(name: String) -> float:
	var values: PackedFloat64Array = _samples.get(name, PackedFloat64Array())
	var total: float = 0.0
	for value in values:
		total += value
	return total / values.size() if values.size() > 0 else 0.0


func _percentile(name: String, fraction: float) -> float:
	var values: PackedFloat64Array = (_samples.get(name, PackedFloat64Array())).duplicate()
	if values.is_empty():
		return 0.0
	values.sort()
	return values[mini(floori(fraction * values.size()), values.size() - 1)]


func _metric(name: String, value: float) -> void:
	print("LATENCY METRIC %s %.2f" % [name, value])


func _own_player() -> Node2D:
	var path: String = "Main/LevelContainer/TestArena/Players/%d" % root.multiplayer.get_unique_id()
	return root.get_node_or_null(path) as Node2D


func _wait_until(condition: Callable, timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not condition.call():
		await create_timer(0.1).timeout
		time_left -= 0.1


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _finish(extra_failure: String) -> void:
	if _finished:
		return
	_finished = true
	if not extra_failure.is_empty():
		_failures.append(extra_failure)
	if _failures.is_empty():
		print("SMOKE PASS %s" % _role)
	else:
		print("SMOKE FAIL %s: %s" % [_role, "; ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)
