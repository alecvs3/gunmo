extends "res://tests/net/fairness.gd"
## Smoke scenario I, Waves at 160 ms (docs/LATENCY_PLAN.md, step 1: the lag lab). A host and a
## client with simulated latency (the role's "latency,jitter,loss%" argument, 80 ms each way by
## default) sit in the lobby of a Waves match (no wave ever starts). The host spawns 3 Runners
## (melee), a test spitter and a test volley enemy (a 5-bolt fan after a 0.4 s windup); they hunt
## only the client. Every hit on an enemy deals 1 damage and the host tops them up; the client
## can be hurt but the host refills its health every frame. The client strafes for 40 s and
## shoots the nearest enemy, and measures what a 160 ms player feels:
##   hit_feedback_ms        own hit landing -> its flash and hit sound
##                          (tests/net/hit_feedback_meter.gd)
##   predicted_confirm_share  hits our screen predicted that the host confirmed
##   bullet_visible_share   enemy bullets that hit us: drawn on our player at the judged tick
##   hurt_feedback_ms       such a bullet first drawn on us -> our hurt sound
##                          (both: tests/net/incoming_hit_judge.gd)
##   melee_fair_share       melee hits on us where the enemy we drew touched us at the judged tick
##   melee_gap_px           how far that drawn enemy's contact square was from our hitbox
## For melee, the host's EVENT_HURT for each touch names the enemy and the tick of our own
## timeline it was judged on (fair contact, step 5), and the test's host also sends where it had
## us at that tick (test-only topic): a hit while a shove had moved us without our screen knowing
## yet is counted apart (melee_hits_while_displaced), like bullet hits while displaced.
## Each step of the plan turns on the budget of the number it fixes: hit_feedback_ms and
## predicted_confirm_share (step 3), bullet_visible_share and hurt_feedback_ms (step 4),
## melee_fair_share and melee_gap_px (step 5).
## Usage: -s res://tests/net/waves_fairness.gd -- <waveshost|wavesclient> <port>
## [latency,jitter,loss%]. It runs before the autoloads exist, so it names no project classes.

const WAVES_MATCH_PATH: String = "res://tests/net/data/fair_waves_match.tres"
const RUNNER_PATH: String = "res://enemies/data/runner.tres"
const VOLLEY_PATH: String = "res://tests/net/data/test_volley.tres"
const RUNNERS: int = 3
## Longer than H: its shares need more samples to be steady from run to run.
const WAVES_PLAY_SECONDS: float = 40.0
## One tick of a Runner's movement (230 px/s at 60 Hz), for blending between ticks (px).
const MELEE_SLACK: float = 4.0
const MIN_BULLET_HITS: int = 3
const MIN_MELEE_HITS: int = 3
## Test-only NetChannel topic (no game code uses it): where the host had the client at the tick a
## touch on it was judged on.
const HOST_VIEW_TOPIC: int = 200
## Our own screen had us further than this from where the host did (px): displaced (a shove our
## prediction hasn't learnt of yet), so the hit is counted apart.
const DISPLACED_PX: float = 6.0
## Fair contact (latency plan step 5): melee hits where the enemy we drew touched us.
const MIN_MELEE_FAIR_SHARE: float = 0.85
const MAX_MELEE_GAP_P95_PX: float = 12.0
## Ticks of drawn positions the client keeps.
const KEEP_TICKS: int = 600

## Client: tick of its own timeline -> {enemy net id: where we drew it}.
var _drawn_enemies: Dictionary = {}
## Client: enemy net id -> half the size of its contact square.
var _contact_half: Dictionary = {}
var _melee_fair: int = 0
var _melee_unfair: int = 0
## Client: melee hits while our screen had us elsewhere than the host (counted apart).
var _melee_displaced: int = 0
## Client: judged tick -> net ids of the enemies whose touch EVENT_HURT came, waiting for the
## host's view of us at that tick.
var _pending_melee: Dictionary = {}


func _initialize() -> void:
	_metric_label = "WAVEFAIR"
	_play_seconds = WAVES_PLAY_SECONDS
	_boot("waveshost", 7800, WATCHDOG_SECONDS)


