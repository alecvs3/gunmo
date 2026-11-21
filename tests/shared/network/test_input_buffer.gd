extends GutTest
## CommandQueue's adaptive input buffer: nothing held back while inputs flow evenly, one more
## command held after repeated stalls (at most max_buffer), and given back after a calm spell.

var queue: CommandQueue
var _next: int = 1


func before_each() -> void:
	queue = CommandQueue.new()
	queue.max_buffer = 2
	queue.stalls_to_grow = 2
	queue.grow_window_ticks = 120
	queue.calm_ticks = 30
	_next = 1


## One tick: `arriving` new commands arrive, then the host takes what it may.
func _tick(arriving: int) -> int:
	var commands: Array[InputCommand] = []
	for i in arriving:
		var command := InputCommand.new()
		command.sequence = _next
		_next += 1
		commands.append(command)
	queue.push(commands)
	return queue.take_for_tick().size()


func test_even_inputs_are_never_held_back() -> void:
	for i in 200:
		assert_eq(_tick(1), 1)
	assert_eq(queue.buffer_ticks, 0)
	assert_eq(queue.late_per_second(), 0)


func test_repeated_stalls_grow_the_buffer_by_one() -> void:
	for i in 10:
		_tick(1)
	for i in 2:
		_tick(0)
		_tick(2)
	assert_eq(queue.buffer_ticks, 1, "two stalls in the window: hold one back")
	assert_gt(queue.late_per_second(), 0)


func test_buffer_smooths_the_next_bunched_arrival() -> void:
	for i in 10:
		_tick(1)
	for i in 2:
		_tick(0)
		_tick(2)
	for i in 5:
		_tick(1)
	var taken: Array[int] = []
	for arriving in [0, 2, 1, 1]:
		taken.append(_tick(arriving))
	assert_eq(taken, [1, 1, 1, 1] as Array[int], "a late packet no longer stops the player")


func test_buffer_never_exceeds_max() -> void:
	for i in 40:
		_tick(0)
		_tick(0)
		_tick(0)
		_tick(3)
	assert_eq(queue.buffer_ticks, 2)


func test_buffer_shrinks_after_a_calm_spell() -> void:
	_tick(1)
	for i in 2:
		_tick(0)
		_tick(2)
	assert_eq(queue.buffer_ticks, 1)
	for i in 40:
		_tick(1)
	assert_eq(queue.buffer_ticks, 0)


func test_no_stalls_counted_before_the_first_input() -> void:
	for i in 10:
		queue.take_for_tick()
	assert_eq(queue.buffer_ticks, 0)
	assert_eq(queue.late_per_second(), 0)


func test_jitter_is_measured_from_arrival_times() -> void:
	var command := InputCommand.new()
	for i in 20:
		command = InputCommand.new()
		command.sequence = i + 1
		var late: float = 0.01 if i % 2 == 0 else 0.0
		queue.push([command] as Array[InputCommand], i * NetClock.tick_delta() + late)
	assert_almost_eq(queue.jitter.jitter_seconds(), 0.01, 0.0005)
