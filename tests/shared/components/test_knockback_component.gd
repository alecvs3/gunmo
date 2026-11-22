extends GutTest

const TICK: float = 1.0 / 60.0

var knockback: KnockbackComponent


func before_each() -> void:
	knockback = KnockbackComponent.new()
	knockback.configure(2400.0, 0.3, 1.0)
	add_child_autofree(knockback)


func test_impulse_scaled_by_taken() -> void:
	knockback.apply(Vector2(100, 0))
	assert_eq(knockback.velocity, Vector2(100, 0))
	knockback.taken = 0.5
	knockback.apply(Vector2(100, 0))
	assert_eq(knockback.velocity, Vector2(150, 0))


func test_tells_what_a_push_added() -> void:
	watch_signals(knockback)
	knockback.taken = 0.5
	knockback.apply(Vector2(100, 0))
	assert_signal_emitted_with_parameters(knockback, "pushed", [Vector2(50, 0)])
	knockback.taken = 0.0
	knockback.apply(Vector2(100, 0))
	assert_signal_emit_count(knockback, "pushed", 1, "an immovable owner isn't pushed")


func test_push_dies_down_in_expected_time() -> void:
	knockback.apply(Vector2(360, 0))
	for i in 8:
		knockback.step(TICK)
	assert_true(knockback.is_active(), "still moving after 8 ticks")
	for i in 2:
		knockback.step(TICK)
	assert_false(knockback.is_active(), "360 px/s at 2400 px/s² stops in 0.15 s (9 ticks)")


func test_bounces_back_from_a_wall_with_reduced_speed() -> void:
	knockback.apply(Vector2(200, 50))
	knockback.bounce_off(Vector2.LEFT)
	assert_almost_eq(knockback.velocity.x, -60.0, 0.001)
	assert_almost_eq(knockback.velocity.y, 15.0, 0.001)


func test_no_bounce_when_moving_away_or_idle() -> void:
	knockback.apply(Vector2(-200, 0))
	knockback.bounce_off(Vector2.LEFT)
	assert_eq(knockback.velocity, Vector2(-200, 0))
	knockback.velocity = Vector2.ZERO
	knockback.bounce_off(Vector2.LEFT)
	assert_eq(knockback.velocity, Vector2.ZERO)


func test_deterministic_for_prediction() -> void:
	var other := KnockbackComponent.new()
	other.configure(2400.0, 0.3, 1.0)
	add_child_autofree(other)
	for component: KnockbackComponent in [knockback, other]:
		component.apply(Vector2(350, -120))
		for i in 5:
			component.step(TICK)
		component.bounce_off(Vector2.UP.rotated(0.3))
	assert_eq(knockback.velocity, other.velocity)
