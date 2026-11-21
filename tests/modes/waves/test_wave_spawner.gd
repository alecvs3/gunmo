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
