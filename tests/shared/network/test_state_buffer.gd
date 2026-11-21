extends GutTest

var buffer: StateBuffer


func _state(x: float) -> EnemyNetState:
	var state := EnemyNetState.new()
	state.position = Vector2(x, 0)
	return state


func before_each() -> void:
	buffer = StateBuffer.new()


func _x(render_tick: float) -> float:
	return (buffer.sample(render_tick) as EnemyNetState).position.x


func test_empty_buffer_samples_nothing() -> void:
	assert_null(buffer.sample(10.0))


func test_blends_between_surrounding_states() -> void:
	buffer.push(10, _state(0))
	buffer.push(12, _state(100))
	assert_almost_eq(_x(11.0), 50.0, 0.001)
	assert_almost_eq(_x(11.5), 75.0, 0.001)


func test_holds_ends_instead_of_guessing() -> void:
	buffer.push(10, _state(0))
	buffer.push(12, _state(100))
	assert_eq(_x(5.0), 0.0)
	assert_eq(_x(20.0), 100.0)


func test_out_of_order_and_duplicate_pushes() -> void:
	buffer.push(14, _state(200))
	buffer.push(10, _state(0))
	buffer.push(12, _state(100))
	buffer.push(12, _state(999))
	assert_almost_eq(_x(13.0), 150.0, 0.001)
	assert_eq(buffer.latest_tick(), 14)


func test_old_states_are_dropped_as_time_moves_on() -> void:
	for tick in range(0, 20, 2):
		buffer.push(tick, _state(tick))
	_x(15.0)
	buffer.push(9, _state(-1))
	assert_almost_eq(_x(15.0), 15.0, 0.001, "a stale state can't disturb the present")


func test_capacity() -> void:
	buffer.capacity = 4
	for tick in 10:
		buffer.push(tick, _state(tick))
	assert_eq(_x(0.0), 6.0, "only the newest 4 kept")
