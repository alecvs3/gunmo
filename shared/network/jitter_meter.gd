class_name JitterMeter
extends RefCounted
## How unevenly something sent at a steady rate arrives (snapshots at a client, one player's
## input commands at the host). Each arrival gives an offset = arrival time - send time; the
## constant part (clock difference, average latency) cancels out, and the spread of the
## offsets over the last window_seconds is the jitter. Pure (times are passed in), so tested.

## Arrivals older than this are forgotten.
var window_seconds: float = 3.0
## Jitter is the spread between the earliest arrival and this share of the arrivals
## (0.95 ignores the rare worst 5% so one freak packet doesn't decide everything).
var percentile: float = 0.95

var _arrivals := PackedFloat64Array()
var _offsets := PackedFloat64Array()
var _cached: float = -1.0


## Something sent at `sent_seconds` (sender's clock) arrived at `arrived_seconds` (ours).
func observe(sent_seconds: float, arrived_seconds: float) -> void:
	_arrivals.append(arrived_seconds)
	_offsets.append(arrived_seconds - sent_seconds)
	var oldest: float = arrived_seconds - window_seconds
	var drop: int = 0
	while drop < _arrivals.size() and _arrivals[drop] < oldest:
		drop += 1
	if drop > 0:
		_arrivals = _arrivals.slice(drop)
		_offsets = _offsets.slice(drop)
	_cached = -1.0


## Seconds of jitter in the window (0 with fewer than two arrivals).
func jitter_seconds() -> float:
	if _cached >= 0.0:
		return _cached
	if _offsets.size() < 2:
		return 0.0
	var sorted: PackedFloat64Array = _offsets.duplicate()
	sorted.sort()
	var top: int = mini(ceili(percentile * (sorted.size() - 1)), sorted.size() - 1)
	_cached = sorted[top] - sorted[0]
	return _cached


func sample_count() -> int:
	return _offsets.size()


func reset() -> void:
	_arrivals = PackedFloat64Array()
	_offsets = PackedFloat64Array()
	_cached = -1.0
