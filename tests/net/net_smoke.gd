extends SceneTree
## Headless multiplayer smoke test, started several times by run_smoke.ps1. Roles:
##   host       listen host: fires a few shots (for the client to see), checks the wrong-build
##              client was refused and that the client's hits killed enemies, ends
##   dedicated  server with no player: checks it spawned none for itself, then ends
##   client     joins; checks its own movement is instant (prediction), agrees with the host
##              afterwards, its shots are predicted and confirmed as hits (lag compensation),
##              sees the host's bullets; expects the host-closed notice at the end
##   shooter    same as client, without expecting anyone else's bullets
##   observer   joins; checks it sees another player move and that player's bullets
##   badclient  joins with a wrong build id and expects to be refused with a reason
## Usage: -s res://tests/net/net_smoke.gd -- <role> <port> [latency,jitter,loss%]
## Each prints "SMOKE PASS <role>" or "SMOKE FAIL <role>: ..." and exits (0 = pass).
## This script runs before the autoloads exist, so it never names project classes directly
## (that would compile them too early); it loads what it needs once the game is running.

const WATCHDOG_SECONDS: float = 75.0
const HOST_SECONDS: float = 16.0
const ARENA_PATH: String = "Main/LevelContainer/TestArena"

var _role: String = ""
var _port: int = 7790
var _sim: Array = []
var _failures := PackedStringArray()
var _finished: bool = false
var _counts: Dictionary = {"remote_bullets": 0, "predicted": 0, "confirmed": 0, "kills": 0}
var _refused: int = 0
var _end_reason: String = ""
var _join_fail_reason: String = ""
var _net: Node
var _input_command_script: GDScript
var _fire_button: int = 0
var _remote_bullet_mode: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "host"
	_port = args[1].to_int() if args.size() > 1 else _port
	if args.size() > 2:
		_sim = Array(args[2].split(",")).map(func(part: String) -> float: return part.to_float())
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_net = root.get_node("NetworkManager")
	_input_command_script = load("res://shared/network/input_command.gd")
	_fire_button = _input_command_script.get_script_constant_map()["FIRE"]
	var bullet_constants: Dictionary = load("res://weapons/bullet.gd").get_script_constant_map()
	_remote_bullet_mode = bullet_constants["Mode"]["REMOTE"]
	_net.session_ended.connect(func(reason: String) -> void: _end_reason = reason)
	_net.join_failed.connect(func(reason: String) -> void: _join_fail_reason = reason)
	if _sim.size() == 3:
		_net.configure_simulator(int(_sim[0]), int(_sim[1]), _sim[2] / 100.0)
	match _role:
		"host":
			await _run_host(false)
		"dedicated":
			await _run_host(true)
		"client":
			await _run_client(true)
		"shooter":
			await _run_client(false)
		"observer":
			await _run_observer()
		"badclient":
			await _run_bad_client()
	_finish("")


func _run_host(dedicated: bool) -> void:
	_check(_net.host(_port, dedicated) == OK, "host() failed")
	_net.gate.peer_rejected.connect(func(_id: int, _why: String) -> void: _refused += 1)
	root.get_node("EventBus").enemy_killed.connect(
		func(_enemy: Node2D, _killer: int) -> void: _counts["kills"] += 1
	)
	var wanted: int = 3 if dedicated else 2
	await _wait_until(func() -> bool: return _net.peers.size() >= wanted, 20.0)
	_check(_net.peers.size() == wanted, "clients never joined (peers %s)" % [_net.peers])
	await create_timer(3.0).timeout
	_spawn_enemy_near_each_player()
	if dedicated:
		_check(_arena().get_node_or_null("Players/1") == null, "server spawned itself a player")
		await create_timer(HOST_SECONDS).timeout
	else:
		await _fire_straight(_own_player(), 2.0)
		await create_timer(HOST_SECONDS - 2.0).timeout
		_check(_refused >= 1, "the wrong-build client was not refused")
	_check(_counts["kills"] > 0, "no enemies were killed")
	_net.leave()
	await create_timer(1.0).timeout
	_check(_end_reason.contains("closed"), "host end reason '%s'" % _end_reason)


func _run_client(expect_remote_bullets: bool) -> void:
	if not await _join_and_wait():
		return
	await _check_instant_movement()
	await _check_agreement_with_host()
	await _shoot_for(_own_player(), 6.0)
	await create_timer(1.0).timeout
	_check(_counts["predicted"] > 0, "no predicted shots")
	_check(_counts["confirmed"] > 0, "the host confirmed none of our hits")
	if expect_remote_bullets:
		_check(_counts["remote_bullets"] > 0, "never saw the host's bullets")
	await _expect_host_closed()


func _run_observer() -> void:
	if not await _join_and_wait():
		return
	await _wait_until(func() -> bool: return _other_player() != null, 10.0)
	var other: Node2D = _other_player()
	if other == null:
		_check(false, "never saw another player")
		return
	var start: Vector2 = other.position
	var furthest: float = 0.0
	for i in 80:
		await create_timer(0.1).timeout
		furthest = maxf(furthest, other.position.distance_to(start))
	_check(furthest > 50.0, "the other player never moved here (%.0f px)" % furthest)
	_check(_counts["remote_bullets"] > 0, "never saw the other player's bullets")
	await _expect_host_closed()


