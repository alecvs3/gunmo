extends GutTest

var data: SoldierData


func before_each() -> void:
	data = load("res://pets/data/soldier.tres")


func test_drill_and_last_stand_damage() -> void:
	assert_eq(SoldierRules.damage_bonus(data, 0, true), 0.0)
	assert_eq(SoldierRules.damage_bonus(data, 1, false), data.drill_bonus)
	assert_eq(
		SoldierRules.damage_bonus(data, 2, true), data.drill_bonus_upgraded, "no last stand yet"
	)
	assert_almost_eq(
		SoldierRules.damage_bonus(data, 4, true),
		data.drill_bonus_upgraded + data.last_stand_damage,
		1e-6
	)
	assert_eq(SoldierRules.move_bonus(data, 4, false), 0.0, "only while a teammate is down")
	assert_eq(SoldierRules.move_bonus(data, 4, true), data.last_stand_move)


func test_rally_every_n_kills() -> void:
	assert_false(SoldierRules.rally_ready(data, 1, 50), "not before tier 2")
	assert_false(SoldierRules.rally_ready(data, 2, data.rally_kills - 1))
	assert_true(SoldierRules.rally_ready(data, 2, data.rally_kills))
	assert_eq(SoldierRules.rally_fire_rate(data, 2), data.rally_fire_rate)
	assert_eq(SoldierRules.rally_fire_rate(data, 5), data.rally_fire_rate_upgraded)
	assert_false(SoldierRules.rally_includes_owner(3))
	assert_true(SoldierRules.rally_includes_owner(4))


func test_covering_fire_from_tier_3() -> void:
	assert_eq(SoldierRules.cover_damage(data, 2, 40), 0)
	assert_eq(SoldierRules.cover_damage(data, 3, 40), 10, "25% of the gun")
	assert_eq(SoldierRules.cover_damage(data, 3, 1), 1, "at least 1")


func test_airstrike_needs_a_streak_in_the_window() -> void:
	var rate: int = NetClock.tick_rate()
	var streak: Array[int] = []
	for i in data.airstrike_kills:
		streak.append(i * rate / 2)
	var now: int = streak.back()
	assert_true(SoldierRules.airstrike_ready(data, 5, streak, now))
	assert_false(SoldierRules.airstrike_ready(data, 4, streak, now), "not before tier 5")
	assert_false(
		SoldierRules.airstrike_ready(data, 5, streak, now + 20 * rate), "the kills are too old"
	)
	assert_false(SoldierRules.airstrike_ready(data, 5, streak.slice(1), now), "one short")


func test_airstrike_damage_and_line() -> void:
	assert_eq(SoldierRules.airstrike_damage(data, 10, false), 500)
	assert_eq(SoldierRules.airstrike_damage(data, 10, true), 125, "a quarter on bosses")
	assert_true(SoldierRules.under_strike(Vector2(300, 40), Vector2.ZERO, Vector2(600, 0), 50.0))
	assert_false(SoldierRules.under_strike(Vector2(300, 60), Vector2.ZERO, Vector2(600, 0), 50.0))
	assert_false(SoldierRules.under_strike(Vector2(700, 0), Vector2.ZERO, Vector2(600, 0), 50.0))
