extends SceneTree
## Headless multiplayer smoke test, started three times by run_smoke.ps1:
##   host       hosts, shoots enemies, checks the bad client was refused, then closes the session
##   client     joins, moves, checks bullets and ping arrive, expects "host closed" at the end
##   badclient  joins with a wrong build id and expects to be refused with a reason
## Each prints "SMOKE PASS <role>" or "SMOKE FAIL <role>: ..." and exits (0 = pass).

const WATCHDOG_SECONDS: float = 60.0
const HOST_FIRE_SECONDS: float = 8.0
const ARENA_PATH: String = "Main/LevelContainer/TestArena"

var _role: String = ""
var _port: int = 7790
var _failures := PackedStringArray()
var _finished: bool = false
var _bullets_seen: int = 0
var _enemies_killed: int = 0
var _refused_peers: int = 0
var _end_reason: String = ""
var _join_fail_reason: String = ""
var _net: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "host"
	_port = args[1].to_int() if args.size() > 1 else _port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_net = root.get_node("NetworkManager")
	_net.session_ended.connect(func(reason: String) -> void: _end_reason = reason)
	_net.join_failed.connect(func(reason: String) -> void: _join_fail_reason = reason)
	match _role:
		"host":
			await _run_host()
		"client":
			await _run_client()
		"badclient":
			await _run_bad_client()
	_finish("")


func _run_host() -> void:
	_check(_net.host(_port) == OK, "host() failed")
	_net.gate.peer_rejected.connect(func(_id: int, _why: String) -> void: _refused_peers += 1)
	root.get_node("EventBus").enemy_killed.connect(
		func(_enemy: Node2D, _killer: int) -> void: _enemies_killed += 1
	)
	await _wait_until(func() -> bool: return _net.peers.size() >= 2, 15.0)
	_check(_net.peers.size() == 2, "client never joined (peers %s)" % [_net.peers])
	await _shoot_for(HOST_FIRE_SECONDS)
	_check(_enemies_killed > 0, "no enemies were killed")
	_check(_refused_peers >= 1, "the bad client was not refused")
	_check(_net.ping.peer_pings.size() == 2, "host ping table %s" % [_net.ping.peer_pings])
	_net.leave()
	await create_timer(1.0).timeout
	_check(_end_reason.contains("closed"), "host end reason '%s'" % _end_reason)


func _run_client() -> void:
	await create_timer(0.5).timeout
	_check(_net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null, 10.0)
	if _own_player() == null:
		_check(false, "never got our player (join fail reason '%s')" % _join_fail_reason)
		return
	_arena().get_node("Projectiles").child_entered_tree.connect(
		func(_node: Node) -> void: _bullets_seen += 1
	)
	await _check_movement()
	await create_timer(5.0).timeout
	_check(_bullets_seen > 0, "no bullets replicated to the client")
	_check(_net.ping.own_ping_ms > 0, "no ping measured")
	_check(_net.ping.peer_pings.size() == 2, "client ping table %s" % [_net.ping.peer_pings])
	await _wait_until(func() -> bool: return not _end_reason.is_empty(), 20.0)
	_check(
		_end_reason.contains("closed"), "expected the host-closed notice, got '%s'" % _end_reason
	)


func _run_bad_client() -> void:
	_net.gate.hello["build"] = "mismatch0000"
	_check(_net.join("127.0.0.1", _port) == OK, "join() failed")
	var settled := func() -> bool: return not _join_fail_reason.is_empty() or _net.is_online()
	await _wait_until(settled, 10.0)
	_check(not _net.is_online(), "the bad client got in")
	_check(
		_join_fail_reason.contains("build"), "unexpected refusal reason '%s'" % _join_fail_reason
	)


func _check_movement() -> void:
	var player: Node2D = _own_player()
	var input: Node = player.get_node("InputSync")
	input.set_process(false)
	var start: Vector2 = player.global_position
	input.move_direction = Vector2.RIGHT
	await create_timer(1.0).timeout
	input.move_direction = Vector2.ZERO
	var moved: float = player.global_position.x - start.x
	_check(moved > 100.0, "host did not move our player (moved %.0f px)" % moved)


func _shoot_for(seconds: float) -> void:
	var input: Node = _own_player().get_node("InputSync")
	input.set_process(false)
	var steps: int = roundi(seconds / 0.2)
	for i in steps:
		var enemies: Array[Node] = _arena().get_node("Enemies").get_children()
		input.fire_held = not enemies.is_empty()
		if not enemies.is_empty():
			input.aim_position = (enemies[0] as Node2D).global_position
		await create_timer(0.2).timeout
	input.fire_held = false


func _wait_until(condition: Callable, timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not condition.call():
		await create_timer(0.1).timeout
		time_left -= 0.1


func _arena() -> Node:
	return root.get_node_or_null(ARENA_PATH)


func _own_player() -> Node2D:
	var arena: Node = _arena()
	if arena == null:
		return null
	return arena.get_node_or_null("Players/%d" % root.multiplayer.get_unique_id()) as Node2D


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
