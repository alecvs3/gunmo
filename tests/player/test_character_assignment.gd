extends GutTest


func test_nobody_looks_alike_while_looks_last() -> void:
	var taken: Array[int] = []
	for i in 6:
		var pick: int = CharacterAssignment.pick(taken, [0, 1, 2, 3] as Array[int], 6, i)
		assert_does_not_have(taken, pick, "player %d got a look nobody has" % i)
		taken.append(pick)
	assert_eq(taken.size(), 6)


func test_preferred_looks_come_first() -> void:
	assert_eq(CharacterAssignment.pick([] as Array[int], [4, 5] as Array[int], 6, 0), 4)
	assert_eq(CharacterAssignment.pick([4] as Array[int], [4, 5] as Array[int], 6, 0), 5)
	assert_eq(CharacterAssignment.pick([4, 5] as Array[int], [4, 5] as Array[int], 6, 0), 0)


func test_repeats_only_when_all_are_taken() -> void:
	var all: Array[int] = [0, 1, 2]
	assert_eq(CharacterAssignment.pick(all, [] as Array[int], 3, 7), 1, "7 mod 3")
	assert_eq(CharacterAssignment.pick([] as Array[int], [] as Array[int], 0, 7), -1)


func test_default_looks_split_humans_and_bots() -> void:
	var data: PlayerData = load("res://player/data/default_player.tres")
	var humans: Array[int] = data.preferred_looks(false)
	var bots: Array[int] = data.preferred_looks(true)
	assert_eq(humans.size(), data.player_looks.size())
	assert_eq(bots[0], data.player_looks.size(), "bot looks come after the human ones")
	assert_eq(data.all_looks().size(), humans.size() + bots.size())


func test_kill_feed_text() -> void:
	assert_eq(KillFeed.entry_text("Alex", "SMG", "Yusuf"), "Alex [SMG] Yusuf")
	assert_eq(KillFeed.entry_text("", "", "Yusuf"), "Yusuf died")
	assert_eq(KillFeed.entry_text("Alex", "", "Yusuf"), "Alex killed Yusuf")
