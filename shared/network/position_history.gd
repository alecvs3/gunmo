class_name PositionHistory
extends RefCounted
## Where one hitbox was, and whether it could be hit, over the last few hundred ms of ticks.

var capacity: int = 32

var _ticks: Array[int] = []
var _positions: Array[Vector2] = []
var _hittable: Array[bool] = []


## Where the hitbox was at one moment.
class Place:
	var position: Vector2
	var hittable: bool

	func _init(at: Vector2, can_be_hit: bool) -> void:
		position = at
		hittable = can_be_hit


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


## Where it was at `tick`, blended between recorded ticks (null when nothing is recorded).
## Outside the recorded range it holds the nearest end.
func sample(tick: float) -> Place:
	var place := Place.new(Vector2.ZERO, false)
	return place if sample_into(tick, place) else null


## The same without making a new object: fills `place` (false when nothing is recorded).
## Hit tests call this for every target on every tick, where allocating would add up.
func sample_into(tick: float, place: Place) -> bool:
	if _ticks.is_empty():
		return false
	var last: int = _ticks.size() - 1
	if tick <= _ticks[0] or tick >= _ticks[last]:
		var end: int = 0 if tick <= _ticks[0] else last
		place.position = _positions[end]
		place.hittable = _hittable[end]
		return true
	var index: int = 0
	while _ticks[index + 1] <= tick:
		index += 1
	var weight: float = (tick - _ticks[index]) / float(_ticks[index + 1] - _ticks[index])
	place.position = _positions[index].lerp(_positions[index + 1], weight)
	place.hittable = _hittable[index] and _hittable[index + 1]
	return true
