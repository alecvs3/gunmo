extends GutTest

var history: PredictionHistory


func before_each() -> void:
	history = PredictionHistory.new()
	for sequence in range(1, 11):
		var command := InputCommand.new()
		command.sequence = sequence
		history.record(command)


func test_acknowledge_drops_confirmed_commands() -> void:
	history.acknowledge(6)
	assert_eq(history.size(), 4)
	assert_eq(history.pending()[0].sequence, 7)


func test_acknowledge_older_sequence_changes_nothing() -> void:
	history.acknowledge(6)
	history.acknowledge(3)
	assert_eq(history.size(), 4)


func test_recent_returns_newest_oldest_first() -> void:
	var recent: Array[InputCommand] = history.recent(3)
	assert_eq(recent.size(), 3)
	assert_eq(recent[0].sequence, 8)
	assert_eq(recent[2].sequence, 10)


func test_recent_with_few_commands() -> void:
	history.acknowledge(9)
	assert_eq(history.recent(4).size(), 1)


func test_capacity_drops_the_oldest() -> void:
	history.capacity = 5
	var command := InputCommand.new()
	command.sequence = 11
	history.record(command)
	assert_eq(history.size(), 5)
	assert_eq(history.pending()[0].sequence, 7)
