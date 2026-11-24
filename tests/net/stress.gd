extends "res://tests/net/smoke_script.gd"
## Headless stress test and performance budget: a host and a client, plus 6 bots, so 8
## players, each with a tier-5 pet, fire at up to 40 enemies at once
## (tests/net/data/stress_match.tres). Players can't die, so the fight never stops. After a
## warm-up it samples every frame for MEASURE_SECONDS:
##   host    game-logic time per physics tick (every node's _physics_process, measured between
##           a probe that runs first and one that runs last), enemies alive, shots fired per
##           second, bytes sent per second
##   client  frame time, bytes received per second (= one player's download)
## It prints "STRESS METRIC name value" lines and fails if a budget below is exceeded, or if
## the scene wasn't actually busy (too few enemies or shots to mean anything).
## Usage: -s res://tests/net/stress.gd -- <stresshost|stressclient> <port> [measure seconds]
## With a measure time of SOAK_MIN_SECONDS or more it is also a soak test (scenario S): memory,
## objects and nodes are sampled once a second and must not keep growing.
## It runs before the autoloads exist, so it names no project classes directly.

## On top of the measure time: joining, warm-up and shutting down.
const WATCHDOG_EXTRA_SECONDS: float = 90.0
const MATCH_PATH: String = "res://tests/net/data/stress_match.tres"
const BOTS: int = 6
const PET_TIERS: int = 5
const WARM_UP_SECONDS: float = 6.0
const MEASURE_SECONDS: float = 12.0
## Budgets. A 60 Hz tick has 16.7 ms; the host must leave room for rendering, the physics
## server and the OS. Measured on Alex's PC (M5 foundations): p95 about 4.6 ms; CI runners are
## slower, hence the headroom.
const HOST_TICK_P95_MS: float = 10.0
const CLIENT_DOWNLOAD_AVG_BYTES: float = 60000.0
## The scene must really be this busy for the numbers to count.
const MIN_AVG_ENEMIES: float = 25.0
const MIN_SHOTS_PER_SECOND: float = 15.0
## Soak: measured this long or longer, the last quarter's average may be at most this much
## above the first quarter's (enemies and bullets come and go, so counts wobble a little).
const SOAK_MIN_SECONDS: float = 60.0
const SOAK_MAX_GROWTH: float = 0.15
const SOAK_SAMPLES: PackedStringArray = ["nodes", "objects", "memory_mb"]


## Calls `on_tick` from _physics_process at a chosen priority (lower runs earlier).
class TickProbe:
	extends Node
	var on_tick: Callable

	func _physics_process(_delta: float) -> void:
		on_tick.call()


var _measuring: bool = false
var _shots: int = 0
var _tick_start_usec: int = 0
var _measure_seconds: float = MEASURE_SECONDS
var _next_soak_sample_msec: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 2 and args[2].to_float() > 0.0:
		_measure_seconds = args[2].to_float()
	_boot("stresshost", 7796, _measure_seconds + WATCHDOG_EXTRA_SECONDS)
	_metric_label = "STRESS"


func _run() -> void:
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
	_give_pets()
	await _fight(WARM_UP_SECONDS, false)
	await _fight(_measure_seconds, true)
	_report_host()
	net.leave()
	await create_timer(1.0).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null, 15.0)
	await _fight(WARM_UP_SECONDS, false)
	await _fight(_measure_seconds, true)
	_report_client()
	_report_soak()
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


## Every player gets a tier-5 pet (Healer, Wizard, Soldier in turn), so the pets' per-tick
## work and their effect events are part of the budget.
func _give_pets() -> void:
	var players: Array[Node] = _level().get_node("Players").get_children()
	for i in players.size():
		for tier in PET_TIERS:
			players[i].get_node("PlayerLoadout").call("buy_pet_tier", i % 3)


## Every frame: keep players alive and our own player shooting; when `measuring`, sample.
func _fight(seconds: float, measuring: bool) -> void:
	var end_msec: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	_measuring = measuring
	while Time.get_ticks_msec() < end_msec:
		_keep_players_alive()
		_shoot_nearest_enemy()
		if measuring:
			_sample()
			_sample_soak()
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


## Once a second: what would grow if something leaked.
func _sample_soak() -> void:
	if Time.get_ticks_msec() < _next_soak_sample_msec:
		return
	_next_soak_sample_msec = Time.get_ticks_msec() + 1000
	_add("nodes", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_add("objects", Performance.get_monitor(Performance.OBJECT_COUNT))
	_add("memory_mb", Performance.get_monitor(Performance.MEMORY_STATIC) / 1000000.0)


## Soak only: each count's last quarter against its first quarter.
func _report_soak() -> void:
	if _measure_seconds < SOAK_MIN_SECONDS:
		return
	for name in SOAK_SAMPLES:
		var values: PackedFloat64Array = _samples.get(name, PackedFloat64Array())
		var quarter: int = maxi(values.size() / 4, 1)
		var first: float = _mean(values.slice(0, quarter))
		var last: float = _mean(values.slice(values.size() - quarter))
		var growth: float = last / first - 1.0 if first > 0.0 else 0.0
		_metric("soak_%s_first" % name, first)
		_metric("soak_%s_last" % name, last)
		_check(
			growth <= SOAK_MAX_GROWTH,
			"%s grew %.0f%% during the soak (leak?)" % [name, growth * 100.0]
		)


static func _mean(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value in values:
		total += value
	return total / values.size() if values.size() > 0 else 0.0


func _report_host() -> void:
	_report_soak()
	var tick_p95: float = _percentile("tick_ms", 0.95)
	_metric("host_tick_avg_ms", _average("tick_ms"))
	_metric("host_tick_p95_ms", tick_p95)
	_metric("host_tick_max_ms", _percentile("tick_ms", 1.0))
	_metric("enemies_avg", _average("enemies"))
	_metric("shots_per_sec", _shots / _measure_seconds)
	_metric("host_upload_avg_bytes", _average("sent_bytes_per_sec"))
	_check(_average("tick_ms") > 0.0, "measured no tick time at all")
	_check(_average("enemies") >= MIN_AVG_ENEMIES, "not busy: too few enemies")
	_check(_shots / _measure_seconds >= MIN_SHOTS_PER_SECOND, "not busy: too few shots")
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


func _level() -> Node:
	return root.get_node_or_null(_level_path())