func _run() -> void:
	if _role == "waveshost":
		await _run_waves_host()
	else:
		await _run_client()
	_finish("")


func _run_waves_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", WAVES_MATCH_PATH)
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return net.peers.size() >= 2, 20.0)
	_check(net.peers.size() == 2, "client never joined")
	await create_timer(3.0).timeout
	var client: Node2D = _client_on_host()
	_check(client != null, "no client player on the host")
	var hunters: Array[Node] = _spawn_enemies(RUNNER_PATH, RUNNERS)
	hunters += _spawn_enemies(SPITTER_PATH, 1)
	hunters += _spawn_enemies(VOLLEY_PATH, 1)
	for enemy: Node in hunters:
		enemy.set("_base_damage_taken", TEST_DAMAGE_TAKEN)
	root.get_node("EventBus").contact_hit.connect(_tell_host_view.bind(client))
	while net.peers.size() >= 2:
		_hold_waves_host_frame(client)
		await process_frame
	net.leave()
	await create_timer(0.5).timeout


## Host, every frame: our own player is out of the fight, the client never runs out of health
## and the enemies never die.
func _hold_waves_host_frame(client: Node2D) -> void:
	var own: Node = root.get_node_or_null(_level_path() + "/Players/1")
	if own != null:
		own.get_node("HitboxComponent").monitorable = false
		own.get_node("HealthComponent").invulnerable = true
		own.remove_from_group(LIVING_GROUP)
	if is_instance_valid(client):
		var health: Node = client.get_node("HealthComponent")
		health.call("set_health", health.max_health)
	for enemy: Node in _enemies():
		var health: Node = enemy.get_node("HealthComponent")
		if _needs_top_up(health):
			health.call("set_health", health.max_health)


func _aim_targets() -> Array[Node]:
	return _enemies()


## Runners only: the test enemies' data can't load on clients (outside enemies/data/), so
## their health on our screen doesn't follow the host's.
func _feedback_targets() -> Array[Node]:
	var runners: Array[Node] = []
	for enemy: Node in _enemies():
		if enemy.get("data_path") == RUNNER_PATH:
			runners.append(enemy)
	return runners


func _on_physics_frame() -> void:
	super._on_physics_frame()
	var tick: int = roundi(root.get_node("NetworkManager").clock.server_tick_now())
	_record_drawn_enemies(tick)
	for old: Dictionary in [_own_positions, _tick_usec, _drawn_enemies]:
		old.erase(tick - KEEP_TICKS)


func _record_drawn_enemies(tick: int) -> void:
	var drawn: Dictionary = {}
	for enemy: Node2D in _enemies():
		var net_id: int = enemy.get_node("NetEntity").net_id
		drawn[net_id] = enemy.global_position
		if not _contact_half.has(net_id):
			var shape: CollisionShape2D = enemy.get_node("ContactArea/CollisionShape2D")
			_contact_half[net_id] = shape.shape.get("size") * shape.scale / 2.0
	_drawn_enemies[tick] = drawn


## EVENT_HURT from an enemy's touch (after its source byte): the host judged it on our own tick;
## did that enemy, as we drew it then, touch us?
func _on_contact_hurt(buffer: StreamPeerBuffer) -> void:
	buffer.get_float()
	buffer.get_float()
	var net_id: int = ENEMY_SHOOTER_BASE - buffer.get_32()
	var tick: int = buffer.get_u32()
	if tick >= 1 << 31:
		return
	var waiting: Array = _pending_melee.get(tick, [])
	waiting.append(net_id)
	_pending_melee[tick] = waiting


## Host (test only): where the host had the client at the tick a touch on it was judged on.
func _tell_host_view(enemy: Node2D, hitbox: Node, client: Node2D) -> void:
	if not is_instance_valid(client) or hitbox != client.get_node("HitboxComponent"):
		return
	var tick: int = enemy.call("judged_tick", hitbox)
	if tick < 0:
		return
	var place: RefCounted = client.get("timeline").get("history").call("sample", tick)
	var buffer := StreamPeerBuffer.new()
	buffer.put_32(tick)
	buffer.put_float(place.get("position").x)
	buffer.put_float(place.get("position").y)
	var channel: Object = root.get_node("NetworkManager").channel
	channel.call("send_event", client.name.to_int(), HOST_VIEW_TOPIC, buffer.data_array)