func _run_bad_client() -> void:
	_net.gate.hello["build"] = "mismatch0000"
	_check(_net.join("127.0.0.1", _port) == OK, "join() failed")
	var settled := func() -> bool: return not _join_fail_reason.is_empty() or _net.is_online()
	await _wait_until(settled, 10.0)
	_check(not _net.is_online(), "the bad client got in")
	_check(
		_join_fail_reason.contains("build"), "unexpected refusal reason '%s'" % _join_fail_reason
	)


## Joins, waits until our player has its first host state, and starts counting bullets.
func _join_and_wait() -> bool:
	await create_timer(0.5).timeout
	_check(_net.join("127.0.0.1", _port) == OK, "join() failed")
	var ready := func() -> bool: return _own_player() != null and _own_player().visible
	await _wait_until(ready, 10.0)
	if not ready.call():
		_check(false, "never got our player (join fail reason '%s')" % _join_fail_reason)
		return false
	_arena().get_node("Projectiles").child_entered_tree.connect(_on_projectile_added)
	_arena().get_node("ProjectileSystem").hit_confirmed.connect(
		func(_key: String, _at: Vector2) -> void: _counts["confirmed"] += 1
	)
	root.get_node("EventBus").shot_predicted.connect(
		func(_shot: RefCounted) -> void: _counts["predicted"] += 1
	)
	return true


## Prediction: our player must respond on the next ticks, not after a round trip.
func _check_instant_movement() -> void:
	var player: Node2D = _own_player()
	await create_timer(0.5).timeout
	var start: Vector2 = player.position
	_script(player, Vector2.RIGHT, 0.0, 0)
	for i in 3:
		await physics_frame
	var moved: float = player.position.x - start.x
	_info("moved %.1f px within 3 ticks of pressing right" % moved)
	_check(moved > 1.0, "no movement within 3 ticks (%.2f px): not predicted" % moved)
	await create_timer(1.0).timeout
	_script(player, Vector2.ZERO, 0.0, 0)


## Reconciliation: once still, our predicted position must match the host's.
func _check_agreement_with_host() -> void:
	await create_timer(1.0).timeout
	var player: Node2D = _own_player()
	var latest: RefCounted = player.get_node("NetEntity").buffer.latest()
	var gap: float = player.position.distance_to(latest.position)
	_info("gap to host after stopping %.2f px" % gap)
	_check(gap < 2.0, "predicted position is %.1f px from the host's" % gap)
	var error: float = _net.stats.prediction_error
	_check(error < 2.0, "last prediction correction was %.1f px" % error)


func _shoot_for(player: Node2D, seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		var target: Node2D = _nearest_enemy(player.global_position)
		if target != null:
			var aim: float = (target.global_position - player.global_position).angle()
			_script(player, Vector2.ZERO, aim, _fire_button)
		else:
			_script(player, Vector2.ZERO, 0.0, 0)
		await create_timer(0.1).timeout
	_script(player, Vector2.ZERO, 0.0, 0)


## Test setup: one enemy close to every player, so shooting doesn't depend on where the
## wandering AI happens to be.
func _spawn_enemy_near_each_player() -> void:
	var enemy_scene: PackedScene = load("res://enemies/test_enemy.tscn")
	for player: Node2D in _arena().get_node("Players").get_children():
		var enemy: Node2D = enemy_scene.instantiate()
		enemy.position = player.position + Vector2(220, 0)
		_arena().get_node("Enemies").add_child(enemy, true)


## Shoots in one fixed direction, at nothing in particular (so it can't steal kills).
func _fire_straight(player: Node2D, seconds: float) -> void:
	_script(player, Vector2.ZERO, PI * 0.5, _fire_button)
	await create_timer(seconds).timeout
	_script(player, Vector2.ZERO, 0.0, 0)


func _expect_host_closed() -> void:
	await _wait_until(func() -> bool: return not _end_reason.is_empty(), 30.0)
	_check(
		_end_reason.contains("closed"), "expected the host-closed notice, got '%s'" % _end_reason
	)


func _script(player: Node2D, move: Vector2, aim: float, buttons: int) -> void:
	var command: RefCounted = _input_command_script.new()
	command.move = move
	command.aim = aim
	command.buttons = buttons
	player.get_node("PlayerInputSource").scripted = command


func _on_projectile_added(node: Node) -> void:
	if node.get("mode") == _remote_bullet_mode:
		_counts["remote_bullets"] += 1


func _nearest_enemy(from: Vector2) -> Node2D:
	var nearest: Node2D = null
	for enemy: Node2D in _arena().get_node("Enemies").get_children():
		if enemy.visible and (nearest == null or _closer(from, enemy, nearest)):
			nearest = enemy
	return nearest


func _closer(from: Vector2, a: Node2D, b: Node2D) -> bool:
	return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position)


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


func _other_player() -> Node2D:
	var arena: Node = _arena()
	if arena == null:
		return null
	for player: Node2D in arena.get_node("Players").get_children():
		if player.name != str(root.multiplayer.get_unique_id()) and player.visible:
			return player
	return null


func _info(text: String) -> void:
	print("SMOKE INFO %s: %s" % [_role, text])


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _finish(extra_failure: String) -> void:
	if _finished:
		return
	_finished = true
	_info("counts %s" % [_counts])
	if not extra_failure.is_empty():
		_failures.append(extra_failure)
	if _failures.is_empty():
		print("SMOKE PASS %s" % _role)
	else:
		print("SMOKE FAIL %s: %s" % [_role, "; ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)
