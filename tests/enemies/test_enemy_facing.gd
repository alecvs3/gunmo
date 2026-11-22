extends GutTest
## EnemyFacing: faces where it walks, flinches towards a push and recovers.

const TICK: float = 1.0 / 60.0

var facing: EnemyFacing


func before_each() -> void:
	facing = EnemyFacing.new()
	facing.configure(30.0, 0.25)
	facing.rng.seed = 7


func test_faces_where_it_walks_and_keeps_it_when_standing() -> void:
	facing.walk_towards(Vector2.DOWN * 140.0)
	assert_almost_eq(facing.angle(), PI / 2.0, 0.0001)
	facing.walk_towards(Vector2.ZERO)
	assert_almost_eq(facing.angle(), PI / 2.0, 0.0001, "standing still keeps the facing")


func test_flinches_towards_the_side_it_was_pushed() -> void:
	facing.walk_towards(Vector2.RIGHT)
	facing.flinch_from(Vector2(-100, 100))
	assert_almost_eq(facing.angle(), deg_to_rad(30.0), 0.0001, "pushed to its right: turns right")
	facing.flinch_from(Vector2(-100, -100))
	assert_almost_eq(facing.angle(), -deg_to_rad(30.0), 0.0001, "pushed to its left: turns left")


func test_flinch_wears_off_over_the_recovery_time() -> void:
	facing.walk_towards(Vector2.RIGHT)
	facing.flinch_from(Vector2(0, 100))
	for i in 7:
		facing.step(TICK)
	assert_gt(facing.angle(), 0.0, "still flinching after 7 of 15 ticks")
	for i in 8:
		facing.step(TICK)
	assert_almost_eq(facing.angle(), 0.0, 0.0001, "back after 0.25 s")


func test_straight_on_pushes_turn_both_ways() -> void:
	facing.walk_towards(Vector2.RIGHT)
	var lefts: int = 0
	var rights: int = 0
	for i in 40:
		facing.flinch_from(Vector2(-300, 0))
		if facing.angle() > 0.0:
			rights += 1
		else:
			lefts += 1
	assert_gt(lefts, 5, "not always right")
	assert_gt(rights, 5, "not always left")


func test_no_flinch_when_turned_off() -> void:
	facing.configure(0.0, 0.25)
	facing.walk_towards(Vector2.RIGHT)
	facing.flinch_from(Vector2(0, 100))
	assert_eq(facing.angle(), 0.0)
