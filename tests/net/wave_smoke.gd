extends "res://tests/net/smoke_script.gd"
## Headless smoke test of the whole wave loop with a host and a client, using a quick 3-wave
## match (tests/net/data/combo_match.tres: wave 1 is a Splitter, wave 2 a Support (walking in,
## so the stand-still players can reach it behind cover), wave 3 a
## 2-phase boss whose death ends the match, so those run over the network too). Both sides:
##   1. ready up (the 20 s lobby must be skipped)       2. shoot through both waves: VICTORY
##   3. host presses "Play again": back to the LOBBY    4. stand still: DEFEAT
## Each side records the phases it sees (the client through replication) and checks them.
## The host also checks a Splitter split, that its children had to die before wave 1 cleared,
## and that the boss reached its second phase and was killed. In the second run the host
## downs the client and revives it (holding revive next to it); the client must see itself go
## down and come back.
## Role botwavehost (its own port, + BOT_PORT_OFFSET): 1 human host who never fires and can't be
## hurt, plus 3 bots, must clear a quick 3-wave schedule. The host downs a bot once; another
## bot must revive it. The bots must have spent credits between waves. The human votes to
## call every wave early once it can: at least one wave must start early (no break before it).
## Usage: -s res://tests/net/wave_smoke.gd -- <wavehost|waveclient|botwavehost> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 110.0
const MATCH_PATH: String = "res://tests/net/data/combo_match.tres"
const BOT_MATCH_PATH: String = "res://tests/net/data/bot_coop_match.tres"
const BOT_PORT_OFFSET: int = 50
## InputCommand.REVIVE.
const REVIVE_BUTTON: int = 4
## Groups.BOSSES.
const BOSS_GROUP: StringName = &"bosses"

var _seen: Array[String] = []
var _state: RefCounted = null
var _end_reason: String = ""
var _saw_last_wave_hud: bool = false
var _saw_results: bool = false
var _wave_one_msec: int = -1
var _splits: int = 0
## Host: the highest boss phase seen, and whether a boss died.
var _boss_phase: int = -1
var _boss_killed: bool = false
## Client: saw its own player downed, then alive again.
var _saw_self_downed: bool = false
var _saw_self_revived: bool = false
var _kills: int = 0
## Host: kills seen when wave 1 ended (a split's children must die too).
var _kills_by_wave_two: int = -1


func _initialize() -> void:
	_boot("wavehost", 7795, WATCHDOG_SECONDS)


func _run() -> void:
	root.get_node("EventBus").match_state_changed.connect(_on_state)
	root.get_node("NetworkManager").session_ended.connect(
		func(reason: String) -> void: _end_reason = reason
	)
	if _role == "botwavehost":
		_port += BOT_PORT_OFFSET
		await _run_bot_coop()
	elif _role == "wavehost":
		await _run_host()
	else:
		await _run_client()
	_finish("")


func _run_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", MATCH_PATH)
	var bus: Node = root.get_node("EventBus")
	bus.enemy_split.connect(func(_e: Node2D, _into: Resource, _count: int) -> void: _splits += 1)
	bus.enemy_killed.connect(_on_enemy_killed)
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return net.peers.size() >= 2, 20.0)
	_check(net.peers.size() == 2, "client never joined")
	var joined_msec: int = Time.get_ticks_msec()
	await _play_until(_phase["VICTORY"], true, 50.0)
	var lobby_seconds: float = (_wave_one_msec - joined_msec) / 1000.0
	_info("wave 1 started %.1f s after both joined (lobby timer is 20 s)" % lobby_seconds)
	_check(lobby_seconds < 8.0, "ready-up did not skip the lobby (%.1f s)" % lobby_seconds)
	_check(_splits >= 1, "the Splitter never split")
	_check(_boss_phase >= 1, "the boss never reached its second phase (%d)" % _boss_phase)
	_check(_boss_killed, "the boss was never killed")
	_check(
		_kills_by_wave_two >= 3,
		"wave 1 cleared after %d kills; the Splitter and its 2 children make 3" % _kills_by_wave_two
	)
	await create_timer(1.0).timeout
	root.get_node("EventBus").match_restart_requested.emit()
	await _wait_until(func() -> bool: return _is_phase("LOBBY"), 5.0)
	await _play_until(_phase["ACTIVE"], false, 10.0)
	await _down_and_revive_client()
	await _play_until(_phase["DEFEAT"], false, 60.0)
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
	_check(_saw_last_wave_hud, "the HUD never showed 'Wave 3 / 3'")
	_check(_saw_self_downed, "never saw our own player downed")
	_check(_saw_self_revived, "never saw our own player revived")
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
		_watch_boss()
		_watch_downed()
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
	if hud != null and hud.get("visible") and hud.get_node("%WaveLabel").text == "Wave 3 / 3":
		_saw_last_wave_hud = true
	var results: Node = root.get_node_or_null("Main/UI/ResultsScreen")
	if results != null and results.get("visible"):
		_saw_results = true


