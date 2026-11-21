extends GutTest

var ladder: GunGameLadder
var score: ScoreComponent


func before_each() -> void:
	ladder = GunGameLadder.new()
	ladder.configure(3, 2, 1)
	score = autofree(ScoreComponent.new())


func test_kills_on_a_tier_until_the_target_then_advance() -> void:
	assert_eq(ladder.record_kill(score), GunGameLadder.Result.STAYED)
	assert_eq([score.tier, score.tier_kills], [0, 1])
	assert_eq(ladder.record_kill(score), GunGameLadder.Result.ADVANCED)
	assert_eq([score.tier, score.tier_kills], [1, 0], "next gun, kills start over")


func test_finishing_the_last_gun_wins() -> void:
	for i in 4:
		ladder.record_kill(score)
	assert_eq(score.tier, 2, "on the last gun after 2 + 2 kills")
	assert_eq(ladder.record_kill(score), GunGameLadder.Result.FINISHED, "1 kill on the last")


func test_kills_needed_uses_the_final_target_on_the_last_tier() -> void:
	assert_eq(ladder.kills_needed(0), 2)
	assert_eq(ladder.kills_needed(2), 1)


func test_single_gun_ladder_finishes_on_its_final_target() -> void:
	ladder.configure(1, 5, 2)
	assert_eq(ladder.record_kill(score), GunGameLadder.Result.STAYED)
	assert_eq(ladder.record_kill(score), GunGameLadder.Result.FINISHED)


func test_configure_never_allows_zero() -> void:
	ladder.configure(0, 0, 0)
	assert_eq([ladder.length, ladder.kills_per_tier, ladder.final_tier_kills], [1, 1, 1])


func test_catalog_indices_follow_the_ladder() -> void:
	var catalog: ShopCatalog = ShopCatalog.load_default()
	var ladder_guns: Array[WeaponData] = [
		catalog.weapons[2], catalog.weapons[0], catalog.weapons[2]
	]
	assert_eq(GunGameMode._catalog_indices(ladder_guns), [2, 0, 2] as Array[int])


func test_default_gun_game_match_is_valid() -> void:
	var settings: MatchSettings = load("res://modes/data/gun_game_match.tres")
	assert_not_null(settings.mode_scene)
	assert_gt(settings.ladder.size(), 1)
	assert_eq(GunGameMode._catalog_indices(settings.ladder).size(), settings.ladder.size())
