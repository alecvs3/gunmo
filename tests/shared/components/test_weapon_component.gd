extends GutTest

const TICK: float = 1.0 / 60.0

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


func test_starts_with_full_magazine() -> void:
	assert_eq(weapon.ammo, 3)


func test_fire_uses_ammo() -> void:
	assert_true(weapon.step(TICK, true, false))
	assert_eq(weapon.ammo, 2)


func test_not_holding_fire_never_fires() -> void:
	assert_false(weapon.step(TICK, false, false))
	assert_eq(weapon.ammo, 3)


func test_fire_rate_blocks_shots_until_cooldown_passes() -> void:
	assert_true(weapon.step(TICK, true, false))
	var ticks_until_next: int = 0
	while not weapon.step(TICK, true, false):
		ticks_until_next += 1
	assert_eq(ticks_until_next, 14, "4 shots/s at 60 Hz = a shot every 15 ticks")


func test_empty_magazine_auto_reloads_after_reload_time() -> void:
	_fire_until_empty()
	assert_true(weapon.is_reloading())
	_run(0.5, true)
	assert_eq(weapon.ammo, 0, "still reloading halfway")
	_run(0.5, false)
	assert_eq(weapon.ammo, 3)
	assert_false(weapon.is_reloading())


func test_manual_reload_ignored_when_magazine_full() -> void:
	weapon.step(TICK, false, true)
	assert_false(weapon.is_reloading())


func test_manual_reload_refills_partial_magazine() -> void:
	weapon.step(TICK, true, false)
	weapon.step(TICK, false, true)
	_run(1.0, false)
	assert_eq(weapon.ammo, 3)


func test_restore_then_replay_matches_original() -> void:
	weapon.step(TICK, true, false)
	var saved: Array = [weapon.ammo, weapon.cooldown_left, weapon.reload_left]
	var original: Array[bool] = []
	for i in 40:
		original.append(weapon.step(TICK, true, false))
	weapon.restore(saved[0], saved[1], saved[2])
	var replayed: Array[bool] = []
	for i in 40:
		replayed.append(weapon.step(TICK, true, false))
	assert_eq(replayed, original, "prediction replays produce the same shots")


func test_spread_is_deterministic_per_seed() -> void:
	data.spread = 10.0
	var seed_value: int = WeaponComponent.shot_seed(7, 42)
	var first: Vector2 = weapon.spread_direction(Vector2.RIGHT, seed_value)
	assert_eq(weapon.spread_direction(Vector2.RIGHT, seed_value), first)
	assert_ne(weapon.spread_direction(Vector2.RIGHT, WeaponComponent.shot_seed(7, 43)), first)


func test_spread_stays_inside_cone() -> void:
	data.spread = 10.0
	for i in 50:
		var direction: Vector2 = weapon.spread_direction(Vector2.RIGHT, i)
		assert_almost_eq(direction.length(), 1.0, 0.0001)
		assert_lte(absf(rad_to_deg(direction.angle())), 5.0001)


func test_pistol_resource_has_valid_values() -> void:
	var pistol: WeaponData = load("res://weapons/data/pistol.tres")
	assert_gt(pistol.damage, 0)
	assert_gt(pistol.fire_rate, 0.0)
	assert_gt(pistol.magazine_size, 0)
	assert_gt(pistol.bullet_speed, 0.0)
	assert_gt(pistol.bullet_radius, 0.0)


func _fire_until_empty() -> void:
	for i in 200:
		weapon.step(TICK, true, false)
		if weapon.ammo == 0:
			return


func _run(seconds: float, holding_fire: bool) -> void:
	for i in roundi(seconds / TICK):
		weapon.step(TICK, holding_fire, false)
