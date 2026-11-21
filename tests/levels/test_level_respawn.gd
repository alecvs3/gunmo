extends GutTest


func test_farthest_from_picks_the_point_whose_nearest_player_is_farthest() -> void:
	var candidates: Array[Vector2] = [Vector2(0, 0), Vector2(500, 0), Vector2(1000, 0)]
	var others: Array[Vector2] = [Vector2(10, 0), Vector2(900, 0)]
	assert_eq(Level.farthest_from(candidates, others), Vector2(500, 0))


func test_farthest_from_with_nobody_to_avoid_is_the_first() -> void:
	var candidates: Array[Vector2] = [Vector2(5, 5), Vector2(50, 50)]
	assert_eq(Level.farthest_from(candidates, []), Vector2(5, 5))
