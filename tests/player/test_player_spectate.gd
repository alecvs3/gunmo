extends GutTest


func test_nobody_alive_means_nobody_to_watch() -> void:
	var none: Array[int] = []
	assert_eq(PlayerSpectate.next_peer(none, 0), 0)


func test_starts_with_the_lowest_id() -> void:
	var living: Array[int] = [300, 100, 200]
	assert_eq(PlayerSpectate.next_peer(living, 0), 100)


func test_cycles_in_a_stable_order() -> void:
	var living: Array[int] = [300, 100, 200]
	assert_eq(PlayerSpectate.next_peer(living, 100), 200)
	assert_eq(PlayerSpectate.next_peer(living, 200), 300)
	assert_eq(PlayerSpectate.next_peer(living, 300), 100, "wraps around")


func test_watched_player_gone_starts_over() -> void:
	var living: Array[int] = [100, 300]
	assert_eq(PlayerSpectate.next_peer(living, 200), 100)


func test_follow_time_settings_exist() -> void:
	var data: PlayerData = load("res://player/data/default_player.tres")
	assert_eq(data.camera_follow_time, 0.0, "own player: no camera lag")
	assert_gt(data.spectate_follow_time, 0.0, "teammates: smoothed")
