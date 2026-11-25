extends "res://tests/net/smoke_script.gd"
## Smoke scenario H, fairness under lag (Yusuf's case: 160 ms round trip): a host and a client with
## simulated latency (the role's "latency,jitter,loss%" argument, 80 ms each way by default) play
## Gun Game against 2 hard bots. Nobody can die: the two humans can't be hurt (hits still count as
## hits), and every hit on a bot deals 1 damage and the host tops them up. The host's own player
## can't be hit and both bots are on one team, so they only go for the client. The client
## alternates walking (changing direction, as if dodging) and standing while it shoots at the
## nearest bot, and records where its own screen had its player at every tick of its own
## timeline. Every time the host says a bot's bullet hit the client, the client checks where that
## was: on its own player at that moment (fair: what it saw is what counted), or somewhere it no
## longer was (a hit from a bullet that missed on its screen). Fails below MIN_FAIR_SHARE. Two
## ranged test enemies (test_spitter) also hunt the client and are judged the same way, on their
## own count. It also checks that the client's own hits on bots show within about a frame
## (hit_feedback_ms, tests/net/hit_feedback_meter.gd) and that the host confirms nearly all of
## them.
## Usage: -s res://tests/net/fairness.gd -- <fairhost|fairclient> <port> [latency,jitter,loss%]
## It runs before the autoloads exist, so it names no project classes directly.
## tests/net/waves_fairness.gd (scenario I) extends this file.

const HitFeedbackMeter = preload("res://tests/net/hit_feedback_meter.gd")

const WATCHDOG_SECONDS: float = 90.0
const MATCH_PATH: String = "res://tests/net/data/quick_gun_game.tres"
const PLAY_SECONDS: float = 20.0
const MIN_HITS: int = 5
const MIN_FAIR_SHARE: float = 0.85
const MIN_ENEMY_HITS: int = 3
const MIN_PREDICTED_HITS: int = 5
## Own hit feedback budgets (latency plan step 3: about one frame).
const MAX_HIT_FEEDBACK_P50_MS: float = 20.0
const MAX_HIT_FEEDBACK_P95_MS: float = 35.0
const MIN_CONFIRM_SHARE: float = 0.9
const SPITTER_PATH: String = "res://tests/net/data/test_spitter.tres"
const CHASER_SCENE_PATH: String = "res://enemies/chaser.tscn"
const SPITTERS: int = 2
## The client's simulated connection when the role names none: latency, jitter, loss %.
const DEFAULT_SIM: String = "80,0,0"
## Groups.LIVING_PLAYERS: who enemies hunt.
const LIVING_GROUP: StringName = &"living_players"
## Shot.ENEMY_SHOOTER_BASE: enemy shooter ids are at or below it.
const ENEMY_SHOOTER_BASE: int = -(1 << 20)
## Both bots share this team, so they leave each other alone and go for the client.
const BOT_TEAM: int = -100
## Damage taken multiplier for test targets: every hit deals the minimum of 1.
const TEST_DAMAGE_TAKEN: float = 0.0001
## Test targets are topped up below this share of their health. Low, so a top-up (which hides
## that frame's drop from the hit feedback timing) is rare; never below 3, so two hits in one
## frame can't kill.
const TOP_UP_SHARE: float = 0.1
## Player hitbox radius + bullet radius + a little slack for blending between ticks (px).
const ON_PLAYER_DISTANCE: float = 33.0
## ProjectileSystem's event topic and kinds.
const TOPIC: int = 1
const EVENT_ENDED: int = 2
const EVENT_HURT: int = 4

## Client: tick of its own timeline -> where its player was.
var _own_positions: Dictionary = {}
## Client: tick of its own timeline -> Time.get_ticks_usec() when it was recorded.
var _tick_usec: Dictionary = {}
var _hurt_pending: int = 0
var _fair: int = 0
var _unfair: int = 0
## Host: enemy bolts fired (shooter ids at or below ENEMY_SHOOTER_BASE).
var _enemy_bolts: int = 0
var _enemy_fair: int = 0
var _enemy_unfair: int = 0
## Client: how it moves and whether it fires (at the nearest of _aim_targets()).
var _move: Vector2 = Vector2.ZERO
var _firing: bool = false
var _meter: HitFeedbackMeter = null
## How long the client plays (scenario I plays longer for steadier numbers).
var _play_seconds: float = PLAY_SECONDS


