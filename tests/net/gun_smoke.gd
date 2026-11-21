extends SceneTree
## Headless smoke test of Gun Game with a host, a client and two bots, using the quick match
## (tests/net/data/quick_gun_game.tres: 3 guns, 2 kills each, 1 on the last, fill to 4).
##   1. both sides see 4 players: the two humans by the names they chose, and 2 bots
##   2. the humans hold fire for a while: the bots must find and kill someone on their own
##   3. then everyone fights until someone finishes the ladder: both sides see VICTORY with
##      the same winner, who is on the last gun; somebody climbed a tier on the way
##      and the results screen names the winner next to a scoreboard of all 4 players
##   4. the host restarts: both sides see the match running again with every tier back at 0
## Usage: -s res://tests/net/gun_smoke.gd -- <gunhost|gunclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 115.0
const MATCH_PATH: String = "res://tests/net/data/quick_gun_game.tres"
const HOST_NAME: String = "SmokeHost"
const CLIENT_NAME: String = "SmokeClient"
const HOLD_FIRE_SECONDS: float = 12.0

var _role: String = ""
var _port: int = 7794
var _failures := PackedStringArray()
var _finished: bool = false
var _phase: Dictionary = {}
var _fire_button: int = 0
var _input_command_script: GDScript
var _state: RefCounted = null
var _winner_id: int = 0
var _highest_tier: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "gunhost"
	_port = args[1].to_int() if args.size() > 1 else _port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_phase = load("res://modes/game_mode.gd").get_script_constant_map()["Phase"]
	_input_command_script = load("res://shared/network/input_command.gd")
	_fire_button = _input_command_script.get_script_constant_map()["FIRE"]
	root.get_node("EventBus").match_state_changed.connect(_on_state)
	if _role == "gunhost":
		await _run_host()
	else:
		await _run_client()
	_finish("")


func _run_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", MATCH_PATH)
	net.set_local_name(HOST_NAME)
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return net.peers.size() >= 2, 20.0)
	_check(net.peers.size() == 2, "client never joined")
	await _wait_until(func() -> bool: return _players().size() == 4, 5.0)
	_check_roster(CLIENT_NAME)
	await _hold_fire(HOLD_FIRE_SECONDS)
	var bot_kills: int = 0
	for player in _players():
		if player.get("is_bot"):
			bot_kills += player.call("get_score").kills
	_info("bot kills while the humans held fire: %d" % bot_kills)
	_check(bot_kills > 0, "the bots never killed anyone")
	await _fight_until_winner(70.0)
	_info("winner id %d" % _winner_id)
	await create_timer(1.0).timeout
	root.get_node("EventBus").match_restart_requested.emit()
	await _wait_until(func() -> bool: return _is_phase("ACTIVE"), 5.0)
	await _check_restarted()
	await create_timer(3.0).timeout
	net.leave()
	await create_timer(1.0).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	net.set_local_name(CLIENT_NAME)
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null and _players().size() == 4, 15.0)
	_check_roster(HOST_NAME)
	await _hold_fire(HOLD_FIRE_SECONDS - 1.0)
	await _fight_until_winner(75.0)
	_info("winner id %d" % _winner_id)
	await _wait_until(func() -> bool: return _is_phase("ACTIVE"), 10.0)
	await _check_restarted()
	await _wait_until(func() -> bool: return not net.is_online(), 15.0)


## 4 players: us, the other human by name, and 2 bots with bot names.
func _check_roster(other_name: String) -> void:
	var names: Array[String] = []
	var bots: int = 0
	for player in _players():
		names.append(player.get("display_name"))
		bots += 1 if player.get("is_bot") else 0
	_info("players: %s" % [names])
	_check(_players().size() == 4, "expected 4 players, saw %d" % _players().size())
	_check(bots == 2, "expected 2 bots, saw %d" % bots)
	_check(other_name in names, "never saw the other human's name " + other_name)
	for player in _players():
		if player.get("is_bot"):
			_check(str(player.get("display_name")).begins_with("Bot"), "bot without a bot name")


func _hold_fire(seconds: float) -> void:
	_script(_own_player(), 0.0, 0)
	await create_timer(seconds).timeout


## Shoots at the nearest living opponent until the match has a winner.
func _fight_until_winner(timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not _is_phase("VICTORY"):
		_shoot_nearest()
		_note_tiers()
		await create_timer(0.1).timeout
		time_left -= 0.1
	_script(_own_player(), 0.0, 0)
	await create_timer(0.5).timeout
	_check(_is_phase("VICTORY"), "nobody finished the ladder")
	_check(_highest_tier > 0, "nobody ever climbed a tier")
	if not _is_phase("VICTORY"):
		return
	_winner_id = _state.winner_id
	var winner: Node = _player_by_id(_winner_id)
	_check(winner != null, "the winner %d is not a player here" % _winner_id)
	if winner == null:
		return
	var tier: int = winner.call("get_score").tier
	_info("winner %s on tier %d" % [winner.get("display_name"), tier])
	_check(tier == _state.ladder_length - 1, "the winner is not on the last gun")
	await _check_results_ui(str(winner.get("display_name")))


## The results screen names the winner; the scoreboard lists a header and 4 players.
func _check_results_ui(winner_name: String) -> void:
	await create_timer(0.5).timeout
	var results: Node = root.get_node("Main/UI/ResultsScreen")
	var title: String = results.get_node("%Title").text
	_info("results title '%s'" % title)
	_check(results.get("visible"), "the results screen did not show")
	_check(title.ends_with("wins!") or title == "You win!", "results title: " + title)
	_check(title == "You win!" or title.begins_with(winner_name), "results name the wrong winner")
	var board: Node = root.get_node("Main/UI/Scoreboard")
	_check(board.get("visible"), "the scoreboard did not show at the end")
	var grid: Node = board.get_node("%Grid")
	_check(grid.get_child_count() == 5 * 4, "scoreboard cells: %d" % grid.get_child_count())


func _check_restarted() -> void:
	_check(_is_phase("ACTIVE") and _state.winner_id == 0, "restart did not reopen the match")
	await create_timer(1.0).timeout
	for player in _players():
		_check(player.call("get_score").tier == 0, "a tier was not reset by the restart")


func _shoot_nearest() -> void:
	var own: Node2D = _own_player()
	if own == null:
		return
	var nearest: Node2D = null
	for player in _players():
		if player == own or not player.get("is_alive"):
			continue
		var closer: bool = (
			nearest == null
			or (
				own.global_position.distance_squared_to(player.global_position)
				< own.global_position.distance_squared_to(nearest.global_position)
			)
		)
		if closer:
			nearest = player
	if nearest == null:
		_script(own, 0.0, 0)
		return
	_script(own, (nearest.global_position - own.global_position).angle(), _fire_button)


func _note_tiers() -> void:
	for player in _players():
		_highest_tier = maxi(_highest_tier, player.call("get_score").tier)


func _on_state(state: RefCounted) -> void:
	_state = state


func _is_phase(name: String) -> bool:
	return _state != null and _state.phase == _phase[name]


func _players() -> Array[Node2D]:
	var found: Array[Node2D] = []
	var players_root: Node = root.get_node_or_null("Main/LevelContainer/TestArena/Players")
	if players_root == null:
		return found
	for child: Node in players_root.get_children():
		if not child.is_queued_for_deletion():
			found.append(child as Node2D)
	return found


func _player_by_id(peer_id: int) -> Node:
	return root.get_node_or_null("Main/LevelContainer/TestArena/Players/%d" % peer_id)


func _own_player() -> Node2D:
	return _player_by_id(root.multiplayer.get_unique_id()) as Node2D


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
