extends GutTest


func test_hit_forwards_damage_and_source_to_health() -> void:
	var health := HealthComponent.new()
	health.max_health = 40
	add_child_autofree(health)
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	add_child_autofree(hitbox)
	watch_signals(health)

	hitbox.hit(15, 3)

	assert_eq(health.current_health, 25)
	assert_signal_emitted_with_parameters(health, "damaged", [15, 3])


func test_hit_without_health_does_nothing() -> void:
	var hitbox := HitboxComponent.new()
	add_child_autofree(hitbox)
	hitbox.hit(15, 3)
	assert_true(is_instance_valid(hitbox))
