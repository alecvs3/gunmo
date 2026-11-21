extends GutTest

var data: WeaponData


func before_each() -> void:
	data = WeaponData.new()
	data.damage = 35
	data.bullet_speed = 600.0
	data.bullet_lifetime = 0.5
	data.bullet_radius = 3.0
	data.knockback = 90.0


func test_from_weapon_takes_weapon_numbers() -> void:
	var shot: Shot = Shot.from_weapon(data, Vector2(10, 20), Vector2(0, 5))
	assert_eq(shot.damage, 35)
	assert_eq(shot.speed, 600.0)
	assert_eq(shot.lifetime, 0.5)
	assert_eq(shot.radius, 3.0)
	assert_eq(shot.knockback, 90.0)
	assert_eq(shot.origin, Vector2(10, 20))
	assert_eq(shot.direction, Vector2.DOWN, "direction is normalized")


func test_point_at_moves_at_speed() -> void:
	var shot: Shot = Shot.from_weapon(data, Vector2.ZERO, Vector2.RIGHT)
	assert_almost_eq(shot.point_at(60.0).x, 600.0, 0.001, "60 ticks = 1 s")
	assert_almost_eq(shot.lifetime_ticks(), 30.0, 0.001)


func test_encode_decode_round_trip() -> void:
	var shot: Shot = Shot.from_weapon(data, Vector2(1, 2), Vector2.UP)
	shot.shooter_id = 123456
	shot.shot_id = 99
	shot.team = &"players"
	shot.fire_tick = 1000.0
	shot.view_tick = 993.5
	shot.pierce = 2
	shot.projectile = WeaponData.Projectile.ROCKET
	var buffer := StreamPeerBuffer.new()
	shot.encode(buffer)
	var decoded: Shot = Shot.decode(NetCodec.buffer_from(buffer.data_array))
	assert_eq(decoded.key(), "123456:99")
	assert_eq(decoded.team, &"players")
	assert_eq(decoded.origin, Vector2(1, 2))
	assert_eq(decoded.direction, Vector2.UP)
	assert_eq(decoded.damage, 35)
	assert_eq(decoded.fire_tick, 1000.0)
	assert_eq(decoded.view_tick, 993.5)
	assert_eq(decoded.pierce, 2)
	assert_eq(decoded.projectile, WeaponData.Projectile.ROCKET)


func test_pellet_ids_are_unique_per_command() -> void:
	var ids: Dictionary = {}
	for command in range(1, 50):
		for pellet in Shot.MAX_PELLETS:
			ids[Shot.make_id(command, pellet)] = true
	assert_eq(ids.size(), 49 * Shot.MAX_PELLETS)


func test_bot_shooter_ids_are_signed() -> void:
	var shot: Shot = Shot.from_weapon(data, Vector2.ZERO, Vector2.RIGHT)
	shot.shooter_id = -4
	shot.shot_id = 7
	var buffer := StreamPeerBuffer.new()
	shot.encode(buffer)
	assert_eq(Shot.decode(NetCodec.buffer_from(buffer.data_array)).key(), "-4:7")
