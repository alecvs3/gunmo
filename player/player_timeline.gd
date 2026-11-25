class_name PlayerTimeline
extends RefCounted
## Host, for a remote human player: where their own inputs put them, by their own view of the
## host's tick (InputCommand.client_tick). Bots' bullets are tested against it (TimelineHits,
## fair dodging) and bots lead them by how far ahead their screen is (lead).
## The stamps come from the client, so a stamp may only be up to max_rewind in the past and
## never in the future or before the previous one (it can't be used to hide in time).
## Each stamp also keeps the tick the player was looking at then (InputCommand.view_tick, their
## render tick): enemy contact is judged against where they saw the enemy (fair contact). It may
## be at most victim_rewind before its stamp and never after it.

var history := PositionHistory.new()
## The newest tick recorded (-1 = none yet).
var newest: int = -1

var _max_rewind_ticks: int = 0
var _victim_rewind_ticks: int = 0
## Stamp -> the tick the player was looking at (oldest first).
var _views: Dictionary = {}


func _init(max_rewind_ticks: int, victim_rewind_ticks: int = 0) -> void:
	_max_rewind_ticks = max_rewind_ticks
	_victim_rewind_ticks = victim_rewind_ticks
	history.capacity = max_rewind_ticks * 3


## The newest tick recorded (a Callable for TimelineHits, which may outlive the player).
func newest_tick() -> int:
	return newest


## Where one input command (stamped `client_tick`, made while looking at `view_tick`) put the
## player, at host tick `now`.
func record(
	client_tick: float, now: int, center: Vector2, hittable: bool, view_tick: float = -1.0
) -> void:
	var stamp: int = clampi(roundi(client_tick), now - _max_rewind_ticks, now)
	stamp = maxi(stamp, newest + 1)
	if stamp > now:
		return
	newest = stamp
	history.record(stamp, center, hittable)
	var view: float = view_tick if view_tick >= 0.0 else float(stamp)
	_views[stamp] = clampf(view, stamp - _victim_rewind_ticks, stamp)
	while _views.size() > history.capacity:
		_views.erase(_views.keys()[0])


## The tick the player was looking at when making the input stamped `tick` (the stamp itself
## when unknown).
func view_at(tick: int) -> float:
	return _views.get(tick, float(tick))


## How far the player's own screen is ahead of where the host has them at `now`, in seconds:
## their latency plus input buffer.
func lead(now: int) -> float:
	if newest < 0:
		return 0.0
	return maxf(now - newest, 0.0) * NetClock.tick_delta()
