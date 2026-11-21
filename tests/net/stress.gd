extends SceneTree
## Headless stress test and performance budget: a host and a client, plus 6 bots, so 8
## players fire at up to 40 enemies at once (tests/net/data/stress_match.tres). Players can't
## die, so the fight never stops. After a warm-up it samples every frame for MEASURE_SECONDS:
##   host    game-logic time per physics tick (every node's _physics_process, measured between
##           a probe that runs first and one that runs last), enemies alive, shots fired per
##           second, bytes sent per second
##   client  frame time, bytes received per second (= one player's download)
## It prints "STRESS METRIC name value" lines and fails if a budget below is exceeded, or if
## the scene wasn't actually busy (too few enemies or shots to mean anything).
## Usage: -s res://tests/net/stress.gd -- <stresshost|stressclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 100.0
const MATCH_PATH: String = "res://tests/net/data/stress_match.tres"
const BOTS: int = 6
const WARM_UP_SECONDS: float = 6.0
const MEASURE_SECONDS: float = 20.0
## Budgets. A 60 Hz tick has 16.7 ms; the host must leave room for rendering, the physics
## server and the OS. Measured on Alex's PC (M5 foundations): p95 about 4.6 ms; CI runners are
## slower, hence the headroom.
const HOST_TICK_P95_MS: float = 10.0
const CLIENT_DOWNLOAD_AVG_BYTES: float = 60000.0
## The scene must really be this busy for the numbers to count.
const MIN_AVG_ENEMIES: float = 25.0
const MIN_SHOTS_PER_SECOND: float = 20.0


## Calls `on_tick` from _physics_process at a chosen priority (lower runs earlier).
class TickProbe:
	extends Node
	var on_tick: Callable

	func _physics_process(_delta: float) -> void:
		on_tick.call()


var _role: String = ""
var _port: int = 7796
var _failures := PackedStringArray()
var _finished: bool = false
var _fire_button: int = 0
var _input_command_script: GDScript
var _samples: Dictionary = {}
var _measuring: bool = false
var _shots: int = 0
var _tick_start_usec: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "stresshost"
	_port = args[1].to_int() if args.size() > 1 else _port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_input_command_script = load("res://shared/network/input_command.gd")
	_fire_button = _input_command_script.get_script_constant_map()["FIRE"]
	_add_tick_probes()
	if _role == "stresshost":
		root.get_node("EventBus").shot_fired.connect(
			func(_shot: RefCounted) -> void: _shots += 1 if _measuring else 0
		)
		await _run_host()
	else:
		await _run_client()
	_finish("")


func _run_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", MATCH_PATH)
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return net.peers.size() >= 2, 20.0)
	_check(net.peers.size() == 2, "client never joined")
	_add_bots()
	await _fight(WARM_UP_SECONDS, false)
	await _fight(MEASURE_SECONDS, true)
	_report_host()
	net.leave()
	await create_timer(1.0).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null, 15.0)
	await _fight(WARM_UP_SECONDS, false)
	await _fight(MEASURE_SECONDS, true)
	_report_client()
	await _wait_until(func() -> bool: return not net.is_online(), 15.0)


func _add_tick_probes() -> void:
	var first := TickProbe.new()
	first.process_physics_priority = -1000000
	first.on_tick = func() -> void: _tick_start_usec = Time.get_ticks_usec()
	var last := TickProbe.new()
	last.process_physics_priority = 1000000
	last.on_tick = func() -> void:
		if _measuring:
			_add("tick_ms", (Time.get_ticks_usec() - _tick_start_usec) / 1000.0)
	root.add_child(first)
	root.add_child(last)


func _add_bots() -> void:
	var level: Node = _level()
	var profile: Resource = load("res://bots/profiles/hard.tres")
	for number in range(1, BOTS + 1):
		level.call("spawn_bot", -number, "Stress bot %d" % number, profile)


## Every frame: keep players alive and our own player shooting; when `measuring`, sample.
func _fight(seconds: float, measuring: bool) -> void:
	var end_msec: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	_measuring = measuring
	while Time.get_ticks_msec() < end_msec:
		_keep_players_alive()
		_shoot_nearest_enemy()
		if measuring:
			_sample()
		await process_frame
	_measuring = false


func _keep_players_alive() -> void:
	if _role != "stresshost":
		return
	for player: Node in _level().get("players_root").get_children():
		player.get_node("HealthComponent").invulnerable = true


func _sample() -> void:
	var net: Node = root.get_node("NetworkManager")
	if _role == "stresshost":
		_add("enemies", _level().call("enemy_count"))
		_add("sent_bytes_per_sec", net.ping.sent_bytes_per_sec)
	else:
		_add("frame_ms", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_add("received_bytes_per_sec", net.ping.received_bytes_per_sec)


func _report_host() -> void:
	var tick_p95: float = _percentile("tick_ms", 0.95)
	_metric("host_tick_avg_ms", _average("tick_ms"))
	_metric("host_tick_p95_ms", tick_p95)
	_metric("host_tick_max_ms", _percentile("tick_ms", 1.0))
	_metric("enemies_avg", _average("enemies"))
	_metric("shots_per_sec", _shots / MEASURE_SECONDS)
	_metric("host_upload_avg_bytes", _average("sent_bytes_per_sec"))
	_check(_average("tick_ms") > 0.0, "measured no tick time at all")
	_check(_average("enemies") >= MIN_AVG_ENEMIES, "not busy: too few enemies")
	_check(_shots / MEASURE_SECONDS >= MIN_SHOTS_PER_SECOND, "not busy: too few shots")
	_check(
		tick_p95 <= HOST_TICK_P95_MS,
		"host tick p95 %.2f ms > budget %.1f ms" % [tick_p95, HOST_TICK_P95_MS]
	)


func _report_client() -> void:
	var download: float = _average("received_bytes_per_sec")
	_metric("client_frame_avg_ms", _average("frame_ms"))
	_metric("client_frame_p95_ms", _percentile("frame_ms", 0.95))
	_metric("client_download_avg_bytes", download)
	_metric("client_download_p95_bytes", _percentile("received_bytes_per_sec", 0.95))
	_check(download > 0.0, "measured no download at all")
	_check(
		download <= CLIENT_DOWNLOAD_AVG_BYTES,
		"client download %.0f B/s > budget %.0f B/s" % [download, CLIENT_DOWNLOAD_AVG_BYTES]
	)


func _shoot_nearest_enemy() -> void:
	var player: Node2D = _own_player()
	var level: Node = _level()
	if player == null or level == null:
		return
	var nearest: Node2D = null
	for enemy: Node2D in level.get("enemies_root").get_children():
		var closer: bool = (
			nearest == null
			or (
				player.global_position.distance_squared_to(enemy.global_position)
				< player.global_position.distance_squared_to(nearest.global_position)
			)
		)
		if enemy.visible and closer:
			nearest = enemy
	var command: RefCounted = _input_command_script.new()
	if nearest != null:
		command.aim = (nearest.global_position - player.global_position).angle()
		command.buttons = _fire_button
	player.get_node("PlayerInputSource").scripted = command


## Packed arrays are copied when read from a Dictionary, so the array is stored back.
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
	print("STRESS METRIC %s %.2f" % [name, value])


func _level() -> Node:
	return root.get_node_or_null("Main/LevelContainer/TestArena")


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
