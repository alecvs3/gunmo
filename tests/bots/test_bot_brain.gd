extends GutTest
## BotBrain's decisions.


func _candidate(id: int, position: Vector2, visible: bool = true) -> BotBrain.Candidate:
	return BotBrain.Candidate.new(id, position, visible)


func test_choose_target_picks_the_nearest_visible_in_range() -> void:
	var candidates: Array[BotBrain.Candidate] = [
		_candidate(2, Vector2(300, 0)),
		_candidate(3, Vector2(100, 0), false),
		_candidate(4, Vector2(200, 0)),
		_candidate(5, Vector2(900, 0)),
	]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 500.0, 0), 4)


func test_choose_target_none_when_nothing_visible_in_range() -> void:
	var candidates: Array[BotBrain.Candidate] = [
		_candidate(2, Vector2(100, 0), false), _candidate(3, Vector2(900, 0))
	]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 500.0, 0), 0)


func test_choose_target_keeps_the_current_target_a_little_farther() -> void:
	var candidates: Array[BotBrain.Candidate] = [
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


func test_the_most_dangerous_for_its_distance_wins() -> void:
	var grunt := BotBrain.Candidate.new(1, Vector2(200, 0), true, 1.0)
	var support := BotBrain.Candidate.new(2, Vector2(400, 0), true, 4.0)
	var candidates: Array[BotBrain.Candidate] = [grunt, support]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 800.0, 0), 2, "4/400 beats 1/200")
	support.danger = 1.5
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 800.0, 0), 1)
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 800.0, 1), 1, "keeps its target")


func test_equal_danger_still_means_nearest() -> void:
	var near := BotBrain.Candidate.new(1, Vector2(10, 0), true)
	var far := BotBrain.Candidate.new(2, Vector2(50, 0), true)
	var candidates: Array[BotBrain.Candidate] = [far, near]
	assert_eq(BotBrain.choose_target(Vector2.ZERO, candidates, 800.0, 0), 1)


func test_regroup_goes_to_the_team_centre_when_too_far() -> void:
	var team: Array[Vector2] = [Vector2(400, 0), Vector2(600, 0)]
	assert_eq(BotBrain.regroup_goal(Vector2.ZERO, team, 300.0), Vector2(500, 0))
	assert_eq(BotBrain.regroup_goal(Vector2(450, 0), team, 300.0), Vector2.INF, "close enough")
	assert_eq(BotBrain.regroup_goal(Vector2.ZERO, [] as Array[Vector2], 300.0), Vector2.INF)


func test_revive_the_nearest_downed_teammate_in_reach() -> void:
	var downed: Array[Vector2] = [Vector2(800, 0), Vector2(300, 0), Vector2(2000, 0)]
	assert_eq(BotBrain.revive_target(Vector2.ZERO, downed, 900.0), 1)
	assert_eq(BotBrain.revive_target(Vector2.ZERO, [Vector2(2000, 0)] as Array[Vector2], 900.0), -1)
	assert_true(BotBrain.can_revive(Vector2.ZERO, Vector2(40, 0), 45.0))
	assert_false(BotBrain.can_revive(Vector2.ZERO, Vector2(60, 0), 45.0))


func test_dodge_steps_off_the_line_of_a_bullet_about_to_hit() -> void:
	var bullet := BotBrain.Threat.new(Vector2(-200, 5), Vector2.RIGHT, 800.0)
	var threats: Array[BotBrain.Threat] = [bullet]
	var away: Vector2 = BotBrain.dodge(Vector2.ZERO, threats, 30.0, 0.5)
	assert_almost_eq(away, Vector2(0, -1), Vector2(0.01, 0.01), "the bullet passes below: go up")


func test_dodge_ignores_bullets_that_miss_are_past_or_far_off() -> void:
	var miss := BotBrain.Threat.new(Vector2(-200, 80), Vector2.RIGHT, 800.0)
	var past := BotBrain.Threat.new(Vector2(100, 0), Vector2.RIGHT, 800.0)
	var slow := BotBrain.Threat.new(Vector2(-400, 0), Vector2.RIGHT, 200.0)
	var threats: Array[BotBrain.Threat] = [miss, past, slow]
	assert_eq(BotBrain.dodge(Vector2.ZERO, threats, 30.0, 0.5), Vector2.ZERO)


func test_dodge_a_bullet_dead_on_goes_sideways() -> void:
	var threats: Array[BotBrain.Threat] = [
		BotBrain.Threat.new(Vector2(-100, 0), Vector2.RIGHT, 500.0)
	]
	var away: Vector2 = BotBrain.dodge(Vector2.ZERO, threats, 30.0, 0.5)
	assert_almost_eq(absf(away.y), 1.0, 0.01)


func test_barrel_aim_puts_the_shot_through_the_target() -> void:
	var muzzle := Vector2(33, 10)
	var target := Vector2(300, 0)
	var aim: float = BotBrain.barrel_aim(Vector2.ZERO, muzzle, target)
	var origin: Vector2 = muzzle.rotated(aim)
	var direction := Vector2.RIGHT.rotated(aim)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
		target, origin, origin + direction * 1000.0
	)
	assert_lt(closest.distance_to(target), 0.5, "the barrel's line passes through the target")
	assert_lt(aim, 0.0, "a barrel to the right turns the aim slightly left")
	assert_eq(BotBrain.barrel_aim(Vector2.ZERO, muzzle, Vector2(5, 0)), 0.0, "point blank")


func test_cover_is_the_nearest_spot_out_of_sight() -> void:
	var spots: Array[Vector2] = [Vector2(100, 0), Vector2(300, 0), Vector2(600, 0)]
	assert_eq(BotBrain.cover_point(Vector2.ZERO, spots, [true, false, false]), Vector2(300, 0))
	assert_eq(BotBrain.cover_point(Vector2.ZERO, spots, [true, true, true]), Vector2.INF)


func test_flank_comes_in_from_the_side() -> void:
	var target := Vector2(1000, 0)
	var flank: Vector2 = BotBrain.flank_point(Vector2.ZERO, target, 1.0, PI / 2.0, 300.0)
	assert_almost_eq(flank, Vector2(1000, -300), Vector2(0.01, 0.01))
	var other: Vector2 = BotBrain.flank_point(Vector2.ZERO, target, -1.0, PI / 2.0, 300.0)
	assert_almost_eq(other, Vector2(1000, 300), Vector2(0.01, 0.01))
	var straight: Vector2 = BotBrain.flank_point(Vector2.ZERO, target, 1.0, 0.0, 300.0)
	assert_almost_eq(straight, Vector2(700, 0), Vector2(0.01, 0.01))
