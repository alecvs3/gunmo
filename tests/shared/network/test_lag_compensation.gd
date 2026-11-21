extends GutTest
## PositionHistory and LagCompensator's rewind rules.

var history: PositionHistory


func before_each() -> void:
	history = PositionHistory.new()
	history.capacity = 8


func test_history_blends_between_ticks() -> void:
	history.record(10, Vector2(0, 0), true)
	history.record(11, Vector2(10, 0), true)
	var sample: Dictionary = history.sample(10.5)
	assert_almost_eq((sample["position"] as Vector2).x, 5.0, 0.001)
	assert_true(sample["hittable"])


func test_history_holds_ends_and_forgets_old() -> void:
	for tick in 12:
		history.record(tick, Vector2(tick, 0), true)
	assert_eq(history.sample(0.0)["position"], Vector2(4, 0), "only the newest 8 ticks kept")
	assert_eq(history.sample(99.0)["position"], Vector2(11, 0))


func test_history_not_hittable_if_either_side_was_dead() -> void:
	history.record(1, Vector2.ZERO, true)
	history.record(2, Vector2.ZERO, false)
	assert_false(history.sample(1.5)["hittable"])


func test_empty_history() -> void:
	assert_eq(history.sample(3.0), {})


func test_rewind_is_clamped_to_max_rewind_and_present() -> void:
	var lag: LagCompensator = NetworkManager.lag_compensator
	var clock: NetClock = NetworkManager.clock
	var saved_tick: int = clock.tick
	clock.tick = 1000
	var max_ticks: int = lag.max_rewind_ticks()
	assert_eq(lag.clamped_tick(990.0), 990.0)
	assert_eq(lag.clamped_tick(1000.0 - max_ticks - 50), float(1000 - max_ticks))
	assert_eq(lag.clamped_tick(1200.0), 1000.0, "never into the future")
	clock.tick = saved_tick


func test_sweep_uses_rewound_position() -> void:
	var lag: LagCompensator = NetworkManager.lag_compensator
	var hitbox := HitboxComponent.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 10.0
	hitbox.add_child(shape)
	hitbox.team = &"targets"
	hitbox.position = Vector2(500, 0)
	add_child_autofree(hitbox)
	var past: PositionHistory = lag._histories[hitbox]
	past.record(100, Vector2(50, 0), true)
	past.record(101, Vector2(500, 0), true)
	var at_past: LagCompensator.Hit = lag.sweep(Vector2.ZERO, Vector2(100, 0), 0.0, 100.0, &"x")
	assert_not_null(at_past, "hits where the shooter saw it")
	assert_null(lag.sweep(Vector2.ZERO, Vector2(100, 0), 0.0, LagCompensator.PRESENT, &"x"))
	assert_null(lag.sweep(Vector2.ZERO, Vector2(100, 0), 0.0, 100.0, &"targets"), "same team")
