extends GutTest

var data: WeaponData
var weapon: WeaponComponent


func before_each() -> void:
	data = WeaponData.new()
	data.damage = 25
	data.fire_rate = 4.0
	data.spread = 0.0
	data.magazine_size = 3
	data.reload_time = 1.0
	weapon = WeaponComponent.new()
	weapon.weapon_data = data
	add_child_autofree(weapon)
	weapon.set_physics_process(false)
	watch_signals(weapon)


func test_starts_with_full_magazine() -> void:
	assert_eq(weapon.ammo, 3)


func test_fire_uses_ammo_and_emits_fired() -> void:
	assert_true(weapon.try_fire(Vector2.ZERO, Vector2.RIGHT))
	assert_eq(weapon.ammo, 2)
	assert_signal_emitted_with_parameters(weapon, "fired", [Vector2.ZERO, Vector2.RIGHT])


func test_fire_rate_blocks_shots_until_cooldown_passes() -> void:
	weapon.try_fire(Vector2.ZERO, Vector2.RIGHT)
	assert_false(weapon.try_fire(Vector2.ZERO, Vector2.RIGHT), "fired again too soon")
	weapon.tick(0.2)
	assert_false(weapon.try_fire(Vector2.ZERO, Vector2.RIGHT), "0.2s is under the 0.25s cooldown")
	weapon.tick(0.06)
	assert_true(weapon.try_fire(Vector2.ZERO, Vector2.RIGHT), "0.25s cooldown has passed")


func test_empty_magazine_auto_reloads_after_reload_time() -> void:
	_fire_times(3)
	assert_eq(weapon.ammo, 0)
	assert_true(weapon.is_reloading())
	assert_signal_emitted(weapon, "reload_started")
	weapon.tick(0.5)
	assert_false(weapon.try_fire(Vector2.ZERO, Vector2.RIGHT), "still reloading")
	weapon.tick(0.5)
	assert_eq(weapon.ammo, 3)
	assert_signal_emitted(weapon, "reloaded")


func test_manual_reload_ignored_when_magazine_full() -> void:
	weapon.start_reload()
	assert_false(weapon.is_reloading())


func test_manual_reload_refills_partial_magazine() -> void:
	weapon.try_fire(Vector2.ZERO, Vector2.RIGHT)
	weapon.start_reload()
	weapon.tick(1.0)
	assert_eq(weapon.ammo, 3)


func test_spread_stays_inside_cone() -> void:
	data.spread = 10.0
	for i in 50:
		var dir: Vector2 = weapon.spread_direction(Vector2.RIGHT)
		assert_almost_eq(dir.length(), 1.0, 0.0001)
		assert_lte(absf(rad_to_deg(dir.angle())), 5.0001)


func test_pistol_resource_has_valid_values() -> void:
	var pistol: WeaponData = load("res://weapons/data/pistol.tres")
	assert_gt(pistol.damage, 0)
	assert_gt(pistol.fire_rate, 0.0)
	assert_gt(pistol.magazine_size, 0)
	assert_gt(pistol.bullet_speed, 0.0)


func _fire_times(count: int) -> void:
	for i in count:
		weapon.tick(1.0)
		weapon.try_fire(Vector2.ZERO, Vector2.RIGHT)
