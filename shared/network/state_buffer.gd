class_name StateBuffer
extends RefCounted
## A short history of one entity's states by server tick, for drawing it in the past.
## sample() blends the two states around the requested tick; before the oldest it holds the
## oldest, after the newest it holds the newest (no guessing ahead).

var capacity: int = 32

var _ticks: Array[int] = []
var _states: Array[NetState] = []


func push(tick: int, state: NetState) -> void:
	var index: int = _ticks.size()
	while index > 0 and _ticks[index - 1] > tick:
		index -= 1
	if index > 0 and _ticks[index - 1] == tick:
		return
	_ticks.insert(index, tick)
	_states.insert(index, state)
	while _ticks.size() > capacity:
		_ticks.pop_front()
		_states.pop_front()


func is_empty() -> bool:
	return _ticks.is_empty()


func latest() -> NetState:
	return null if _states.is_empty() else _states.back()


func latest_tick() -> int:
	return -1 if _ticks.is_empty() else _ticks.back()


func sample(render_tick: float) -> NetState:
	if _ticks.is_empty():
		return null
	if render_tick <= _ticks[0]:
		return _states[0]
	if render_tick >= _ticks.back():
		return _states.back()
	var index: int = 0
	while _ticks[index + 1] <= render_tick:
		index += 1
	_drop_before(index)
	var weight: float = (render_tick - _ticks[0]) / float(_ticks[1] - _ticks[0])
	return _states[0].interpolated(_states[1], weight)


## States older than the one we are blending from can never be needed again.
func _drop_before(index: int) -> void:
	for i in index:
		_ticks.pop_front()
		_states.pop_front()
