extends GutTest
## BotBrain's decisions.


func _candidate(id: int, position: Vector2, visible: bool = true) -> Dictionary:
	return {"id": id, "position": position, "visible": visible}


func test_choose_target_picks_the_nearest_visible_in_range() -> void:
	var candidates: Array[Dictionary] = [
		_candidate(2, Vector2(300, 0)),
		_candidate(3, Vector2(100, 0), false),
		_candidate(4, Vector2(200, 0)),
		_candidate(5, Vector2(900, 0)),
	]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 500.0, 0), 4)


func test_choose_target_none_when_nothing_visible_in_range() -> void:
	var candidates: Array[Dictionary] = [
		_candidate(2, Vector2(100, 0), false), _candidate(3, Vector2(900, 0))
	]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 500.0, 0), 0)


func test_choose_target_keeps_the_current_target_a_little_farther() -> void:
	var candidates: Array[Dictionary] = [
		_candidate(2, Vector2(560, 0)), _candidate(3, Vector2(450, 0))
	]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 500.0, 2), 2, "sticky")
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 500.0, 0), 3, "fresh pick")


func test_turn_towards_is_limited_per_tick_and_takes_the_short_way() -> void:
	assert_almost_eq(BotBrain.turn_towards(0.0, 1.0, 0.25), 0.25, 0.0001)
	assert_almost_eq(BotBrain.turn_towards(0.0, 0.1, 0.25), 0.1, 0.0001, "arrives")
	var across: float = BotBrain.turn_towards(PI - 0.1, -PI + 0.1, 0.05)
	assert_almost_eq(absf(across), PI - 0.05, 0.0001, "turns through PI, not through 0")


func test_aim_ready_within_the_cone_only() -> void:
	assert_true(BotBrain.aim_ready(0.0, 0.05, 0.1))
	assert_false(BotBrain.aim_ready(0.0, 0.2, 0.1))
	assert_true(BotBrain.aim_ready(PI - 0.02, -PI + 0.02, 0.1), "across the wrap")


func test_move_direction_closes_in_backs_off_and_strafes() -> void:
	var far: Vector2 = BotBrain.move_direction(Vector2.ZERO, Vector2(800, 0), 300.0, 0.0, 1.0)
	assert_gt(far.x, 0.9, "too far: walk in")
	var near: Vector2 = BotBrain.move_direction(Vector2.ZERO, Vector2(100, 0), 300.0, 0.0, 1.0)
	assert_lt(near.x, -0.9, "too close: back off")
	var side: Vector2 = BotBrain.move_direction(Vector2.ZERO, Vector2(300, 0), 300.0, 1.0, 1.0)
	assert_almost_eq(absf(side.y), 1.0, 0.0001, "at range with full strafe: sideways")
	var other: Vector2 = BotBrain.move_direction(Vector2.ZERO, Vector2(300, 0), 300.0, 1.0, -1.0)
	assert_almost_eq(side.y, -other.y, 0.0001, "strafe sign flips the side")
	assert_lte(BotBrain.move_direction(Vector2.ZERO, Vector2(9000, 0), 0.0, 0.5, 1.0).length(), 1.0)


func test_follow_path_skips_reached_points_and_stops_at_the_end() -> void:
	var path := PackedVector2Array([Vector2(5, 0), Vector2(100, 0)])
	var step: Array = BotBrain.follow_path(Vector2.ZERO, path, 0, 10.0)
	assert_eq(step[1], 1, "first point already reached")
	assert_almost_eq((step[0] as Vector2).x, 1.0, 0.0001)
	assert_eq(BotBrain.follow_path(Vector2(100, 0), path, 1, 10.0)[0], Vector2.ZERO)


func test_profiles_get_harder() -> void:
	var easy: BotProfile = load("res://bots/profiles/easy.tres")
	var hard: BotProfile = load("res://bots/profiles/hard.tres")
	assert_gt(easy.reaction_time, hard.reaction_time)
	assert_gt(easy.aim_error_degrees, hard.aim_error_degrees)
	assert_lt(easy.turn_speed_degrees, hard.turn_speed_degrees)
