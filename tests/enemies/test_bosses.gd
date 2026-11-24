extends GutTest

const BOSSES: Array[String] = ["brood_mother", "warden", "overlord"]


func _phase(below: float, name: String = "") -> BossPhase:
	var phase := BossPhase.new()
	phase.health_below = below
	phase.display_name = name
	return phase


func _boss(boss_name: String) -> EnemyData:
	return load("res://enemies/data/bosses/%s.tres" % boss_name)


func test_phase_follows_health() -> void:
	var phases: Array[BossPhase] = [_phase(1.0), _phase(0.6), _phase(0.25)]
	assert_eq(BossPhase.index_for(phases, 1.0), 0)
	assert_eq(BossPhase.index_for(phases, 0.61), 0)
	assert_eq(BossPhase.index_for(phases, 0.6), 1, "at the threshold it changes")
	assert_eq(BossPhase.index_for(phases, 0.3), 1)
	assert_eq(BossPhase.index_for(phases, 0.1), 2)
	assert_eq(BossPhase.index_for([] as Array[BossPhase], 0.5), 0, "not a boss")


func test_a_phase_replaces_movement_attack_and_speed() -> void:
	var data := EnemyData.new()
	data.movement = ChaseMovement.new()
	data.attack = MeleeAttack.new()
	var second: BossPhase = _phase(0.5)
	second.movement = KeepDistanceMovement.new()
	second.speed_multiplier = 1.5
	data.phases.assign([_phase(1.0), second])
	assert_eq(data.movement_in(0), data.movement, "a phase without parts keeps the plain ones")
	assert_eq(data.attack_in(1), data.attack)
	assert_eq(data.movement_in(1), second.movement)
	assert_eq(data.speed_in(1), 1.5)
	assert_eq(data.speed_in(9), 1.0)
	assert_true(data.is_boss())
	assert_false(EnemyData.new().is_boss())


func test_ring_volley_spreads_evenly_and_fires_unseen() -> void:
	var ring := VolleyAttack.new()
	ring.shots = 8
	ring.spread_degrees = 360.0
	var directions: Array[Vector2] = ring.directions(Vector2.RIGHT)
	assert_eq(directions.size(), 8)
	assert_almost_eq(directions[2].angle(), PI / 2.0, 1e-4)
	assert_true(ring.wants_to_attack(0.0, INF, false), "a ring needs no target in sight")
	assert_false(ring.needs_line_of_sight())


func test_fan_volley_is_centred_on_the_aim() -> void:
	var fan := VolleyAttack.new()
	fan.shots = 5
	fan.spread_degrees = 40.0
	fan.attack_range = 600.0
	var directions: Array[Vector2] = fan.directions(Vector2.UP)
	assert_almost_eq(directions[2].angle(), Vector2.UP.angle(), 1e-4, "middle shot at the aim")
	assert_almost_eq(directions[0].angle_to(directions[4]), deg_to_rad(40.0), 1e-4)
	assert_false(fan.wants_to_attack(0.0, 500.0, false), "aimed: needs to see")
	assert_false(fan.wants_to_attack(0.0, 700.0, true), "aimed: in range")
	assert_true(fan.wants_to_attack(0.0, 500.0, true))


func test_summon_waits_for_room() -> void:
	var summon := SummonAttack.new()
	summon.count = 4
	summon.max_alive = 30
	assert_true(summon.has_room(26))
	assert_false(summon.has_room(27))


func test_telegraph_byte_fills_over_the_windup() -> void:
	assert_eq(EnemyNetState.to_telegraph(0.0, 1.0), 0, "not winding up")
	assert_eq(EnemyNetState.to_telegraph(1.0, 1.0), 1, "just started")
	assert_eq(EnemyNetState.to_telegraph(0.5, 1.0), 128)
	assert_eq(EnemyNetState.to_telegraph(0.001, 1.0), 255, "about to fire")
	assert_eq(EnemyNetState.to_telegraph(0.5, 0.0), 0, "no windup")


func test_every_boss_has_telegraphed_phases() -> void:
	for boss_name in BOSSES:
		var boss: EnemyData = _boss(boss_name)
		assert_gte(boss.phases.size(), 2, boss_name + " has at least 2 phases")
		assert_eq(boss.phases[0].health_below, 1.0, boss_name + " starts in phase 1")
		var telegraphed: int = 0
		for i in boss.phases.size():
			if i > 0:
				assert_lt(boss.phases[i].health_below, boss.phases[i - 1].health_below, boss_name)
			assert_false(boss.phases[i].display_name.is_empty(), boss_name + " phase names")
			if boss.attack_in(i).windup > 0.0:
				telegraphed += 1
		assert_gt(telegraphed, 0, boss_name + " telegraphs an attack")
		assert_gt(boss.body_scale, 1.5, boss_name + " is big")
		assert_true(boss.resource_path.begins_with(ChaserEnemy.DATA_FOLDER), "clients load it")


func test_bosses_come_at_10_20_25_and_the_last_ends_the_match() -> void:
	var schedule: WaveSchedule = load("res://modes/waves/data/default_waves.tres")
	assert_eq(schedule.boss_for(10), _boss("brood_mother"))
	assert_eq(schedule.boss_for(20), _boss("warden"))
	assert_eq(schedule.boss_for(25), _boss("overlord"))
	assert_null(schedule.boss_for(11))
	assert_true(_boss("overlord").ends_wave_on_death, "beating it wins")
	assert_false(_boss("warden").ends_wave_on_death)
	var rng := RandomNumberGenerator.new()
	var plan: Array[EnemyData] = WaveBudget.plan(schedule, 20, rng)
	assert_eq(plan[0], _boss("warden"), "the boss comes first")
	assert_eq(plan.count(_boss("warden")), 1)


func test_boss_bar_title() -> void:
	assert_eq(BossBar.title("Warden", "Lockdown"), "Warden · Lockdown")
	assert_eq(BossBar.title("Warden", ""), "Warden")
