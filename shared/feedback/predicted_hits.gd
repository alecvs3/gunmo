class_name PredictedHits
extends RefCounted
## Looks only: hits our own screen already showed (our bullet landed on this target before the
## host's verdict), waiting for the host's health drop that answers them. The host's feedback for
## a hit we already showed is not shown again, like DDNet's predicted events. One per target (its
## HitFeedback keeps it). Pure: times are passed in, in seconds. A predicted hit older than
## `window` is dropped: the host never confirmed it (a misprediction; its flash already played).

var _times: Array[float] = []


## Our own bullet landed on the target at `now`.
func add(now: float, window: float) -> void:
	_expire(now, window)
	_times.append(now)


## The host's health drop arrived: true if a predicted hit not older than `window` already
## showed it (the oldest one is used up).
func consume(now: float, window: float) -> bool:
	_expire(now, window)
	if _times.is_empty():
		return false
	_times.pop_front()
	return true


## Predicted hits still waiting for the host.
func pending(now: float, window: float) -> int:
	_expire(now, window)
	return _times.size()


func _expire(now: float, window: float) -> void:
	while not _times.is_empty() and now - _times[0] > window:
		_times.pop_front()
