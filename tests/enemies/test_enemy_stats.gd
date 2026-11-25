extends GutTest

const FOLDERS: Array[String] = ["res://enemies/data/", "res://enemies/data/bosses/"]


func _load(type_name: String) -> EnemyData:
	return load("res://enemies/data/%s.tres" % type_name)


func _melee(damage: int, interval: float) -> MeleeAttack:
	var attack := MeleeAttack.new()
	attack.damage = damage
	attack.interval = interval
	return attack


func test_a_grunt_s_numbers() -> void:
	var stats: EnemyStats = EnemyStats.of(_load("grunt"))
	assert_almost_eq(stats.value(EnemyStats.MELEE_DPS), 20.0, 0.01, "10 damage every 0.5 s")
	assert_almost_eq(stats.value(EnemyStats.HEALTH), 60.0, 0.01)
	assert_almost_eq(stats.value(EnemyStats.MOVE), 140.0, 0.01)
	assert_eq(stats.value(EnemyStats.BODIES), 1.0)


func test_armor_raises_effective_health() -> void:
	var tank: EnemyData = _load("tank")
	var health: float = EnemyStats.of(tank).value(EnemyStats.HEALTH)
	assert_almost_eq(health, tank.max_health / tank.damage_taken, 0.01)


func test_a_splitter_counts_its_children() -> void:
	var stats: EnemyStats = EnemyStats.of(_load("splitter"))
	assert_almost_eq(stats.value(EnemyStats.HEALTH), 140.0 + 2 * 35.0, 0.01)
	assert_eq(stats.value(EnemyStats.BODIES), 3.0)


func test_a_windup_slows_the_attack() -> void:
	var attack: MeleeAttack = _melee(10, 1.0)
	attack.windup = 1.0
	var stats := EnemyStats.new()
	attack.add_stats(stats, 1.0)
	assert_almost_eq(stats.value(EnemyStats.MELEE_DPS), 5.0, 0.01)


func test_a_ring_lands_only_the_shots_in_the_aim_cone() -> void:
	var ring := VolleyAttack.new()
	ring.shots = 12
	ring.spread_degrees = 360.0
	assert_almost_eq(ring.shots_that_hit(30.0), 1.0, 0.01)
	ring.spread_degrees = 20.0
	assert_almost_eq(ring.shots_that_hit(30.0), 12.0, 0.01, "a tight fan all lands")


func test_boss_phases_count_by_the_health_they_cover() -> void:
	var boss := EnemyData.new()
	boss.max_health = 1000
	for at in [1.0, 0.5]:
		var phase := BossPhase.new()
		phase.health_below = at
		phase.attack = _melee(10, 1.0) if at == 1.0 else _melee(30, 1.0)
		boss.phases.append(phase)
	assert_eq(EnemyStats.phase_weights(boss), PackedFloat32Array([0.5, 0.5]))
	var stats: EnemyStats = EnemyStats.of(boss)
	assert_almost_eq(stats.value(EnemyStats.MELEE_DPS), 20.0, 0.01)
	assert_eq(stats.value(EnemyStats.BODIES), 0.0, "a boss is not a normal body")


func test_a_summon_adds_health_over_time() -> void:
	var summon := SummonAttack.new()
	summon.into = _load("grunt")
	summon.count = 2
	summon.interval = 4.0
	var stats := EnemyStats.new()
	summon.add_stats(stats, 1.0)
	assert_almost_eq(stats.value(EnemyStats.SUMMONED_HEALTH), 30.0, 0.01, "2 × 60 every 4 s")


func test_a_summon_of_itself_stops() -> void:
	var data := EnemyData.new()
	var summon := SummonAttack.new()
	summon.into = data
	data.attack = summon
	assert_gt(EnemyStats.of(data).value(EnemyStats.SUMMONED_HEALTH), 0.0, "no endless loop")


func test_every_enemy_does_something_the_score_sees() -> void:
	var acting: Array[StringName] = [
		EnemyStats.MELEE_DPS,
		EnemyStats.RANGED_DPS,
		EnemyStats.HEAL_SHARE,
		EnemyStats.SUMMONED_HEALTH
	]
	for folder in FOLDERS:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".tres"):
				continue
			var stats: EnemyStats = EnemyStats.of(load(folder + file))
			var acts: float = 0.0
			for key in acting:
				acts += stats.value(key)
			assert_gt(stats.value(EnemyStats.HEALTH), 0.0, file)
			assert_gt(acts, 0.0, "%s: its attack needs add_stats (EnemyAttack)" % file)
