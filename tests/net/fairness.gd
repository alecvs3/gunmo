extends "res://tests/net/smoke_script.gd"
## Smoke scenario H, fairness under lag (Yusuf's case: 160 ms round trip): a host and a client with
## 80 ms of simulated latency each way play Gun Game against 2 hard bots. Nobody can die (hits still
## count as hits), the host's own player can't be hit and both bots are on one team, so they only go
## for the client. The client alternates walking (changing direction, as if dodging) and standing,
## and records where its own screen had its player at every tick of its own timeline. Every time the
## host says a bot's bullet hit the client, the client checks where that was: on its own player at
## that moment (fair: what it saw is what counted), or somewhere it no longer was (a hit from a
## bullet that missed on its screen). Fails below MIN_FAIR_SHARE. Two ranged test enemies
## (test_spitter) also hunt the client and are judged the same way, on their own count.
## Usage: -s res://tests/net/fairness.gd -- <fairhost|fairclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 90.0
const MATCH_PATH: String = "res://tests/net/data/quick_gun_game.tres"
const PLAY_SECONDS: float = 20.0
const MIN_HITS: int = 5
const MIN_FAIR_SHARE: float = 0.85
const MIN_ENEMY_HITS: int = 3
const SPITTER_PATH: String = "res://tests/net/data/test_spitter.tres"
const CHASER_SCENE_PATH: String = "res://enemies/chaser.tscn"
const SPITTERS: int = 2
## Groups.LIVING_PLAYERS: who enemies hunt.
const LIVING_GROUP: StringName = &"living_players"
## Shot.ENEMY_SHOOTER_BASE: enemy shooter ids are at or below it.
const ENEMY_SHOOTER_BASE: int = -(1 << 20)
## Both bots share this team, so they leave each other alone and go for the client.
const BOT_TEAM: int = -100
## Player hitbox radius + bullet radius + a little slack for blending between ticks (px).
const ON_PLAYER_DISTANCE: float = 33.0
## ProjectileSystem's event topic and kinds.
const TOPIC: int = 1
const EVENT_ENDED: int = 2
const EVENT_HURT: int = 4

## Client: tick of its own timeline -> where its player was.
var _own_positions: Dictionary = {}
var _hurt_pending: int = 0
var _fair: int = 0
var _unfair: int = 0
var _enemy_fair: int = 0
var _enemy_unfair: int = 0


func _initialize() -> void:
	_boot("fairhost", 7799, WATCHDOG_SECONDS)


func _run() -> void:
	if _role == "fairhost":
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
	await create_timer(3.0).timeout
	_spawn_spitters()
	while net.peers.size() >= 2:
		for player: Node in _players():
			player.get_node("HealthComponent").invulnerable = true
		var own: Node = root.get_node_or_null(_level_path() + "/Players/1")
		if own != null:
			own.get_node("HitboxComponent").monitorable = false
		for player: Node in _players():
			if player.get("is_bot"):
				player.set("team_id", BOT_TEAM)
			# Enemies chase the nearest living player: only the client counts as one here.
			if player.get("is_bot") or player.name == "1":
				player.remove_from_group(LIVING_GROUP)
		for enemy: Node in _enemies():
			enemy.get_node("HealthComponent").invulnerable = true
			# On the bots' team, so the bots keep hunting the client instead of the spitters.
			enemy.get_node("HitboxComponent").team = StringName("team_%d" % BOT_TEAM)
		await process_frame
	net.leave()
	await create_timer(0.5).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	net.configure_simulator(80, 0, 0.0)
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null, 15.0)
	net.channel.event_received.connect(_on_event)
	physics_frame.connect(_record_own_position)
	await create_timer(3.0).timeout
	var end_msec: int = Time.get_ticks_msec() + roundi(PLAY_SECONDS * 1000.0)
	var direction: float = 1.0
	while Time.get_ticks_msec() < end_msec:
		direction = -direction
		_walk(Vector2(direction, 0.4 * direction).normalized())
		await create_timer(0.5).timeout
		_walk(Vector2.ZERO)
		await create_timer(0.5).timeout
	_report()
	net.leave()
	await create_timer(0.5).timeout


