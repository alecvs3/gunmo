extends GutTest

var crowd := EnemyCrowd.new()


func _push(own: Vector2, own_scale: float, other: Vector2, other_scale: float) -> Vector2:
	var spots: Array[Vector2] = [other]
	var scales: Array[float] = [other_scale]
	return crowd.push(own, own_scale, spots, scales, 0)


func test_no_push_when_apart() -> void:
	assert_eq(_push(Vector2.ZERO, 1.0, Vector2(40, 0), 1.0), Vector2.ZERO)


func test_overlapping_enemies_push_away_from_each_other() -> void:
	var push: Vector2 = _push(Vector2.ZERO, 1.0, Vector2(10, 0), 1.0)
	assert_lt(push.x, 0.0, "pushed away from the neighbour on its right")
	assert_almost_eq(push.y, 0.0, 0.001)


func test_deeper_overlap_pushes_harder() -> void:
	var light: float = _push(Vector2.ZERO, 1.0, Vector2(20, 0), 1.0).length()
	var deep: float = _push(Vector2.ZERO, 1.0, Vector2(5, 0), 1.0).length()
	assert_gt(deep, light)


func test_a_boss_barely_moves_for_a_small_enemy() -> void:
	var boss: Vector2 = _push(Vector2.ZERO, 2.0, Vector2(30, 0), 1.0)
	var small: Vector2 = _push(Vector2(30, 0), 1.0, Vector2.ZERO, 2.0)
	assert_almost_eq(small.length(), boss.length() * 4.0, 0.01, "weight grows with area")


func test_equal_sizes_share_the_push() -> void:
	assert_almost_eq(EnemyCrowd.share(1.0, 1.0), 0.5, 0.0001)
	assert_almost_eq(EnemyCrowd.share(2.0, 1.0) + EnemyCrowd.share(1.0, 2.0), 1.0, 0.0001)


func test_standing_on_the_same_spot_still_separates() -> void:
	var spots: Array[Vector2] = [Vector2(5, 5)]
	var scales: Array[float] = [1.0]
	var a: Vector2 = crowd.push(Vector2(5, 5), 1.0, spots, scales, 10)
	var b: Vector2 = crowd.push(Vector2(5, 5), 1.0, spots, scales, 190)
	assert_gt(a.length(), 0.0)
	assert_almost_eq(a.normalized().dot(b.normalized()), -1.0, 0.001, "different ids, apart")


func test_push_is_capped() -> void:
	var spots: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
	var scales: Array[float] = [3.0, 3.0, 3.0]
	var push: Vector2 = crowd.push(Vector2.ZERO, 1.0, spots, scales, 0)
	assert_almost_eq(push.length(), crowd.max_speed, 0.01)


func test_small_enemies_cant_walk_through_a_boss() -> void:
	var fastest: float = 270.0 * 1.8
	assert_gt(crowd.max_speed, fastest, "a Swarmer in a Fast wave is pushed back out")
	assert_lt(crowd.strength * 2.0 / 60.0, 1.0, "a pair never overshoots in one tick")


func test_default_tuning_file_loads() -> void:
	var loaded: EnemyCrowd = load("res://enemies/behaviours/data/crowd.tres")
	assert_not_null(loaded)
	assert_eq(ChaserEnemy.CROWD, loaded)


func test_enemies_only_collide_with_walls() -> void:
	var enemy: ChaserEnemy = load("res://enemies/chaser.tscn").instantiate()
	assert_eq(enemy.collision_mask, ChaserEnemy.WORLD_MASK)
	var area := enemy.get_node("Crowd") as Area2D
	assert_eq(area.collision_mask, enemy.collision_layer, "the crowd area sees enemy bodies")
	enemy.free()
