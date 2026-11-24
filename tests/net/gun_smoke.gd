extends "res://tests/net/smoke_script.gd"
## Headless smoke test of Gun Game with a host, a client and two bots, using the quick match
## (tests/net/data/quick_gun_game.tres: SMG, Rocket Launcher, SMG; 2 kills each, 1 on the
## last, fill to 4).
##   1. both sides see 4 players: the two humans by the names they chose, and 2 bots
##   2. the humans hold fire for a while: the bots must find and kill someone on their own
##   3. then everyone fights until someone finishes the ladder: both sides see VICTORY with
##      the same winner, who is on the last gun; somebody climbed a tier on the way
##      and the results screen names the winner next to a scoreboard of all 4 players;
##      the client saw rockets explode (the host's blasts reach it)
##   4. the host restarts: both sides see the match running again with every tier back at 0
## Role botduel (its own port, + DUEL_PORT_OFFSET): a dedicated server where a Hard bot and a
## Normal bot fight each other with SMGs for DUEL_SECONDS; it prints each bot's kills, shots and
## hit rate ("DUEL METRIC" lines) and fails unless the Hard bot has more kills.
## Usage: -s res://tests/net/gun_smoke.gd -- <gunhost|gunclient|botduel> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 140.0
const MATCH_PATH: String = "res://tests/net/data/quick_gun_game.tres"
const HOST_NAME: String = "SmokeHost"
const CLIENT_NAME: String = "SmokeClient"
## The humans hold fire until a bot has killed someone, at most this long.
const HOLD_FIRE_SECONDS: float = 25.0
const DUEL_MATCH_PATH: String = "res://tests/net/data/bot_duel_match.tres"
const DUEL_PORT_OFFSET: int = 50
const DUEL_SECONDS: float = 45.0
## Bot 1 takes the first profile (Hard), bot 2 the second (Normal).
const HARD_BOT: int = -1
const NORMAL_BOT: int = -2

var _state: RefCounted = null
var _winner_id: int = 0
var _highest_tier: int = 0
var _blasts_seen: int = 0
## Kill feed entries seen ("killer>victim:weapon"), until the match is won.
var _feed: PackedStringArray = []
var _feed_closed: bool = false


func _initialize() -> void:
	_boot("gunhost", 7794, WATCHDOG_SECONDS)


func _run() -> void:
	root.get_node("EventBus").match_state_changed.connect(_on_state)
	root.get_node("EventBus").kill_reported.connect(_on_kill_reported)
	if _role == "botduel":
		_port += DUEL_PORT_OFFSET
		await _run_duel()
	elif _role == "gunhost":
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
	_info("bot kills while the humans held fire: %d" % _bot_kills())
	_check(_bot_kills() > 0, "the bots never killed anyone")
	await _fight_until_winner(95.0)
	_info("winner id %d" % _winner_id)
	await _report_feed()
	await create_timer(0.5).timeout
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
	var projectiles: Node = _own_player().get_parent().get_parent().get_node("Projectiles")
	projectiles.child_entered_tree.connect(_on_projectile_added)
	await _hold_fire(HOLD_FIRE_SECONDS)
	await _fight_until_winner(100.0)
	_info("winner id %d, %d rocket blasts seen" % [_winner_id, _blasts_seen])
	await _report_feed()
	_check(_blasts_seen > 0, "no rocket blast reached the client")
	await _wait_until(func() -> bool: return _is_phase("ACTIVE"), 10.0)
	await _check_restarted()
	await _wait_until(func() -> bool: return not net.is_online(), 15.0)


func _on_projectile_added(node: Node) -> void:
	var script: Script = node.get_script()
	if script != null and script.resource_path == "res://weapons/explosion_flash.gd":
		_blasts_seen += 1


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


## Stands still without firing until a bot has a kill (scores replicate, so the client sees it
## too), at most `seconds`.
func _hold_fire(seconds: float) -> void:
	_script(_own_player(), 0.0, 0)
	await _wait_until(func() -> bool: return _bot_kills() > 0, seconds)


func _bot_kills() -> int:
	var kills: int = 0
	for player in _players():
		if player.get("is_bot"):
			kills += player.call("get_score").kills
	return kills


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
	var players_root: Node = root.get_node_or_null(_level_path() + "/Players")
	if players_root == null:
		return found
	for child: Node in players_root.get_children():
		if not child.is_queued_for_deletion():
			found.append(child as Node2D)
	return found


func _player_by_id(peer_id: int) -> Node:
	return root.get_node_or_null(_level_path() + "/Players/%d" % peer_id)


## botduel: Hard vs Normal, counting kills, shots and hits per bot.
func _run_duel() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", DUEL_MATCH_PATH)
	_check(net.host(_port, true) == OK, "dedicated host() failed")
	await _wait_until(func() -> bool: return _players().size() == 2, 10.0)
	_check(_players().size() == 2, "expected 2 bots")
	var kills: Dictionary = {HARD_BOT: 0, NORMAL_BOT: 0}
	var shots: Dictionary = {HARD_BOT: 0, NORMAL_BOT: 0}
	var hits: Dictionary = {HARD_BOT: 0, NORMAL_BOT: 0}
	var bus: Node = root.get_node("EventBus")
	bus.player_killed.connect(
		func(_victim: Node2D, killer: int) -> void:
			if kills.has(killer):
				kills[killer] += 1
	)
	bus.shot_fired.connect(
		func(shot: RefCounted) -> void:
			if shots.has(shot.get("shooter_id")):
				shots[shot.get("shooter_id")] += 1
	)
	for player in _players():
		player.get_node("HealthComponent").damaged.connect(
			func(_amount: int, source: int) -> void:
				if hits.has(source):
					hits[source] += 1
		)
	await create_timer(DUEL_SECONDS).timeout
	for bot: int in [HARD_BOT, NORMAL_BOT]:
		var label: String = "hard" if bot == HARD_BOT else "normal"
		print("DUEL METRIC %s_kills %d" % [label, kills[bot]])
		print("DUEL METRIC %s_shots %d" % [label, shots[bot]])
		print("DUEL METRIC %s_hit_rate %.3f" % [label, hits[bot] / maxf(shots[bot], 1.0)])
	_check(kills[HARD_BOT] + kills[NORMAL_BOT] >= 3, "the bots barely fought")
	_check(kills[HARD_BOT] > kills[NORMAL_BOT], "the Hard bot did not beat the Normal bot")
	net.leave()
	await create_timer(0.5).timeout


## Every entry (the host stops reporting once someone has won), until _report_feed.
func _on_kill_reported(killer: int, victim: int, weapon: int) -> void:
	if not _feed_closed:
		_feed.append("%d>%d:%d" % [killer, victim, weapon])


## Prints the last entries (run_smoke.ps1 checks both sides printed the same) and stops
## recording, before the host restarts.
func _report_feed() -> void:
	await create_timer(0.5).timeout
	_feed_closed = true
	_info("kill feed tail %s" % ",".join(_feed.slice(-5)))
	_check(_feed.size() > 0, "the kill feed showed nothing")
