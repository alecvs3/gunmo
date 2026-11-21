class_name NetClock
extends Node
## Shared simulation time, in ticks (one tick = one physics frame).
## The host counts ticks. Clients estimate the host's current tick from the tick stamped on
## each snapshot plus half the round trip, and draw remote objects interpolation_delay behind
## that estimate (the "render tick"), so there are always two snapshots to blend between.

var config: NetworkConfig
## Host: the tick being simulated now.
var tick: int = 0

var _estimate: float = 0.0
var _synced: bool = false


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


## Runs before every other physics node, so the whole tick sees the same number.
func _ready() -> void:
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		tick += 1


func _process(delta: float) -> void:
	if _synced and not multiplayer.is_server():
		_estimate += delta * tick_rate()


func reset() -> void:
	tick = 0
	_estimate = 0.0
	_synced = false


func is_synced() -> bool:
	return multiplayer.is_server() or _synced


## Client: a snapshot stamped `server_tick` arrived; half_rtt is the one-way delay estimate.
func observe_server_tick(server_tick: int, half_rtt_seconds: float) -> void:
	var target: float = server_tick + half_rtt_seconds * tick_rate()
	_estimate = corrected(
		_estimate, target, _synced, config.clock_snap_ticks, config.clock_correction
	)
	_synced = true


## The host's tick right now (the host's own count, or the client's estimate of it).
func server_tick_now() -> float:
	return float(tick) if multiplayer.is_server() else _estimate


## The moment clients draw remote objects at. The host draws the present.
func render_tick() -> float:
	if multiplayer.is_server():
		return float(tick)
	return _estimate - config.interpolation_delay * tick_rate()
