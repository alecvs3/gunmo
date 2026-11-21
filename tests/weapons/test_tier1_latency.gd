extends GutTest
## Latency tier 1: bots leading targets, fair dodging on the target's own timeline, incoming
## bullets catching up, the hit-direction marker and the input's client tick.


func _shot(from: Vector2, direction: Vector2, speed_px_per_tick: float) -> Shot:
	var shot := Shot.new()
	shot.origin = from
	shot.direction = direction
	shot.speed = speed_px_per_tick * NetClock.tick_rate()
	shot.lifetime = 2.0
	shot.radius = 2.0
	shot.fire_tick = 100.0
	shot.shooter_id = -1
	return shot


func _hitbox() -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 10.0
	hitbox.add_child(shape)
	add_child_autofree(hitbox)
	return hitbox


func test_intercept_leads_a_moving_target() -> void:
	var aim: Vector2 = BotBrain.intercept(
		Vector2.ZERO, Vector2(300, 0), Vector2(0, 100), 1000.0, 2.0
	)
	var time: float = aim.length() / 1000.0
	assert_almost_eq(aim.distance_to(Vector2(300, 0) + Vector2(0, 100) * time), 0.0, 0.5)
	assert_gt(aim.y, 0.0, "aims ahead of where the target is moving")


func test_intercept_still_target_and_unreachable() -> void:
	var still: Vector2 = BotBrain.intercept(
		Vector2.ZERO, Vector2(200, 50), Vector2.ZERO, 900.0, 2.0
	)
	assert_eq(still, Vector2(200, 50))
	var away: Vector2 = BotBrain.intercept(
		Vector2.ZERO, Vector2(100, 0), Vector2(2000, 0), 900.0, 2.0
	)
	assert_eq(away, Vector2(100, 0), "faster than the bullet: aim at it")


func test_fair_dodging_counts_a_dodge_on_the_targets_own_screen() -> void:
	var shot: Shot = _shot(Vector2.ZERO, Vector2.RIGHT, 20.0)
	var hitbox: HitboxComponent = _hitbox()
	var timeline := PositionHistory.new()
	for tick in range(100, 111):
		timeline.record(tick, Vector2(100, 200), true)
	var hits := TimelineHits.new()
	hits.add_target(hitbox, timeline, func() -> int: return 110, shot)
	assert_null(hits.check(shot, 110, shot.point_at(10)), "it had moved out of the way")
	assert_true(hits.settled(110))


func test_fair_dodging_hits_where_the_target_really_was() -> void:
	var shot: Shot = _shot(Vector2.ZERO, Vector2.RIGHT, 20.0)
	var hitbox: HitboxComponent = _hitbox()
	var timeline := PositionHistory.new()
	for tick in range(100, 111):
		timeline.record(tick, Vector2(100, 0), true)
	var newest: Array[int] = [102]
	var hits := TimelineHits.new()
	hits.add_target(hitbox, timeline, func() -> int: return newest[0], shot)
	assert_null(hits.check(shot, 110, shot.point_at(10)), "inputs not here yet")
	assert_false(hits.settled(110), "waits for the target's inputs")
	newest[0] = 110
	var hit: TimelineHits.Hit = hits.check(shot, 110, shot.point_at(10))
	assert_not_null(hit)
	assert_eq(hit.tick, 105, "the bullet reaches x=90 (100 - radius) in tick 105")
	assert_eq(hit.hitbox, hitbox)


func test_unhittable_on_its_timeline_is_skipped() -> void:
	var shot: Shot = _shot(Vector2.ZERO, Vector2.RIGHT, 20.0)
	var timeline := PositionHistory.new()
	for tick in range(100, 111):
		timeline.record(tick, Vector2(100, 0), false)
	var hits := TimelineHits.new()
	hits.add_target(_hitbox(), timeline, func() -> int: return 110, shot)
	assert_null(hits.check(shot, 110, shot.point_at(10)))


func test_catch_up_moves_from_the_past_to_the_present() -> void:
	assert_eq(Bullet.display_tick(100.0, 110.0, 100.0, 12.0), 100.0, "starts at the muzzle")
	assert_almost_eq(Bullet.display_tick(106.0, 116.0, 100.0, 12.0), 111.0, 0.001, "halfway")
	assert_eq(Bullet.display_tick(112.0, 122.0, 100.0, 12.0), 122.0, "then on the present")


func test_only_bullets_passing_near_catch_up() -> void:
	var shot: Shot = _shot(Vector2.ZERO, Vector2.RIGHT, 20.0)
	assert_true(Bullet.passes_near(shot, Vector2(500, 60), 150.0))
	assert_false(Bullet.passes_near(shot, Vector2(500, 400), 150.0))


func test_hurt_marker_points_at_the_source() -> void:
	var angles: Vector2 = HurtIndicator.arc_angles(Vector2.UP)
	assert_almost_eq((angles.x + angles.y) * 0.5, Vector2.UP.angle(), 0.0001)
	assert_almost_eq(angles.y - angles.x, deg_to_rad(HurtIndicator.ARC_DEGREES), 0.0001)


func test_client_tick_travels_with_the_command() -> void:
	var command := InputCommand.new()
	command.sequence = 9
	command.client_tick = 1234.5
	var decoded: Array[InputCommand] = InputCommand.decode_batch(
		InputCommand.encode_batch([command] as Array[InputCommand])
	)
	assert_eq(decoded[0].client_tick, 1234.5)
