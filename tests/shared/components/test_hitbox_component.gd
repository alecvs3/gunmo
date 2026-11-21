extends GutTest


func _hitbox_with(shape: Shape2D, offset: Vector2 = Vector2.ZERO) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	var shape_node := CollisionShape2D.new()
	shape_node.shape = shape
	shape_node.position = offset
	hitbox.add_child(shape_node)
	add_child_autofree(hitbox)
	return hitbox


func test_hit_forwards_damage_source_and_push() -> void:
	var health := HealthComponent.new()
	health.max_health = 40
	add_child_autofree(health)
	var knockback := KnockbackComponent.new()
	add_child_autofree(knockback)
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	hitbox.knockback = knockback
	add_child_autofree(hitbox)
	watch_signals(health)

	hitbox.hit(15, 3, Vector2(50, 0))

	assert_eq(health.current_health, 25)
	assert_signal_emitted_with_parameters(health, "damaged", [15, 3])
	assert_eq(knockback.velocity, Vector2(50, 0))


func test_hit_without_components_does_nothing() -> void:
	var hitbox := HitboxComponent.new()
	add_child_autofree(hitbox)
	hitbox.hit(15, 3, Vector2.ONE)
	assert_true(is_instance_valid(hitbox))


func test_circle_sweep_includes_bullet_radius() -> void:
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	var hitbox: HitboxComponent = _hitbox_with(circle)
	var t: float = hitbox.sweep_fraction(Vector2.ZERO, Vector2(100, 0), Vector2(50, 0), 5.0)
	assert_almost_eq(t, 0.35, 0.0001)
	assert_eq(hitbox.sweep_fraction(Vector2(0, 20), Vector2(100, 20), Vector2(50, 0), 5.0), -1.0)


func test_rectangle_sweep() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	var hitbox: HitboxComponent = _hitbox_with(rect)
	var t: float = hitbox.sweep_fraction(Vector2.ZERO, Vector2(100, 0), Vector2(50, 0), 0.0)
	assert_almost_eq(t, 0.4, 0.0001)


func test_center_includes_shape_offset() -> void:
	var hitbox: HitboxComponent = _hitbox_with(CircleShape2D.new(), Vector2(0, -8))
	hitbox.position = Vector2(100, 100)
	assert_eq(hitbox.center(), Vector2(100, 92))


func test_registers_with_lag_compensator_while_in_tree() -> void:
	var hitbox: HitboxComponent = _hitbox_with(CircleShape2D.new())
	assert_true(NetworkManager.lag_compensator._histories.has(hitbox))
	remove_child(hitbox)
	assert_false(NetworkManager.lag_compensator._histories.has(hitbox))
	hitbox.free()
