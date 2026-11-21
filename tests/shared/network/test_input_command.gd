extends GutTest


func _command(sequence: int) -> InputCommand:
	var command := InputCommand.new()
	command.sequence = sequence
	command.move = Vector2(0.5, -1.0).limit_length(1.0)
	command.aim = 1.2345678901234
	command.buttons = InputCommand.FIRE
	command.view_tick = 1234.5
	return command


func test_batch_round_trip_is_exact() -> void:
	var commands: Array[InputCommand] = [_command(1), _command(2), _command(3)]
	var decoded: Array[InputCommand] = InputCommand.decode_batch(
		InputCommand.encode_batch(commands)
	)
	assert_eq(decoded.size(), 3)
	for i in 3:
		assert_eq(decoded[i].sequence, commands[i].sequence)
		assert_eq(decoded[i].move, commands[i].move, "prediction needs bit-exact input")
		assert_eq(decoded[i].aim, commands[i].aim)
		assert_eq(decoded[i].buttons, commands[i].buttons)
		assert_eq(decoded[i].view_tick, commands[i].view_tick)


func test_batch_keeps_only_the_newest_when_too_many() -> void:
	var commands: Array[InputCommand] = []
	for i in InputCommand.MAX_PER_PACKET + 5:
		commands.append(_command(i))
	var decoded: Array[InputCommand] = InputCommand.decode_batch(
		InputCommand.encode_batch(commands)
	)
	assert_eq(decoded.size(), InputCommand.MAX_PER_PACKET)
	assert_eq(decoded.back().sequence, InputCommand.MAX_PER_PACKET + 4)


func test_malformed_packets_decode_to_nothing() -> void:
	assert_eq(InputCommand.decode_batch(PackedByteArray()).size(), 0)
	assert_eq(InputCommand.decode_batch(PackedByteArray([2, 1, 2, 3])).size(), 0, "too short")
	var data: PackedByteArray = InputCommand.encode_batch([_command(1)])
	data.append(0)
	assert_eq(InputCommand.decode_batch(data).size(), 0, "trailing bytes")


func test_sanitized_fixes_hostile_values() -> void:
	var bad := InputCommand.new()
	bad.move = Vector2(50, 0)
	bad.aim = INF
	bad.buttons = 0xFF
	bad.view_tick = NAN
	var clean: InputCommand = bad.sanitized()
	assert_almost_eq(clean.move.length(), 1.0, 0.0001)
	assert_eq(clean.aim, 0.0)
	assert_eq(clean.buttons, InputCommand.ALL_BUTTONS)
	assert_eq(clean.view_tick, 0.0)
	bad.move = Vector2(NAN, 1)
	assert_eq(bad.sanitized().move, Vector2.ZERO)


func test_has_buttons() -> void:
	var command := _command(1)
	assert_true(command.has(InputCommand.FIRE))
	assert_false(command.has(InputCommand.RELOAD))
