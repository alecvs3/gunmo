class_name NetClock
extends Node
## Shared simulation time, in ticks (one tick = one physics frame).
## The host counts ticks. Clients estimate the host's current tick from the tick stamped on
## each snapshot plus half the round trip, and draw remote objects a smoothing delay behind
## that estimate (the "render tick"), so there are always two snapshots to blend between.
## A snapshot is already the one-way latency old when it arrives, so the delay is that latency
## plus a smoothing buffer. The buffer adapts: one snapshot interval plus the measured jitter, grows
## quickly when snapshots start arriving unevenly (or drawing runs out of snapshots) and
## shrinks slowly once they are even again. The host draws everyone but itself
## host_view_delay_ticks behind (see DisplayDelay), so its render tick is that far back too.

var config: NetworkConfig
## Host: the tick being simulated now.
var tick: int = 0
## Client: how unevenly snapshots arrive.
var snapshot_jitter := JitterMeter.new()
## Client: times drawing caught up with the newest snapshot (it had to hold still).
var ran_dry_count: int = 0

var _estimate: float = 0.0
var _synced: bool = false
var _delay: float = 0.0
## Extra delay after running dry (half a snapshot interval each time); fades at dry_boost_decay.
var _boost: float = 0.0
var _dry: bool = false
var _newest_tick: int = -1
var _last_arrival: float = 0.0
## Client: estimated one-way latency to the host (seconds, smoothed).
var _one_way: float = 0.0


static func tick_rate() -> int:
	return Engine.physics_ticks_per_second


static func tick_delta() -> float:
	return 1.0 / Engine.physics_ticks_per_second


## The client's next estimate of the host's tick after observing `target`. Small errors are
## corrected gradually so the timeline never jumps; big ones (or the first) snap.
static func corrected(
	estimate: float, target: float, synced: bool, snap_ticks: float, correction: float
) -> float:
	if not synced or absf(target - estimate) > snap_ticks:
		return target
	return lerpf(estimate, target, correction)


## The delay a client aims for: one snapshot interval, the jitter (scaled) and a margin, plus
## the boost after running dry, kept within the configured limits. All in seconds.
static func target_delay(
	interval: float, jitter: float, boost: float, settings: NetworkConfig
) -> float:
	var wanted: float = interval + jitter * settings.jitter_scale + settings.smoothing_margin
	return clampf(
		wanted + boost, settings.min_interpolation_delay, settings.max_interpolation_delay
	)


## One step of the delay toward `target`: up at `raise_rate`, down at `lower_rate` (seconds of
## delay per second), never past the target.
static func stepped_delay(
	current: float, target: float, delta: float, raise_rate: float, lower_rate: float
) -> float:
	if target > current:
		return minf(current + raise_rate * delta, target)
	return maxf(current - lower_rate * delta, target)


## Runs before every other physics node, so the whole tick sees the same number.
func _ready() -> void:
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		tick += 1


func _process(delta: float) -> void:
	if _synced and not multiplayer.is_server():
		_estimate += delta * tick_rate()
		_adapt_delay(delta)
		_check_hiccup()


func reset() -> void:
	tick = 0
	_estimate = 0.0
	_synced = false
	_delay = config.interpolation_delay if config != null else 0.1
	_boost = 0.0
	_dry = false
	_newest_tick = -1
	_one_way = 0.0
	ran_dry_count = 0
	snapshot_jitter.reset()


func is_synced() -> bool:
	return multiplayer.is_server() or _synced


## Client: a snapshot stamped `server_tick` arrived; half_rtt is the one-way delay estimate.
func observe_server_tick(server_tick: int, half_rtt_seconds: float) -> void:
	var target: float = server_tick + half_rtt_seconds * tick_rate()
	_estimate = corrected(
		_estimate, target, _synced, config.clock_snap_ticks, config.clock_correction
	)
	if not _synced:
		_delay = config.interpolation_delay
		_one_way = half_rtt_seconds
	else:
		_one_way = lerpf(_one_way, half_rtt_seconds, config.clock_correction)
	_synced = true


## Client: the first packet of the snapshot for `server_tick` arrived at `now_seconds`.
## Returns how many snapshots were skipped since the previous one (lost or out of order).
func observe_snapshot_arrival(server_tick: int, now_seconds: float) -> int:
	if server_tick <= _newest_tick:
		return 0
	var missed: int = 0
	if _newest_tick >= 0:
		var step: int = maxi(config.snapshot_interval_ticks, 1)
		missed = maxi((server_tick - _newest_tick) / step - 1, 0)
	snapshot_jitter.observe(server_tick * tick_delta(), now_seconds)
	_newest_tick = server_tick
	_last_arrival = now_seconds
	return missed


## How far behind the host this peer draws remote objects right now (seconds): the latency
## plus the smoothing buffer (on the host: its view delay).
func smoothing_delay() -> float:
	if multiplayer.is_server():
		return config.host_view_delay_ticks * tick_delta()
	return _delay


## The part of smoothing_delay() that is buffering, not latency (seconds).
func buffer_delay() -> float:
	if multiplayer.is_server():
		return smoothing_delay()
	return maxf(_delay - _one_way, 0.0)


## Client: estimated one-way latency to the host (seconds).
func one_way_latency() -> float:
	return 0.0 if multiplayer.is_server() else _one_way


## The host's tick right now (the host's own count, or the client's estimate of it).
func server_tick_now() -> float:
	return float(tick) if multiplayer.is_server() else _estimate


## The moment this peer draws remote objects at (and aims at: shots are checked against it).
func render_tick() -> float:
	if multiplayer.is_server():
		return float(tick - config.host_view_delay_ticks)
	return _estimate - _delay * tick_rate()


func _adapt_delay(delta: float) -> void:
	var dry: bool = _newest_tick >= 0 and render_tick() > _newest_tick
	if dry and not _dry:
		ran_dry_count += 1
		_boost += config.snapshot_interval_ticks * tick_delta() * 0.5
	_dry = dry
	_boost = maxf(_boost - config.dry_boost_decay * delta, 0.0)
	var interval: float = config.snapshot_interval_ticks * tick_delta()
	var buffer: float = target_delay(interval, snapshot_jitter.jitter_seconds(), _boost, config)
	var target: float = _one_way + buffer
	_delay = stepped_delay(_delay, target, delta, config.delay_raise_rate, config.delay_lower_rate)


func _check_hiccup() -> void:
	var silent: float = Time.get_ticks_usec() / 1000000.0 - _last_arrival
	if _newest_tick >= 0 and silent > config.hiccup_seconds:
		(
			NetLog
			. write_limited(
				"no_snapshots",
				(
					"hiccup: no snapshot from the host for %d ms (jitter %.1f ms, smoothing %d ms)"
					% [
						roundi(silent * 1000.0),
						snapshot_jitter.jitter_seconds() * 1000.0,
						roundi(_delay * 1000.0),
					]
				)
			)
		)
