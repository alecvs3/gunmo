extends GutTest

const TICK: float = 1.0 / 60.0

var data: PlayerData


func before_each() -> void:
	data = PlayerData.new()
	data.move_speed = 240.0
	# Whole numbers of 60 Hz ticks: 12 and 6.
	data.acceleration_time = 0.2
	data.deceleration_time = 0.1


func test_reaches_top_speed_after_acceleration_time() -> void:
	var velocity: Vector2 = _run(Vector2.ZERO, Vector2.RIGHT, 0.1)
	assert_almost_eq(velocity.x, 120.0, 0.5, "half the time gives half the speed")
	velocity = _run(velocity, Vector2.RIGHT, 0.1)
	assert_almost_eq(velocity.x, 240.0, 0.5)


func test_never_exceeds_top_speed() -> void:
	var velocity: Vector2 = _run(Vector2.ZERO, Vector2.RIGHT, 1.0)
	assert_almost_eq(velocity.length(), 240.0, 0.001)


func test_stops_within_deceleration_time() -> void:
	var velocity: Vector2 = _run(Vector2(240, 0), Vector2.ZERO, 0.05)
	assert_almost_eq(velocity.x, 120.0, 0.5, "half the stop time gives half the speed")
	velocity = _run(velocity, Vector2.ZERO, 0.05)
	assert_eq(velocity, Vector2.ZERO)


func test_turning_around_uses_the_faster_rate() -> void:
	var velocity: Vector2 = _run(Vector2(240, 0), Vector2.LEFT, 0.1)
	assert_almost_eq(velocity.x, 0.0, 0.5, "reversing sheds speed at the deceleration rate")


func test_diagonal_is_not_faster() -> void:
	var velocity: Vector2 = _run(Vector2.ZERO, Vector2(1, 1), 1.0)
	assert_almost_eq(velocity.length(), 240.0, 0.001)


func test_oversized_input_is_clamped() -> void:
	var velocity: Vector2 = _run(Vector2.ZERO, Vector2(50, 0), 1.0)
	assert_almost_eq(velocity.x, 240.0, 0.001)


func test_zero_times_mean_instant() -> void:
	data.acceleration_time = 0.0
	data.deceleration_time = 0.0
	assert_eq(PlayerMotor.step(Vector2.ZERO, Vector2.RIGHT, TICK, data), Vector2(240, 0))
	assert_eq(PlayerMotor.step(Vector2(240, 0), Vector2.ZERO, TICK, data), Vector2.ZERO)


func test_same_inputs_give_same_result() -> void:
	var inputs: Array[Vector2] = [Vector2.RIGHT, Vector2(1, 1), Vector2.ZERO, Vector2.LEFT]
	assert_eq(_replay(inputs), _replay(inputs), "deterministic, as prediction needs")


func test_default_player_resource_values() -> void:
	var player_data: PlayerData = load("res://player/data/default_player.tres")
	assert_eq(player_data.move_speed, 220.0)
	assert_eq(player_data.acceleration_time, 0.12)
	assert_eq(player_data.deceleration_time, 0.08)


func _run(velocity: Vector2, input: Vector2, seconds: float) -> Vector2:
	for i in roundi(seconds / TICK):
		velocity = PlayerMotor.step(velocity, input, TICK, data)
	return velocity


func _replay(inputs: Array[Vector2]) -> Vector2:
	var velocity := Vector2.ZERO
	for input in inputs:
		for i in 10:
			velocity = PlayerMotor.step(velocity, input, TICK, data)
	return velocity
