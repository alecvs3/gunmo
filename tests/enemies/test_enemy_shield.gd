extends GutTest
## A Shielder's shield: which hits it blocks (EnemyShield), how a guarded hitbox ignores them
## (HitboxComponent.guard), how it turns (EnemyFacing.turn_towards) and its plate (ShieldLook).


func _shield() -> EnemyShield:
	var shield := EnemyShield.new()
	shield.arc_degrees = 110.0
	shield.turn_speed_degrees = 90.0
	return shield


func test_blocks_hits_from_the_front_only() -> void:
	var shield: EnemyShield = _shield()
	# Facing right (angle 0): a bullet flying left came from the front.
	assert_true(shield.blocks(0.0, Vector2.LEFT), "straight on")
	assert_true(shield.blocks(0.0, Vector2.from_angle(PI - deg_to_rad(50.0))), "50 degrees off")
	assert_false(shield.blocks(0.0, Vector2.from_angle(PI - deg_to_rad(60.0))), "past the edge")
	assert_false(shield.blocks(0.0, Vector2.DOWN), "from the side")
	assert_false(shield.blocks(0.0, Vector2.RIGHT), "from behind")
	assert_false(shield.blocks(0.0, Vector2.ZERO), "a hit from no side (a pet's lightning)")


func test_blocking_follows_where_it_faces() -> void:
	var shield: EnemyShield = _shield()
	assert_true(shield.blocks(PI / 2.0, Vector2.UP), "facing down, hit from below")
	assert_false(shield.blocks(PI / 2.0, Vector2.LEFT), "its right side is open")


func test_turns_slowly_towards_its_target() -> void:
	var facing := EnemyFacing.new()
	facing.walk_towards(Vector2.RIGHT)
	var step: float = _shield().turn_step(0.5)
	assert_almost_eq(step, deg_to_rad(45.0), 0.0001, "90 degrees per second")
	facing.turn_towards(Vector2.DOWN, step)
	assert_almost_eq(facing.angle(), deg_to_rad(45.0), 0.0001, "half way after half a second")
	facing.turn_towards(Vector2.DOWN, step)
	assert_almost_eq(facing.angle(), PI / 2.0, 0.0001)
	facing.turn_towards(Vector2.DOWN, step)
	assert_almost_eq(facing.angle(), PI / 2.0, 0.0001, "doesn't overshoot")


func test_a_guarded_hitbox_ignores_blocked_hits() -> void:
	var health: HealthComponent = autofree(HealthComponent.new())
	health.max_health = 100
	var hitbox: HitboxComponent = autofree(HitboxComponent.new())
	hitbox.health = health
	add_child(health)
	hitbox.guard = func(incoming: Vector2) -> bool: return incoming == Vector2.LEFT
	assert_false(hitbox.hit(30, 0, Vector2.ZERO, DamageType.Type.BLAST, Vector2.LEFT), "blocked")
	assert_eq(health.current_health, 100, "no damage through the shield")
	assert_true(hitbox.hit(30, 0, Vector2.ZERO, DamageType.Type.BLAST, Vector2.RIGHT))
	assert_eq(health.current_health, 70, "from behind it lands")
	assert_true(hitbox.hit(10, 0), "a hit with no direction always lands")
	assert_eq(health.current_health, 60)


func test_the_plate_spans_its_arc() -> void:
	var look := ShieldLook.new()
	look.arc_degrees = 90.0
	look.plate_radius = 20.0
	look.thickness = 5.0
	var plate: PackedVector2Array = look.outline()
	assert_eq(plate.size(), (ShieldLook.STEPS + 1) * 2)
	assert_almost_eq(plate[0].angle(), deg_to_rad(-45.0), 0.0001, "starts at one edge")
	assert_almost_eq(plate[ShieldLook.STEPS].angle(), deg_to_rad(45.0), 0.0001, "ends at the other")
	assert_almost_eq(plate[0].length(), 25.0, 0.0001, "outer edge")
	assert_almost_eq(plate[plate.size() - 1].length(), 20.0, 0.0001, "inner edge")