## The tick the client stamps on its inputs (its view of the host's present) -> where its own
## player is after that tick's prediction.
func _record_own_position() -> void:
	var player: Node2D = _own_player()
	if player == null:
		return
	var tick: int = roundi(root.get_node("NetworkManager").clock.server_tick_now())
	_own_positions[tick] = player.get_node("HitboxComponent").call("center")


func _on_event(topic: int, data: PackedByteArray) -> void:
	if topic != TOPIC or data.is_empty():
		return
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	match buffer.get_u8():
		EVENT_HURT:
			_hurt_pending += 1

		EVENT_ENDED:
			_on_bullet_ended(buffer)


## A bullet that hit us is announced right after the hurt event (same reliable channel).
func _on_bullet_ended(buffer: StreamPeerBuffer) -> void:
	var shooter_id: int = buffer.get_32()
	buffer.get_u32()
	var end_point := Vector2(buffer.get_float(), buffer.get_float())
	var end_tick: float = buffer.get_double()
	var hit_something: bool = buffer.get_u8() == 1
	if _hurt_pending <= 0 or not hit_something or shooter_id >= 0:
		return
	_hurt_pending -= 1
	var tick: int = roundi(end_tick)
	if not _own_positions.has(tick):
		return
	var fair: bool = (_own_positions[tick] as Vector2).distance_to(end_point) <= ON_PLAYER_DISTANCE
	if shooter_id <= ENEMY_SHOOTER_BASE:
		_enemy_fair += 1 if fair else 0
		_enemy_unfair += 0 if fair else 1
	else:
		_fair += 1 if fair else 0
		_unfair += 0 if fair else 1


func _report() -> void:
	var hits: int = _fair + _unfair
	var share: float = _fair / float(hits) if hits > 0 else 0.0
	print("FAIRNESS METRIC bot_hits_on_client %d" % hits)
	print("FAIRNESS METRIC fair_share %.2f" % share)
	_check(hits >= MIN_HITS, "only %d bot hits on the client to judge" % hits)
	_check(share >= MIN_FAIR_SHARE, "only %.0f%% of bot hits were where we were" % (share * 100))
	var enemy_hits: int = _enemy_fair + _enemy_unfair
	var enemy_share: float = _enemy_fair / float(enemy_hits) if enemy_hits > 0 else 0.0
	print("FAIRNESS METRIC enemy_hits_on_client %d" % enemy_hits)
	print("FAIRNESS METRIC enemy_fair_share %.2f" % enemy_share)
	_check(enemy_hits >= MIN_ENEMY_HITS, "only %d enemy hits on the client to judge" % enemy_hits)
	_check(
		enemy_share >= MIN_FAIR_SHARE,
		"only %.0f%% of enemy hits were where we were" % (enemy_share * 100)
	)


func _walk(move: Vector2) -> void:
	var player: Node2D = _own_player()
	if player == null:
		return
	var command: RefCounted = _input_command_script.new()
	command.move = move
	player.get_node("PlayerInputSource").scripted = command


## Host: ranged test enemies at the level's enemy spawn points nearest the client.
func _spawn_spitters() -> void:
	var level: Node = root.get_node(_level_path())
	var client: Node2D = null
	for player: Node in _players():
		if not player.get("is_bot") and player.name != "1":
			client = player
	var points: Array = level.call("enemy_spawn_positions")
	if client != null:
		points.sort_custom(
			func(a: Vector2, b: Vector2) -> bool:
				return (
					a.distance_squared_to(client.global_position)
					< b.distance_squared_to(client.global_position)
				)
		)
	for i in mini(SPITTERS, points.size()):
		var enemy: Node2D = (load(CHASER_SCENE_PATH) as PackedScene).instantiate()
		enemy.set("enemy_data", load(SPITTER_PATH))
		enemy.position = points[i]
		level.call("add_enemy", enemy)


func _enemies() -> Array[Node]:
	var enemies_root: Node = root.get_node_or_null(_level_path() + "/Enemies")
	return enemies_root.get_children() if enemies_root != null else []


func _players() -> Array[Node]:
	var players_root: Node = root.get_node_or_null(_level_path() + "/Players")
	return players_root.get_children() if players_root != null else []
