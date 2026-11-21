class_name PositionHistory
extends RefCounted
## Where one hitbox was, and whether it could be hit, over the last few hundred ms of ticks.

var capacity: int = 32

var _ticks: Array[int] = []
var _positions: Array[Vector2] = []
var _hittable: Array[bool] = []


func record(tick: int, position: Vector2, hittable: bool) -> void:
	_ticks.append(tick)
	_positions.append(position)
	_hittable.append(hittable)
	while _ticks.size() > capacity:
		_ticks.pop_front()
		_positions.pop_front()
		_hittable.pop_front()


func is_empty() -> bool:
	return _ticks.is_empty()


## {"position": Vector2, "hittable": bool} at `tick`, blended between recorded ticks.
## Outside the recorded range it holds the nearest end.
func sample(tick: float) -> Dictionary:
	if _ticks.is_empty():
		return {}
	if tick <= _ticks[0]:
		return {"position": _positions[0], "hittable": _hittable[0]}
	var last: int = _ticks.size() - 1
	if tick >= _ticks[last]:
		return {"position": _positions[last], "hittable": _hittable[last]}
	var index: int = 0
	while _ticks[index + 1] <= tick:
		index += 1
	var weight: float = (tick - _ticks[index]) / float(_ticks[index + 1] - _ticks[index])
	return {
		"position": _positions[index].lerp(_positions[index + 1], weight),
		"hittable": _hittable[index] and _hittable[index + 1],
	}
