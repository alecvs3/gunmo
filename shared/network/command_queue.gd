class_name CommandQueue
extends RefCounted
## Host side: one player's input commands waiting to be simulated, oldest first.
## Copies already seen (every packet repeats recent commands) are dropped. Each tick earns one
## command of budget, saved up to `budget_cap`, so a player whose packets came late catches up
## a little, but nobody is ever simulated faster than real time (no speed hacks).
## Smoothing (a playout buffer): normally nothing is held back, so a player's inputs add no delay.
## Only when that player actually stalls (a tick with no input to simulate) `stalls_to_grow` x
## (reserve + 1) times within `grow_window_ticks` does the queue keep one more command in reserve
## (at most `max_buffer`). It plays one command per tick, using the reserve when a packet is late,
## so a late packet becomes an even, slightly later stream instead of a stop and a jump; a backlog
## beyond the reserve drains at max_per_tick. After a real stall it waits until the reserve has
## refilled before playing again. After `calm_ticks` without a stall it gives one tick of reserve
## back.

var budget_cap: int = 4
var max_per_tick: int = 2
var max_pending: int = 16
var max_buffer: int = 2
var stalls_to_grow: int = 2
var grow_window_ticks: int = 120
var calm_ticks: int = 300
## Highest sequence number accepted so far.
var last_received: int = -1
## Commands held back right now (= ticks of extra delay).
var buffer_ticks: int = 0
## Ticks in a row with no input to simulate (0 while inputs flow).
var stall_run: int = 0
## How unevenly this player's commands arrive.
var jitter := JitterMeter.new()

var _pending: Array[InputCommand] = []
var _budget: float = 0.0
var _tick: int = 0
## Recent stalls, for growing the reserve (cleared when it grows).
var _stalls: Array[int] = []
## Stalls in the last second, for the late-input report.
var _late: Array[int] = []
var _last_stall: int = 0
## Holding commands back on purpose until the reserve is full again (not a stall).
var _refilling: bool = false


func configure(config: NetworkConfig) -> void:
	budget_cap = config.command_budget
	max_per_tick = config.max_commands_per_tick
	max_pending = config.max_pending_commands
	max_buffer = config.max_input_buffer_ticks
	stalls_to_grow = config.stalls_to_grow_buffer
	grow_window_ticks = roundi(config.buffer_grow_window * NetClock.tick_rate())
	calm_ticks = roundi(config.buffer_calm_time * NetClock.tick_rate())


## `arrived_seconds` (our clock, < 0 = unknown) feeds the jitter measurement.
func push(commands: Array[InputCommand], arrived_seconds: float = -1.0) -> void:
	for command in commands:
		if command.sequence > last_received:
			_pending.append(command.sanitized())
			last_received = command.sequence
			if arrived_seconds >= 0.0:
				jitter.observe(command.sequence * NetClock.tick_delta(), arrived_seconds)
	while _pending.size() > max_pending + buffer_ticks:
		_pending.pop_front()


## The commands to simulate this tick (often one, sometimes none, at most max_per_tick).
func take_for_tick() -> Array[InputCommand]:
	_tick += 1
	_budget = minf(_budget + 1.0, budget_cap)
	var taken: Array[InputCommand] = []
	if _refilling and _pending.size() > buffer_ticks:
		_refilling = false
	if not _refilling:
		var most: int = 1 if _pending.size() <= buffer_ticks + 1 else max_per_tick
		while not _pending.is_empty() and _budget >= 1.0 and taken.size() < most:
			taken.append(_pending.pop_front())
			_budget -= 1.0
		if taken.is_empty() and last_received >= 0:
			_on_stall()
		else:
			stall_run = 0
	_adapt()
	return taken


func pending_count() -> int:
	return _pending.size()


## Ticks in the last second with no input to simulate.
func late_per_second() -> int:
	var since: int = _tick - NetClock.tick_rate()
	while not _late.is_empty() and _late[0] <= since:
		_late.pop_front()
	return _late.size()


func _on_stall() -> void:
	stall_run += 1
	_stalls.append(_tick)
	_late.append(_tick)
	_last_stall = _tick
	_refilling = buffer_ticks > 0


func _adapt() -> void:
	var window_start: int = _tick - maxi(grow_window_ticks, NetClock.tick_rate())
	while not _stalls.is_empty() and _stalls[0] <= window_start:
		_stalls.pop_front()
	var recent: int = 0
	for stall in _stalls:
		recent += 1 if stall > _tick - grow_window_ticks else 0
	# Each further tick of reserve takes proportionally more stalls (it costs more delay).
	if recent >= stalls_to_grow * (buffer_ticks + 1) and buffer_ticks < max_buffer:
		buffer_ticks += 1
		_stalls.clear()
		_last_stall = _tick
		_refilling = true
	elif buffer_ticks > 0 and _tick - _last_stall >= calm_ticks:
		buffer_ticks -= 1
		_last_stall = _tick