func _on_event(topic: int, data: PackedByteArray) -> void:
	if topic != HOST_VIEW_TOPIC or data.is_empty():
		super._on_event(topic, data)
		return
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var tick: int = buffer.get_32()
	var host_view := Vector2(buffer.get_float(), buffer.get_float())
	var waiting: Array = _pending_melee.get(tick, [])
	if waiting.is_empty():
		return
	_judge_melee(waiting.pop_front(), tick, host_view)
	if waiting.is_empty():
		_pending_melee.erase(tick)


## A touch the host judged on our tick `tick`, with us at `host_view` there: did that enemy, as we
## drew it, touch us where our screen had us?
func _judge_melee(net_id: int, tick: int, host_view: Vector2) -> void:
	var drawn: Vector2 = _drawn_enemy_at(net_id, tick)
	if not drawn.is_finite() or not _own_positions.has(tick):
		return
	if (_own_positions[tick] as Vector2).distance_to(host_view) > DISPLACED_PX:
		_melee_displaced += 1
		return
	var gap: float = _contact_gap(drawn, _contact_half[net_id], tick)
	_melee_fair += 1 if gap <= MELEE_SLACK else 0
	_melee_unfair += 0 if gap <= MELEE_SLACK else 1
	_add("melee_gap_px", maxf(gap, 0.0))


## Where we drew enemy `net_id` at our own `tick` (halfway between the ticks around it when that
## tick has no sample), or INF.
func _drawn_enemy_at(net_id: int, tick: int) -> Vector2:
	var at: Dictionary = _drawn_enemies.get(tick, {})
	if at.has(net_id):
		return at[net_id]
	var before: Dictionary = _drawn_enemies.get(tick - 1, {})
	var after: Dictionary = _drawn_enemies.get(tick + 1, {})
	if before.has(net_id) and after.has(net_id):
		return (before[net_id] as Vector2).lerp(after[net_id], 0.5)
	return Vector2.INF


## Pixels between an enemy's contact square (centred on it) and our hitbox at `tick`; 0 or less
## means they touch.
func _contact_gap(center: Vector2, half: Vector2, tick: int) -> float:
	var own: Vector2 = _own_positions[tick]
	var closest := Vector2(
		clampf(own.x, center.x - half.x, center.x + half.x),
		clampf(own.y, center.y - half.y, center.y + half.y)
	)
	var radius: float = _own_player().get_node("HitboxComponent/CollisionShape2D").shape.get(
		"radius"
	)
	return own.distance_to(closest) - radius


func _report() -> void:
	_report_hit_feedback()
	_report_incoming()
	var bullet_hits: int = _incoming.bullet_hits()
	var melee_hits: int = _melee_fair + _melee_unfair
	_metric("melee_hits_on_client", melee_hits)
	_metric("melee_hits_while_displaced", _melee_displaced)
	_metric("melee_fair_share", _melee_fair / float(maxi(melee_hits, 1)))
	_metric("melee_gap_px_p50", _percentile("melee_gap_px", 0.5))
	_metric("melee_gap_px_p95", _percentile("melee_gap_px", 0.95))
	_check(bullet_hits >= MIN_BULLET_HITS, "only %d enemy bullet hits to judge" % bullet_hits)
	_check(melee_hits >= MIN_MELEE_HITS, "only %d melee hits to judge" % melee_hits)
	var fair: float = _melee_fair / float(maxi(melee_hits, 1))
	var gap_p95: float = _percentile("melee_gap_px", 0.95)
	_check(fair >= MIN_MELEE_FAIR_SHARE, "only %.0f%% of melee hits touched us" % (fair * 100))
	_check(gap_p95 <= MAX_MELEE_GAP_P95_PX, "melee hits %.0f px away (p95)" % gap_p95)
