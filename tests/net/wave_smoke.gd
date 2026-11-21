extends SceneTree
## Headless smoke test of the whole wave loop with a host and a client, using the quick
## 2-wave match (tests/net/data/quick_match.tres). Both sides:
##   1. ready up (the 20 s lobby must be skipped)       2. shoot through both waves: VICTORY
##   3. host presses "Play again": back to the LOBBY    4. stand still: DEFEAT
## Each side records the phases it sees (the client through replication) and checks them.
## Usage: -s res://tests/net/wave_smoke.gd -- <wavehost|waveclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 110.0
const MATCH_PATH: String = "res://tests/net/data/quick_match.tres"

var _role: String = ""
var _port: int = 7795
var _failures := PackedStringArray()
var _finished: bool = false
var _phase: Dictionary = {}
var _fire_button: int = 0
var _input_command_script: GDScript
var _seen: Array[String] = []
var _state: RefCounted = null
var _end_reason: String = ""
var _saw_wave_two_hud: bool = false
var _saw_results: bool = false
var _wave_one_msec: int = -1


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "wavehost"
	_port = args[1].to_int() if args.size() > 1 else _port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_phase = load("res://modes/game_mode.gd").get_script_constant_map()["Phase"]
	_input_command_script = load("res://shared/network/input_command.gd")
	_fire_button = _input_command_script.get_script_constant_map()["FIRE"]
	root.get_node("EventBus").match_state_changed.connect(_on_state)
	root.get_node("NetworkManager").session_ended.connect(
		func(reason: String) -> void: _end_reason = reason
	)
	if _role == "wavehost":
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
	var joined_msec: int = Time.get_ticks_msec()
	await _play_until(_phase["VICTORY"], true, 50.0)
	var lobby_seconds: float = (_wave_one_msec - joined_msec) / 1000.0
	_info("wave 1 started %.1f s after both joined (lobby timer is 20 s)" % lobby_seconds)
	_check(lobby_seconds < 8.0, "ready-up did not skip the lobby (%.1f s)" % lobby_seconds)
	await create_timer(1.0).timeout
	root.get_node("EventBus").match_restart_requested.emit()
	await _wait_until(func() -> bool: return _is_phase("LOBBY"), 5.0)
	await _play_until(_phase["DEFEAT"], false, 40.0)
	_check_sequence()
	await create_timer(1.0).timeout
	net.leave()
	await create_timer(1.0).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null and _state != null, 15.0)
	await _play_until(_phase["VICTORY"], true, 55.0)
	await _wait_until(func() -> bool: return _is_phase("LOBBY"), 10.0)
	await _play_until(_phase["DEFEAT"], false, 45.0)
	_check_sequence()
	_check(_saw_wave_two_hud, "the HUD never showed 'Wave 2 / 2'")
	_check(_saw_results, "the results screen never appeared")
	await _wait_until(func() -> bool: return not _end_reason.is_empty(), 15.0)
	_check(
		_end_reason.contains("closed"), "expected the host-closed notice, got '%s'" % _end_reason
	)


## Readies up in every lobby/break and, if `shooting`, fires at the nearest enemy during waves,
## until the match reaches `target_phase`.
func _play_until(target_phase: int, shooting: bool, timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not (_state != null and _state.phase == target_phase):
		_drive(shooting)
		_watch_ui()
		await create_timer(0.1).timeout
		time_left -= 0.1
	_script(_own_player(), 0.0, 0)
	await process_frame
	_watch_ui()
	_check(_state != null and _state.phase == target_phase, "never reached phase %d" % target_phase)


func _drive(shooting: bool) -> void:
	var player: Node2D = _own_player()
	var mode: Node = _mode()
	if player == null or mode == null or _state == null:
		return
	var waiting: bool = _is_phase("LOBBY") or _is_phase("BREAK")
	if waiting and not mode.get("local_ready"):
		mode.call("set_local_ready", true)
	var target: Node2D = _nearest_enemy(player.global_position)
	if shooting and _is_phase("ACTIVE") and target != null:
		_script(player, (target.global_position - player.global_position).angle(), _fire_button)
	else:
		_script(player, 0.0, 0)


func _watch_ui() -> void:
	var hud: Node = root.get_node_or_null("Main/UI/Hud")
	if hud != null and hud.get("visible") and hud.get_node("%WaveLabel").text == "Wave 2 / 2":
		_saw_wave_two_hud = true
	var results: Node = root.get_node_or_null("Main/UI/ResultsScreen")
	if results != null and results.get("visible"):
		_saw_results = true


## The phases this side saw, in order, must include the full loop.
func _check_sequence() -> void:
	var expected: Array[String] = [
		"LOBBY", "ACTIVE 1", "BREAK 1", "ACTIVE 2", "VICTORY 2", "LOBBY", "ACTIVE 1", "DEFEAT 1"
	]
	var position: int = 0
	for token in _seen:
		if position < expected.size() and token == expected[position]:
			position += 1
	_info("phases seen %s" % [_seen])
	_check(
		position == expected.size(),
		"missing '%s' in the phase sequence" % [expected[mini(position, expected.size() - 1)]]
	)


func _on_state(state: RefCounted) -> void:
	_state = state
	var name: String = _phase.find_key(state.phase)
	var token: String = name if name == "LOBBY" else "%s %d" % [name, state.wave]
	if _seen.is_empty() or _seen.back() != token:
		_seen.append(token)
		if token == "ACTIVE 1" and _wave_one_msec < 0:
			_wave_one_msec = Time.get_ticks_msec()
		_info(
			(
				"%.1f s: %s (%d/%d ready, %d alive)"
				% [
					Time.get_ticks_msec() / 1000.0,
					token,
					state.ready_count,
					state.player_count,
					state.living_count
				]
			)
		)


func _is_phase(name: String) -> bool:
	return _state != null and _state.phase == _phase[name]


func _mode() -> Node:
	var container: Node = root.get_node_or_null("Main/ModeContainer")
	return container.get_child(0) if container != null and container.get_child_count() > 0 else null


func _own_player() -> Node2D:
	var path: String = "Main/LevelContainer/TestArena/Players/%d" % root.multiplayer.get_unique_id()
	return root.get_node_or_null(path) as Node2D


func _nearest_enemy(from: Vector2) -> Node2D:
	var enemies: Node = root.get_node_or_null("Main/LevelContainer/TestArena/Enemies")
	var nearest: Node2D = null
	if enemies == null:
		return null
	for enemy: Node2D in enemies.get_children():
		var closer: bool = (
			nearest == null
			or (
				from.distance_squared_to(enemy.global_position)
				< from.distance_squared_to(nearest.global_position)
			)
		)
		if enemy.visible and closer:
			nearest = enemy
	return nearest


func _script(player: Node2D, aim: float, buttons: int) -> void:
	if player == null:
		return
	var command: RefCounted = _input_command_script.new()
	command.aim = aim
	command.buttons = buttons
	player.get_node("PlayerInputSource").scripted = command


func _wait_until(condition: Callable, timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not condition.call():
		await create_timer(0.1).timeout
		time_left -= 0.1


func _info(text: String) -> void:
	print("SMOKE INFO %s: %s" % [_role, text])


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
