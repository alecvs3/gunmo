extends GutTest


func test_reset_and_apply_replicated() -> void:
	var score := ScoreComponent.new()
	autofree(score)
	score.apply_replicated(5, 2, 3, 1)
	assert_eq([score.kills, score.deaths, score.tier, score.tier_kills], [5, 2, 3, 1])
	score.reset()
	assert_eq([score.kills, score.deaths, score.tier, score.tier_kills], [0, 0, 0, 0])