## The phases this side saw, in order, must include the full loop.
func _check_sequence() -> void:
	var expected: Array[String] = [
		"LOBBY",
		"ACTIVE 1",
		"BREAK 1",
		"ACTIVE 2",
		"BREAK 2",
		"ACTIVE 3",
		"VICTORY 3",
		"LOBBY",
		"ACTIVE 1",
		"DEFEAT 1"
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
		if token == "BREAK 1" and _kills_by_wave_two < 0:
			_kills_by_wave_two = _kills
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


func _nearest_enemy(from: Vector2) -> Node2D:
	var enemies: Node = root.get_node_or_null(_level_path() + "/Enemies")
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


func _on_enemy_killed(enemy: Node2D, _killer: int) -> void:
	_kills += 1
	var data: Resource = enemy.get("enemy_data")
	if data != null and data.call("is_boss"):
		_boss_killed = true


## Host: the boss's phase right now (it changes with its health).
func _watch_boss() -> void:
	var boss: Node = get_first_node_in_group(BOSS_GROUP) if _role == "wavehost" else null
	if boss != null:
		_boss_phase = maxi(_boss_phase, boss.call("phase_index"))


## Host: knocks the client down, walks over (a teleport) and holds revive until it is back.
func _down_and_revive_client() -> void:
	var client: Node2D = null
	for player: Node in root.get_node("%s/Players" % _level_path()).get_children():
		if player.name != "1":
			client = player
	_check(client != null, "no client player to revive")
	if client == null:
		return
	client.get_node("HealthComponent").take_damage(100000, 0)
	await _wait_until(func() -> bool: return client.call("is_downed"), 3.0)
	_check(client.call("is_downed"), "the client did not go down at 0 health")
	var own: Node2D = _own_player()
	own.call("respawn", client.global_position + Vector2(30, 0))
	_script(own, 0.0, REVIVE_BUTTON)
	await _wait_until(func() -> bool: return client.get("is_alive"), 6.0)
	_script(own, 0.0, 0)
	_check(client.get("is_alive"), "holding revive next to the client did not revive it")
	_info("client downed and revived by the host")
	await create_timer(1.0).timeout


## Client: our own player's downed state as replication shows it.
func _watch_downed() -> void:
	var own: Node2D = _own_player()
	if _role != "waveclient" or own == null:
		return
	if own.call("is_downed"):
		_saw_self_downed = true
	elif _saw_self_downed and own.get("is_alive"):
		_saw_self_revived = true


## botwavehost: the bots fight, shop and revive while the human only readies up.
func _run_bot_coop() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", BOT_MATCH_PATH)
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return _bots().size() == 3, 10.0)
	_check(_bots().size() == 3, "expected 3 bots, got %d" % _bots().size())
	var downed_one: bool = false
	var revived_by_bot: bool = false
	var victim: Node2D = null
	var early_calls: int = 0
	var last_wave: int = 0
	var last_phase: int = -1
	var time_left: float = 75.0
	while time_left > 0.0 and not _is_phase("VICTORY"):
		var own: Node2D = _own_player()
		if own != null:
			own.get_node("HealthComponent").invulnerable = true
			_script(own, 0.0, 0)
		var mode: Node = _mode()
		if mode != null and (_is_phase("LOBBY") or _is_phase("BREAK")):
			if not mode.get("local_ready"):
				mode.call("set_local_ready", true)
		if mode != null and _state != null and _state.call_open and not mode.get("local_call_vote"):
			mode.call("set_call_vote", true)
		if _state != null and _state.wave > last_wave:
			early_calls += 1 if last_phase == _phase["ACTIVE"] and last_wave > 0 else 0
			last_wave = _state.wave
		if _state != null:
			last_phase = _state.phase
		if not downed_one and _is_phase("ACTIVE") and _bots().size() == 3:
			victim = _bots()[0]
			victim.get_node("HealthComponent").take_damage(100000, 0)
			downed_one = true
		if victim != null and is_instance_valid(victim) and downed_one and not revived_by_bot:
			revived_by_bot = victim.get("is_alive") and _is_phase("ACTIVE")
		await create_timer(0.1).timeout
		time_left -= 0.1
	_check(_is_phase("VICTORY"), "1 human + 3 bots did not clear the quick schedule")
	_check(downed_one, "never downed a bot")
	_check(revived_by_bot, "no bot revived the downed bot during the wave")
	_check(_bots_shopped(), "no bot spent credits in the shop")
	_check(early_calls >= 1, "no wave was called early")
	_info("waves called early: %d" % early_calls)
	_info("bots cleared the schedule, revived a teammate and shopped")
	net.leave()
	await create_timer(0.5).timeout


func _bots() -> Array[Node2D]:
	var found: Array[Node2D] = []
	var players: Node = root.get_node_or_null("%s/Players" % _level_path())
	if players == null:
		return found
	for player: Node in players.get_children():
		if player.get("is_bot"):
			found.append(player)
	return found


func _bots_shopped() -> bool:
	for bot in _bots():
		var loadout: Node = bot.get_node("PlayerLoadout")
		if loadout.get("weapon_index") != 0 or Array(loadout.get("levels")).max() > 0:
			return true
	return false