func _initialize() -> void:
	_metric_label = "FAIRNESS"
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
	root.get_node("EventBus").shot_fired.connect(_count_enemy_bolt)
	_spawn_enemies(SPITTER_PATH, SPITTERS)
	while net.peers.size() >= 2:
		_hold_host_frame()
		await process_frame
	_info("spitters alive %d, enemy bolts fired %d" % [_enemies().size(), _enemy_bolts])
	net.leave()
	await create_timer(0.5).timeout


## Host, every frame: the humans can't be hurt, the bots take 1 per hit and are topped up, and
## only the client is hunted.
func _hold_host_frame() -> void:
	var own: Node = root.get_node_or_null(_level_path() + "/Players/1")
	if own != null:
		own.get_node("HitboxComponent").monitorable = false
	for player: Node in _players():
		var health: Node = player.get_node("HealthComponent")
		health.invulnerable = not player.get("is_bot")
		if player.get("is_bot"):
			player.set("team_id", BOT_TEAM)
			_top_up(health)
		# Enemies chase the nearest living player: only the client counts as one here.
		if player.get("is_bot") or player.name == "1":
			player.remove_from_group(LIVING_GROUP)
	for enemy: Node in _enemies():
		enemy.get_node("HealthComponent").invulnerable = true
		# On the bots' team, so the bots keep hunting the client instead of the spitters.
		enemy.get_node("HitboxComponent").team = StringName("team_%d" % BOT_TEAM)


## Host: every hit on `health` deals 1, and it never runs low enough to die.
func _top_up(health: Node) -> void:
	health.damage_taken_multiplier = TEST_DAMAGE_TAKEN
	if _needs_top_up(health):
		health.call("set_health", health.max_health)


## Host: whether a test target is low enough to top up.
func _needs_top_up(health: Node) -> bool:
	return health.current_health <= maxi(roundi(health.max_health * TOP_UP_SHARE), 3)


func _count_enemy_bolt(shot: RefCounted) -> void:
	if shot.get("shooter_id") <= ENEMY_SHOOTER_BASE:
		_enemy_bolts += 1


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	_configure_simulator(net)
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own_player() != null, 15.0)
	_start_watching(net)
	await create_timer(3.0).timeout
	await _play()
	_report()
	net.leave()
	await create_timer(0.5).timeout


## The client's simulated connection, from the role's "latency,jitter,loss%" argument.
func _configure_simulator(net: Node) -> void:
	var sim: String = _args[2] if _args.size() > 2 else DEFAULT_SIM
	var parts: PackedStringArray = sim.split(",")
	var jitter: int = parts[1].to_int() if parts.size() > 1 else 0
	var loss: float = parts[2].to_float() / 100.0 if parts.size() > 2 else 0.0
	net.configure_simulator(parts[0].to_int(), jitter, loss)
	_info("client simulator %s (latency, jitter, loss %%)" % sim)


func _start_watching(net: Node) -> void:
	net.channel.event_received.connect(_on_event)
	physics_frame.connect(_on_physics_frame)
	var level: Node = root.get_node(_level_path())
	_meter = HitFeedbackMeter.new(_feedback_targets, _add)
	_meter.watch(
		level.get_node("Projectiles"), level.get_node("ProjectileSystem"), root.get_node("EventBus")
	)
	process_frame.connect(_meter.poll)


## Strafes (half a second walking, half a second standing) and fires for _play_seconds, then
## waits a second so the last hits are confirmed and shown.
func _play() -> void:
	var end_msec: int = Time.get_ticks_msec() + roundi(_play_seconds * 1000.0)
	var direction: float = 1.0
	_firing = true
	while Time.get_ticks_msec() < end_msec:
		direction = -direction
		_move = Vector2(direction, 0.4 * direction).normalized()
		await create_timer(0.5).timeout
		_move = Vector2.ZERO
		await create_timer(0.5).timeout
	_firing = false
	await create_timer(1.0).timeout


func _on_physics_frame() -> void:
	_record_own_position()
	_steer()


