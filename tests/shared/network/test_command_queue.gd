extends GutTest

var queue: CommandQueue


func before_each() -> void:
	queue = CommandQueue.new()
	queue.budget_cap = 4
	queue.max_per_tick = 2
	queue.max_pending = 16


func _commands(first: int, last: int) -> Array[InputCommand]:
	var commands: Array[InputCommand] = []
	for sequence in range(first, last + 1):
		var command := InputCommand.new()
		command.sequence = sequence
		commands.append(command)
	return commands


func _sequences(commands: Array[InputCommand]) -> Array[int]:
	var sequences: Array[int] = []
	for command in commands:
		sequences.append(command.sequence)
	return sequences


func test_redundant_copies_are_dropped() -> void:
	queue.push(_commands(1, 4))
	queue.push(_commands(2, 5))
	queue.push(_commands(3, 6))
	assert_eq(queue.pending_count(), 6)
	assert_eq(queue.last_received, 6)


func test_one_command_per_tick_in_order() -> void:
	queue.push(_commands(1, 3))
	assert_eq(_sequences(queue.take_for_tick()), [1])
	assert_eq(_sequences(queue.take_for_tick()), [2])
	assert_eq(_sequences(queue.take_for_tick()), [3])
	assert_eq(queue.take_for_tick().size(), 0)


func test_late_packets_catch_up_using_saved_budget() -> void:
	for i in 3:
		assert_eq(queue.take_for_tick().size(), 0, "nothing arrived yet")
	queue.push(_commands(1, 4))
	assert_eq(_sequences(queue.take_for_tick()), [1, 2], "two this tick")
	assert_eq(_sequences(queue.take_for_tick()), [3, 4])


func test_flood_is_never_faster_than_real_time() -> void:
	var simulated: int = 0
	var next: int = 1
	for tick in 120:
		queue.push(_commands(next, next + 4))
		next += 5
		simulated += queue.take_for_tick().size()
	assert_lte(simulated, 120 + queue.budget_cap, "at most one per tick on average")


func test_backlog_is_capped() -> void:
	queue.push(_commands(1, 40))
	assert_eq(queue.pending_count(), 16)
	assert_eq(_sequences(queue.take_for_tick()), [25], "oldest dropped, newest kept")


func test_commands_are_sanitized_on_arrival() -> void:
	var hostile: Array[InputCommand] = _commands(1, 1)
	hostile[0].move = Vector2(9, 9)
	queue.push(hostile)
	assert_almost_eq(queue.take_for_tick()[0].move.length(), 1.0, 0.0001)
