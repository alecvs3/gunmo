extends GutTest
## ContactJudge: an enemy's contact square against a player's round hitbox (fair contact).

const HALF := Vector2(18, 18)
const RADIUS: float = 21.0


func test_touching() -> void:
	assert_true(ContactJudge.touches(Vector2.ZERO, HALF, Vector2(30, 0), RADIUS), "38 px reach")


func test_just_apart() -> void:
	assert_false(ContactJudge.touches(Vector2.ZERO, HALF, Vector2(40, 0), RADIUS))
	assert_almost_eq(ContactJudge.gap(Vector2.ZERO, HALF, Vector2(40, 0), RADIUS), 1.0, 0.001)


func test_corners_are_square_not_round() -> void:
	var corner := Vector2(18, 18) + Vector2(1, 1).normalized() * 20.0
	assert_true(ContactJudge.touches(Vector2.ZERO, HALF, corner, RADIUS), "20 px from the corner")


func test_a_bigger_enemy_reaches_further() -> void:
	assert_false(ContactJudge.touches(Vector2.ZERO, HALF, Vector2(55, 0), RADIUS))
	assert_true(ContactJudge.touches(Vector2.ZERO, HALF * 2.0, Vector2(55, 0), RADIUS), "scale 2")
