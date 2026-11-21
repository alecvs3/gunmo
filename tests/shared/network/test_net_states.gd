extends GutTest


func _round_trip(state: NetState, fresh: NetState) -> NetState:
	var buffer := StreamPeerBuffer.new()
	state.encode(buffer)
	assert_eq(buffer.data_array.size(), state.byte_size(), "byte_size matches encode")
	fresh.decode(NetCodec.buffer_from(buffer.data_array))
	return fresh


func test_player_state_round_trip_is_exact() -> void:
	var state := PlayerNetState.new()
	state.position = Vector2(123.25, -45.5)
	state.move_velocity = Vector2(220, 0)
	state.knockback = Vector2(-30, 12)
	state.aim = 2.123456789
	state.health = 77
	state.ammo = 5
	state.cooldown_left = 1.0 / 7.0
	state.reload_left = 0.4
	state.alive = false
	state.teleport_count = 3
	state.last_command = 4567
	state.weapon_index = 3
	var back: PlayerNetState = _round_trip(state, PlayerNetState.new())
	assert_eq(back.position, state.position)
	assert_eq(back.move_velocity, state.move_velocity)
	assert_eq(back.knockback, state.knockback)
	assert_eq(back.aim, state.aim)
	assert_eq(back.cooldown_left, state.cooldown_left, "timers exact for prediction")
	assert_eq(back.reload_left, state.reload_left)
	assert_eq([back.health, back.ammo, back.alive], [77, 5, false])
	assert_eq([back.teleport_count, back.last_command, back.weapon_index], [3, 4567, 3])


func test_player_no_command_yet_round_trips() -> void:
	var state := PlayerNetState.new()
	assert_eq((_round_trip(state, PlayerNetState.new()) as PlayerNetState).last_command, -1)


func test_player_interpolation_blends_position_and_aim() -> void:
	var a := PlayerNetState.new()
	var b := PlayerNetState.new()
	b.position = Vector2(100, 0)
	a.aim = PI - 0.1
	b.aim = -PI + 0.1
	a.health = 50
	b.health = 40
	var mid: PlayerNetState = a.interpolated(b, 0.25)
	assert_almost_eq(mid.position.x, 25.0, 0.001)
	assert_almost_eq(absf(mid.aim), PI - 0.05, 0.001, "takes the short way round")
	assert_eq(mid.health, 50, "discrete fields come from the nearer state")


func test_player_interpolation_does_not_slide_across_a_teleport() -> void:
	var a := PlayerNetState.new()
	var b := PlayerNetState.new()
	b.position = Vector2(1000, 0)
	b.teleport_count = 1
	assert_eq((a.interpolated(b, 0.4) as PlayerNetState).position, Vector2.ZERO)
	assert_eq((a.interpolated(b, 0.6) as PlayerNetState).position, Vector2(1000, 0))


func test_enemy_state_round_trip_and_blend() -> void:
	var a := EnemyNetState.new()
	a.position = Vector2(10, 10)
	a.health = 60
	var back: EnemyNetState = _round_trip(a, EnemyNetState.new())
	assert_eq([back.position, back.health], [Vector2(10, 10), 60])
	var b := EnemyNetState.new()
	b.position = Vector2(20, 30)
	assert_eq((a.interpolated(b, 0.5) as EnemyNetState).position, Vector2(15, 20))


func test_kinds_make_matching_states() -> void:
	assert_true(NetKinds.make_state(NetKinds.PLAYER) is PlayerNetState)
	assert_true(NetKinds.make_state(NetKinds.ENEMY) is EnemyNetState)
	assert_true(NetKinds.make_state(NetKinds.MATCH) is MatchNetState)
	assert_null(NetKinds.make_state(255))


func test_match_state_round_trip_equals_and_copy() -> void:
	var state := MatchNetState.new()
	state.phase = GameMode.Phase.BREAK
	state.wave = 12
	state.total_waves = 25
	state.phase_end_tick = 123456.0
	state.enemies_left = 300
	state.ready_count = 2
	state.player_count = 3
	state.living_count = 1
	var back: MatchNetState = _round_trip(state, MatchNetState.new())
	assert_true(back.equals(state))
	assert_true(state.copy().equals(state))
	back.ready_count = 3
	assert_false(back.equals(state))


func test_match_state_seconds_left() -> void:
	var state := MatchNetState.new()
	assert_eq(state.seconds_left(10.0), -1.0, "no timer")
	state.phase_end_tick = 100.0 + NetClock.tick_rate() * 2.0
	assert_almost_eq(state.seconds_left(100.0), 2.0, 0.0001)
	assert_eq(state.seconds_left(1e9), 0.0, "never negative")
