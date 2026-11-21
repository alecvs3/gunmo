class_name PlayerTimeline
extends RefCounted
## Host, for a remote human player: where their own inputs put them, by their own view of the
## host's tick (InputCommand.client_tick). Bots' bullets are tested against it (TimelineHits,
## fair dodging) and bots lead them by how far ahead their screen is (lead).
## The stamps come from the client, so a stamp may only be up to max_rewind in the past and
## never in the future or before the previous one (it can't be used to hide in time).

var history := PositionHistory.new()
## The newest tick recorded (-1 = none yet).
var newest: int = -1

var _max_rewind_ticks: int = 0


func _init(max_rewind_ticks: int) -> void:
	_max_rewind_ticks = max_rewind_ticks
	history.capacity = max_rewind_ticks * 3


## The newest tick recorded (a Callable for TimelineHits, which may outlive the player).
func newest_tick() -> int:
	return newest


## Where one input command (stamped `client_tick`) put the player, at host tick `now`.
func record(client_tick: float, now: int, center: Vector2, hittable: bool) -> void:
	var stamp: int = clampi(roundi(client_tick), now - _max_rewind_ticks, now)
	stamp = maxi(stamp, newest + 1)
	if stamp > now:
		return
	newest = stamp
	history.record(stamp, center, hittable)


## How far the player's own screen is ahead of where the host has them at `now`, in seconds:
## their latency plus input buffer.
func lead(now: int) -> float:
	if newest < 0:
		return 0.0
	return maxf(now - newest, 0.0) * NetClock.tick_delta()
