extends GutTest

var health: HealthComponent
var status: StatusEffectsComponent


func _effects() -> HitEffects:
	return HitEffects.new()


func before_each() -> void:
	health = HealthComponent.new()
	health.max_health = 1000
	add_child_autofree(health)
	status = StatusEffectsComponent.new()
	status.health = health
	status.max_slow = 0.5
	add_child_autofree(status)
	status.set_physics_process(false)


func _burn(dps: float, seconds: float) -> HitEffects:
	var effects: HitEffects = _effects()
	effects.burn_dps = dps
	effects.burn_seconds = seconds
	return effects


func test_burn_deals_damage_over_time_credited_to_the_shooter() -> void:
	watch_signals(health)
	status.apply(_burn(10.0, 2.0), 7)
	assert_true(status.is_burning())
	for i in 300:
		status.step(1.0 / 60.0)
	assert_eq(health.current_health, 980, "10 per second for 2 seconds")
	assert_signal_emitted_with_parameters(health, "damaged", [5, 7])
	assert_false(status.is_burning(), "burned out")


func test_stronger_burn_wins_and_time_refreshes() -> void:
	status.apply(_burn(10.0, 1.0), 1)
	status.apply(_burn(4.0, 2.0), 2)
	for i in 130:
		status.step(1.0 / 60.0)
	assert_eq(health.current_health, 980, "the stronger 10/s burned for the longer 2 s")


func test_burn_kill_counts_for_the_shooter() -> void:
	health.max_health = 5
	health.reset()
	watch_signals(health)
	status.apply(_burn(20.0, 1.0), 9)
	for i in 60:
		status.step(1.0 / 60.0)
	assert_signal_emitted_with_parameters(health, "died", [9])


func test_chill_slows_up_to_the_cap_then_wears_off() -> void:
	var chill: HitEffects = _effects()
	chill.chill_slow = 0.8
	chill.chill_seconds = 1.0
	status.apply(chill, 1)
	assert_almost_eq(status.speed_multiplier(), 0.5, 0.0001, "capped by max_slow")
	assert_eq(status.flags, HitEffects.CHILL)
	for i in 61:
		status.step(1.0 / 60.0)
	assert_eq(status.speed_multiplier(), 1.0)
	assert_eq(status.flags, 0)


func test_shred_makes_hits_and_burns_land_harder() -> void:
	var shred: HitEffects = _burn(10.0, 1.0)
	shred.shred_bonus = 1.0
	shred.shred_seconds = 2.0
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	hitbox.status = status
	add_child_autofree(hitbox)
	hitbox.apply_effects(shred, 1)
	hitbox.hit(20, 1)
	assert_eq(health.current_health, 960, "20 x 2")
	for i in 70:
		status.step(1.0 / 60.0)
	assert_eq(health.current_health, 940, "10 burn x 2")


func test_dead_targets_take_no_effects() -> void:
	health.take_damage(1000)
	status.apply(_burn(10.0, 1.0), 1)
	assert_false(status.is_burning())


func test_clients_show_the_host_flags() -> void:
	status.show_flags(HitEffects.BURN | HitEffects.SHRED)
	assert_true(status.is_burning())