## The tick the client stamps on its inputs (its view of the host's present) -> where its own
## player is after that tick's prediction.
func _record_own_position() -> void:
	var player: Node2D = _own_player()
	if player == null:
		return
	var tick: int = roundi(root.get_node("NetworkManager").clock.server_tick_now())
	_own_positions[tick] = player.get_node("HitboxComponent").call("center")
	_tick_usec[tick] = Time.get_ticks_usec()


## Moves as _play() says and aims at (and, while firing, shoots) the nearest target.
func _steer() -> void:
	var player: Node2D = _own_player()
	if player == null:
		return
	var command: RefCounted = _input_command_script.new()
	command.move = _move
	var target: Node2D = _nearest(_aim_targets(), player.global_position)
	if target != null:
		command.aim = (target.global_position - player.global_position).angle()
		command.buttons = _fire_button if _firing else 0
	player.get_node("PlayerInputSource").scripted = command


## What the client shoots at: the bots.
func _aim_targets() -> Array[Node]:
	return _bots()


## Whose health drops count as feedback for the client's hits: the bots.
func _feedback_targets() -> Array[Node]:
	return _bots()


func _bots() -> Array[Node]:
	var bots: Array[Node] = []
	for player: Node in _players():
		if player.get("is_bot"):
			bots.append(player)
	return bots


func _nearest(candidates: Array[Node], from: Vector2) -> Node2D:
	var best: Node2D = null
	for candidate: Node2D in candidates:
		if (
			best == null
			or from.distance_to(candidate.global_position) < from.distance_to(best.global_position)
		):
			best = candidate
	return best


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
	_report_hit_feedback()


## The client's own hit feedback: it must play within a frame of the bullet landing, and the host
## must agree with nearly every hit our screen showed.
func _report_hit_feedback() -> void:
	var p50: float = _percentile("hit_feedback_ms", 0.5)
	var p95: float = _percentile("hit_feedback_ms", 0.95)
	_metric("predicted_hits", _meter.predicted_hits())
	_metric("hit_feedback_ms_p50", p50)
	_metric("hit_feedback_ms_p95", p95)
	_metric("hit_feedback_unanswered", _meter.unanswered)
	_metric("hit_feedback_ambiguous", _meter.ambiguous)
	_metric("predicted_confirm_share", _meter.confirm_share())
	_check(
		_meter.predicted_hits() >= MIN_PREDICTED_HITS,
		"only %d predicted hits to time" % _meter.predicted_hits()
	)
	_check(p50 <= MAX_HIT_FEEDBACK_P50_MS, "own hits show after %.0f ms (p50)" % p50)
	_check(p95 <= MAX_HIT_FEEDBACK_P95_MS, "own hits show after %.0f ms (p95)" % p95)
	_check(
		_meter.confirm_share() >= MIN_CONFIRM_SHARE,
		"the host confirmed only %.0f%% of our shown hits" % (_meter.confirm_share() * 100)
	)


## Host: `count` enemies of `data_path` at the level's enemy spawn points nearest the client.
func _spawn_enemies(data_path: String, count: int) -> Array[Node]:
	var level: Node = root.get_node(_level_path())
	var client: Node2D = _client_on_host()
	var points: Array = level.call("enemy_spawn_positions")
	if client != null:
		points.sort_custom(
			func(a: Vector2, b: Vector2) -> bool:
				return (
					a.distance_squared_to(client.global_position)
					< b.distance_squared_to(client.global_position)
				)
		)
	var spawned: Array[Node] = []
	for i in count:
		var enemy: Node2D = (load(CHASER_SCENE_PATH) as PackedScene).instantiate()
		enemy.set("enemy_data", load(data_path))
		enemy.position = points[i % points.size()]
		level.call("add_enemy", enemy)
		spawned.append(enemy)
	return spawned


## Host: the client's player (the human that isn't the host).
func _client_on_host() -> Node2D:
	for player: Node in _players():
		if not player.get("is_bot") and player.name != "1":
			return player
	return null


func _enemies() -> Array[Node]:
	var enemies_root: Node = root.get_node_or_null(_level_path() + "/Enemies")
	return enemies_root.get_children() if enemies_root != null else []


func _players() -> Array[Node]:
	var players_root: Node = root.get_node_or_null(_level_path() + "/Players")
	return players_root.get_children() if players_root != null else []
