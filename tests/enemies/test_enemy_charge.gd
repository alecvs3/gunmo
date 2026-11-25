extends GutTest
## A Charger's dash: when it starts (ChargeAttack) and how it ends (EnemyDash).


func _charge() -> ChargeAttack:
	var charge := ChargeAttack.new()
	charge.interval = 1.0
	charge.windup = 0.8
	charge.trigger_range = 300.0
	charge.dash_speed = 600.0
	charge.dash_distance = 300.0
	charge.damage = 25
	charge.stun_seconds = 1.5
	charge.stun_damage_bonus = 0.5
	charge.recover_seconds = 0.4
	return charge


func _dashing() -> EnemyDash:
	var dash := EnemyDash.new()
	dash.start(_charge(), Vector2(10, 0))
	return dash


func test_charges_only_at_a_close_target_it_can_see() -> void:
	var charge: ChargeAttack = _charge()
	assert_true(charge.wants_to_attack(0.0, 250.0, true))
	assert_false(charge.wants_to_attack(0.0, 350.0, true), "too far")
	assert_false(charge.wants_to_attack(0.0, 250.0, false), "behind a wall")
	assert_false(charge.wants_to_attack(0.3, 250.0, true), "cooling down")
	assert_true(charge.needs_line_of_sight())
	assert_true(charge.stands_still_while_winding_up(), "it stops to warn")
	assert_false(MeleeAttack.new().stands_still_while_winding_up(), "others keep walking")


func test_a_dash_counts_in_its_cycle() -> void:
	# 1.0 cooldown + 0.8 windup + 0.5 s dash (300 px at 600 px/s) + 0.4 recover
	assert_almost_eq(_charge().cycle_seconds(), 2.7, 0.001)
	var stats := EnemyStats.new()
	_charge().add_stats(stats, 1.0)
	assert_almost_eq(stats.value(EnemyStats.MELEE_DPS), 25.0 / 2.7, 0.001)


func test_dash_goes_straight_its_full_distance_then_recovers() -> void:
	var dash: EnemyDash = _dashing()
	assert_true(dash.is_busy())
	assert_eq(dash.velocity(), Vector2(600, 0), "locked direction, dash speed")
	for i in 29:
		dash.step(1.0 / 60.0)
	assert_true(dash.is_dashing(), "300 px take half a second")
	dash.step(2.0 / 60.0)
	assert_eq(dash.state, EnemyDash.State.RECOVERING)
	assert_eq(dash.velocity(), Vector2.ZERO)
	dash.step(0.41)
	assert_false(dash.is_busy(), "free to walk again")


func test_a_head_on_wall_stuns_but_a_scrape_does_not() -> void:
	var dash: EnemyDash = _dashing()
	assert_false(dash.hit_wall(Vector2(0, -1)), "scraping along a wall")
	assert_false(dash.hit_wall(Vector2(-0.3, -0.95).normalized()), "glancing blow")
	assert_true(dash.hit_wall(Vector2(-1, 0)), "straight into it")
	assert_true(dash.is_stunned())
	assert_almost_eq(dash.damage_factor(), 1.5, 0.001, "takes more damage while stunned")
	dash.step(1.4)
	assert_true(dash.is_stunned())
	dash.step(0.2)
	assert_false(dash.is_busy())
	assert_almost_eq(dash.damage_factor(), 1.0, 0.001)


func test_hitting_a_player_ends_the_dash_without_a_stun() -> void:
	var dash: EnemyDash = _dashing()
	dash.hit_player()
	assert_eq(dash.state, EnemyDash.State.RECOVERING)
	assert_false(dash.hit_wall(Vector2(-1, 0)), "no stun once the dash is over")


func test_idle_dash_changes_nothing() -> void:
	var dash := EnemyDash.new()
	assert_false(dash.is_busy())
	assert_almost_eq(dash.damage_factor(), 1.0, 0.001)
	dash.hit_player()
	dash.step(1.0)
	assert_false(dash.is_busy())
