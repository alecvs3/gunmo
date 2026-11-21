extends "res://tests/net/smoke_script.gd"
## Smoke scenario H, fairness under lag (Yusuf's case: 160 ms round trip): a host and a client with
## 80 ms of simulated latency each way play Gun Game against 2 hard bots. Nobody can die (hits still
## count as hits), the host's own player can't be hit and both bots are on one team, so they only go
## for the client. The client alternates walking (changing direction, as if dodging) and standing,
## and records where its own screen had its player at every tick of its own timeline. Every time the
## host says a bot's bullet hit the client, the client checks where that was: on its own player at
## that moment (fair: what it saw is what counted), or somewhere it no longer was (a hit from a
## bullet that missed on its screen). Fails below MIN_FAIR_SHARE.
## Usage: -s res://tests/net/fairness.gd -- <fairhost|fairclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 90.0
const MATCH_PATH: String = "res://tests/net/data/quick_gun_game.tres"
const PLAY_SECONDS: float = 30.0
const MIN_HITS: int = 5
const MIN_FAIR_SHARE: float = 0.85
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
	while net.peers.size() >= 2:
		for player: Node in _players():
			player.get_node("HealthComponent").invulnerable = true
		var own: Node = root.get_node_or_null("Main/LevelContainer/TestArena/Players/1")
		if own != null:
			own.get_node("HitboxComponent").monitorable = false
		for player: Node in _players():
			if player.get("is_bot"):
				player.set("team_id", BOT_TEAM)
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
	var distance: float = (_own_positions[tick] as Vector2).distance_to(end_point)
	if distance <= ON_PLAYER_DISTANCE:
		_fair += 1
	else:
		_unfair += 1


func _report() -> void:
	var hits: int = _fair + _unfair
	var share: float = _fair / float(hits) if hits > 0 else 0.0
	print("FAIRNESS METRIC bot_hits_on_client %d" % hits)
	print("FAIRNESS METRIC fair_share %.2f" % share)
	_check(hits >= MIN_HITS, "only %d bot hits on the client to judge" % hits)
	_check(share >= MIN_FAIR_SHARE, "only %.0f%% of bot hits were where we were" % (share * 100))


func _walk(move: Vector2) -> void:
	var player: Node2D = _own_player()
	if player == null:
		return
	var command: RefCounted = _input_command_script.new()
	command.move = move
	player.get_node("PlayerInputSource").scripted = command


func _players() -> Array[Node]:
	var players_root: Node = root.get_node_or_null("Main/LevelContainer/TestArena/Players")
	return players_root.get_children() if players_root != null else []
