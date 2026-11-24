extends GutTest

var data: WizardData


func before_each() -> void:
	data = load("res://pets/data/wizard.tres")


func test_status_slow_keeps_the_stronger_and_the_later() -> void:
	var status := EnemyStatus.new()
	assert_eq(status.speed_factor(0), 1.0)
	status.slow(0.35, 100, 0)
	assert_almost_eq(status.speed_factor(50), 0.65, 1e-6)
	status.slow(0.2, 150, 50)
	assert_almost_eq(status.speed_factor(120), 0.65, 1e-6, "stronger slow kept, longer end")
	assert_eq(status.speed_factor(150), 1.0, "over")
	status.slow(0.2, 300, 200)
	assert_almost_eq(status.speed_factor(250), 0.8, 1e-6, "a fresh slow after one ran out")
	assert_eq(status.flags(250), EnemyStatus.FLAG_SLOWED)


func test_status_hex_and_flags() -> void:
	var status := EnemyStatus.new()
	status.hex(0.2, 60, 0)
	assert_almost_eq(status.damage_factor(10), 1.2, 1e-6)
	assert_eq(status.flags(10), EnemyStatus.FLAG_HEXED)
	status.slow(0.3, 60, 10)
	assert_eq(status.flags(10), EnemyStatus.FLAG_SLOWED | EnemyStatus.FLAG_HEXED)
	assert_eq(status.damage_factor(60), 1.0)


func test_status_travels_with_the_telegraph() -> void:
	var state := EnemyNetState.new()
	state.telegraph = 40
	state.status = EnemyStatus.FLAG_HEXED | EnemyStatus.FLAG_SLOWED
	var buffer := StreamPeerBuffer.new()
	state.encode(buffer)
	buffer.seek(0)
	var back := EnemyNetState.new()
	back.decode(buffer)
	assert_eq([back.telegraph, back.status], [40, 3])


func test_arc_chance_and_jumps_by_tier() -> void:
	assert_eq(WizardRules.arc_chance(data, 0), 0.0)
	assert_eq(WizardRules.arc_chance(data, 1), data.arc_chance)
	assert_eq(WizardRules.arc_chance(data, 2), data.arc_chance_upgraded)
	assert_eq(WizardRules.arc_jumps(data, 1, true), data.arc_jumps, "no conduction yet")
	assert_eq(WizardRules.arc_jumps(data, 2, false), data.arc_jumps_upgraded)
	assert_eq(
		WizardRules.arc_jumps(data, 3, true), data.arc_jumps_upgraded + data.conduction_extra_jumps
	)


func test_arc_damage_and_conduction() -> void:
	assert_eq(WizardRules.arc_damage(data, 1, 100, true), 40)
	assert_eq(WizardRules.arc_damage(data, 3, 100, false), 40)
	assert_eq(WizardRules.arc_damage(data, 3, 100, true), 50, "slowed: +25%")
	assert_eq(WizardRules.arc_damage(data, 1, 1, false), 1, "at least 1")


func test_chain_jumps_to_the_nearest_each_time() -> void:
	var places: Array[Vector2] = [Vector2(100, 0), Vector2(200, 0), Vector2(50, 0), Vector2(900, 0)]
	assert_eq(WizardRules.chain(Vector2.ZERO, places, 5, 140.0), [2, 0, 1], "far one out of reach")
	assert_eq(WizardRules.chain(Vector2.ZERO, places, 1, 140.0), [2])
	assert_eq(WizardRules.chain(Vector2.ZERO, [] as Array[Vector2], 3, 140.0), [] as Array[int])


func test_timers_by_tier() -> void:
	assert_eq(WizardRules.rune_interval(data, 1), 0.0)
	assert_eq(WizardRules.rune_interval(data, 2), data.rune_interval)
	assert_eq(WizardRules.rune_interval(data, 4), data.rune_interval_upgraded)
	assert_eq(WizardRules.hex_interval(data, 3), 0.0)
	assert_eq(WizardRules.hex_interval(data, 4), data.hex_interval)
	assert_eq(WizardRules.hex_interval(data, 5), data.hex_interval_upgraded)
	assert_eq(WizardRules.tempest_interval(data, 4), 0.0)
	assert_eq(WizardRules.tempest_interval(data, 5), data.tempest_interval)


func test_rune_lands_where_enemies_are_thickest() -> void:
	var places: Array[Vector2] = [
		Vector2(0, 0), Vector2(500, 0), Vector2(520, 10), Vector2(510, -20)
	]
	assert_eq(WizardRules.densest(places, 110.0), Vector2(500, 0))
	assert_eq(WizardRules.densest([] as Array[Vector2], 110.0), Vector2.INF)


func test_hex_picks_a_boss_then_the_toughest() -> void:
	assert_eq(WizardRules.toughest([60, 650, 220], [false, false, false]), 1)
	assert_eq(WizardRules.toughest([60, 650, 220], [false, false, true]), 2, "a boss first")
	assert_eq(WizardRules.toughest([] as Array[int], [] as Array[bool]), -1)


func test_tempest_damage_is_a_share_of_max_health() -> void:
	assert_eq(WizardRules.tempest_damage(data, 650, false), 52)
	assert_eq(WizardRules.tempest_damage(data, 7000, true), 140, "bosses: 2%")
