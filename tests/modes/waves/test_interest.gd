extends GutTest

var settings: MatchSettings


func before_each() -> void:
	settings = MatchSettings.new()
	settings.interest_step = 100
	settings.interest_per_step = 10
	settings.interest_cap = 50


func test_pays_per_whole_step_held() -> void:
	assert_eq(Interest.amount(100, settings), 10)
	assert_eq(Interest.amount(300, settings), 30)


func test_rounds_down_to_whole_steps() -> void:
	assert_eq(Interest.amount(99, settings), 0, "under one step")
	assert_eq(Interest.amount(199, settings), 10)
	assert_eq(Interest.amount(0, settings), 0)
	assert_eq(Interest.amount(-50, settings), 0, "never negative")


func test_stops_at_the_cap() -> void:
	assert_eq(Interest.amount(500, settings), 50)
	assert_eq(Interest.amount(10000, settings), 50, "hoarding more pays no more")


func test_off_when_any_setting_is_zero() -> void:
	assert_eq(Interest.amount(500, MatchSettings.new()), 0, "off by default in the class")
	for field in ["interest_step", "interest_per_step", "interest_cap"]:
		var off: MatchSettings = settings.duplicate()
		off.set(field, 0)
		assert_eq(Interest.amount(500, off), 0, "%s = 0 turns it off" % field)


func test_default_match_pays_50_on_500() -> void:
	var real: MatchSettings = load("res://modes/data/default_match.tres")
	assert_eq(Interest.amount(500, real), 50)
