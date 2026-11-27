extends GutTest

var rng := RandomNumberGenerator.new()
var points: Array[Vector2] = [Vector2(0, 0), Vector2(1000, 0), Vector2(0, 1000)]


func test_picks_only_points_far_from_players() -> void:
	var players: Array[Vector2] = [Vector2(50, 50)]
	for i in 20:
		var chosen: Vector2 = WaveSpawner.pick_spawn_position(points, players, 400.0, rng)
		assert_ne(chosen, Vector2(0, 0), "the corner next to the player is never used")


func test_falls_back_to_the_furthest_point() -> void:
	var players: Array[Vector2] = [Vector2(500, 500)]
	var chosen: Vector2 = WaveSpawner.pick_spawn_position(points, players, 5000.0, rng)
	assert_eq(chosen, Vector2(0, 0), "all too close: the one furthest from its nearest player")


func test_no_players_any_point() -> void:
	var none: Array[Vector2] = []
	assert_has(points, WaveSpawner.pick_spawn_position(points, none, 400.0, rng))


func test_group_count_takes_one_group_within_room() -> void:
	var swarm := EnemyData.new()
	swarm.group_size = 3
	var lone := EnemyData.new()
	var queue: Array[EnemyData] = [swarm, swarm, swarm, swarm, lone]
	assert_eq(WaveSpawner.group_count(queue, 40), 3, "one group, not the next one too")
	assert_eq(WaveSpawner.group_count(queue, 2), 2, "never past max_alive")
	assert_eq(WaveSpawner.group_count([lone, lone] as Array[EnemyData], 40), 1)
	assert_eq(WaveSpawner.group_count([] as Array[EnemyData], 40), 0)


func test_group_members_stand_apart() -> void:
	assert_eq(WaveSpawner.group_offset(0, 5), Vector2.ZERO)
	var a: Vector2 = WaveSpawner.group_offset(1, 5)
	var b: Vector2 = WaveSpawner.group_offset(2, 5)
	assert_almost_eq(a.length(), WaveSpawner.GROUP_SPREAD, 0.01)
	assert_gt(a.distance_to(b), 20.0)


func test_split_positions_are_around_the_parent() -> void:
	var at := Vector2(500, 300)
	var spots: Array[Vector2] = WaveSpawner.split_positions(at, 2, 20.0, 20.0)
	assert_eq(spots.size(), 2)
	assert_ne(spots[0], spots[1])
	for spot in spots:
		assert_almost_eq(spot.distance_to(at), WaveSpawner.split_radius(2, 20.0, 20.0), 0.01)


func test_summons_appear_outside_the_brood_mother() -> void:
	var boss: EnemyData = load("res://enemies/data/bosses/brood_mother.tres")
	var swarmer: EnemyData = load("res://enemies/data/swarmer.tres")
	var at := Vector2(500, 300)
	var spots: Array[Vector2] = WaveSpawner.split_positions(
		at, 4, ChaserEnemy.body_reach(boss), ChaserEnemy.body_reach(swarmer)
	)
	for spot in spots:
		assert_false(_boxes_overlap(at, boss, spot, swarmer), "a summon starts clear of the boss")


func test_many_children_stand_apart() -> void:
	var small: EnemyData = load("res://enemies/data/splitling.tres")
	var spots: Array[Vector2] = WaveSpawner.split_positions(
		Vector2.ZERO, 12, ChaserEnemy.body_reach(small), ChaserEnemy.body_reach(small)
	)
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_false(_boxes_overlap(spots[i], small, spots[j], small), "siblings start apart")


func test_body_reach_matches_the_scene() -> void:
	var enemy: ChaserEnemy = load("res://enemies/chaser.tscn").instantiate()
	var shape := (enemy.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_eq(shape.size, Vector2.ONE * ChaserEnemy.BODY_HALF_SIZE * 2.0)
	enemy.free()


## Whether two enemies' collision boxes (axis-aligned squares) overlap.
func _boxes_overlap(a: Vector2, a_data: EnemyData, b: Vector2, b_data: EnemyData) -> bool:
	var reach: float = ChaserEnemy.BODY_HALF_SIZE * (a_data.body_scale + b_data.body_scale)
	return absf(a.x - b.x) < reach and absf(a.y - b.y) < reach
