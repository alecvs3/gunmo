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
	var spots: Array[Vector2] = WaveSpawner.split_positions(at, 2)
	assert_eq(spots.size(), 2)
	assert_ne(spots[0], spots[1])
	for spot in spots:
		assert_almost_eq(spot.distance_to(at), WaveSpawner.GROUP_SPREAD, 0.01)
