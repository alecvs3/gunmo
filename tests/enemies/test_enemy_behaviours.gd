extends GutTest


func _melee(damage: int, interval: float, knockback: float) -> MeleeAttack:
	var melee := MeleeAttack.new()
	melee.damage = damage
	melee.interval = interval
	melee.knockback = knockback
	return melee


func test_chase_walks_at_the_target() -> void:
	var chase := ChaseMovement.new()
	assert_eq(chase.goal(Vector2(0, 0), Vector2(300, -40)), Vector2(300, -40))


func test_base_movement_stays_put() -> void:
	assert_eq(EnemyMovement.new().goal(Vector2(5, 6), Vector2(300, 0)), Vector2(5, 6))


func test_melee_waits_for_its_cooldown() -> void:
	var melee: MeleeAttack = _melee(10, 0.5, 350.0)
	assert_false(melee.wants_to_attack(0.2, 10.0, true))
	assert_true(melee.wants_to_attack(0.0, 10.0, true))
	assert_true(melee.wants_to_attack(0.0, INF, false), "touch works without a target")


func test_melee_pushes_away_from_the_enemy() -> void:
	var melee: MeleeAttack = _melee(10, 0.5, 350.0)
	assert_eq(melee.push(Vector2(0, 0), Vector2(0, 20)), Vector2(0, 350))
	assert_eq(melee.push(Vector2(10, 0), Vector2(0, 0)), Vector2(-350, 0))


func test_melee_with_no_one_touching_does_not_attack() -> void:
	var enemy := Node2D.new()
	var none: Array[HitboxComponent] = []
	assert_false(_melee(10, 0.5, 350.0).perform(enemy, null, none))
	enemy.free()


func test_default_types_are_chase_and_melee_with_their_old_numbers() -> void:
	var expected: Dictionary = {
		"grunt": [10, 0.5, 350.0], "runner": [6, 0.5, 250.0], "brute": [20, 0.8, 600.0]
	}
	for type_name: String in expected:
		var data: EnemyData = load("res://enemies/data/%s.tres" % type_name)
		assert_true(data.movement is ChaseMovement, type_name)
		var melee := data.attack as MeleeAttack
		assert_not_null(melee, type_name)
		if melee != null:
			assert_eq([melee.damage, melee.interval, melee.knockback], expected[type_name])


func _ranged(lead: float) -> RangedAttack:
	var ranged := RangedAttack.new()
	ranged.weapon = load("res://enemies/behaviours/data/enemy_bolt.tres")
	ranged.attack_range = 600.0
	ranged.interval = 1.2
	ranged.lead = lead
	return ranged


func test_ranged_fires_only_when_ready_in_range_and_seeing() -> void:
	var ranged: RangedAttack = _ranged(0.5)
	assert_true(ranged.wants_to_attack(0.0, 500.0, true))
	assert_false(ranged.wants_to_attack(0.3, 500.0, true), "cooldown")
	assert_false(ranged.wants_to_attack(0.0, 700.0, true), "out of range")
	assert_false(ranged.wants_to_attack(0.0, 500.0, false), "behind a wall")


func test_ranged_aims_at_a_still_target() -> void:
	var ranged: RangedAttack = _ranged(1.0)
	assert_eq(ranged.aim_point(Vector2.ZERO, Vector2(300, 0), Vector2.ZERO), Vector2(300, 0))


func test_ranged_leads_a_moving_target_by_its_share() -> void:
	var own := Vector2.ZERO
	var target := Vector2(400, 0)
	var velocity := Vector2(0, 200)
	var full: Vector2 = _ranged(1.0).aim_point(own, target, velocity)
	var none: Vector2 = _ranged(0.0).aim_point(own, target, velocity)
	var half: Vector2 = _ranged(0.5).aim_point(own, target, velocity)
	assert_eq(none, target)
	assert_gt(full.y, 150.0, "full lead aims well ahead")
	assert_almost_eq(half.y, full.y / 2.0, 0.01)
	var flight: float = own.distance_to(full) / 420.0
	assert_almost_eq(full.y, 200.0 * flight, 0.5, "the bolt meets the target")


func test_ranged_shot_is_on_the_enemy_team_from_the_muzzle() -> void:
	var shot: Shot = _ranged(0.0).make_shot(Vector2(100, 100), Vector2(100, 400), Vector2.ZERO)
	assert_eq(shot.team, ChaserEnemy.TEAM)
	assert_eq(shot.origin, Vector2(100, 120))
	assert_eq(shot.direction, Vector2(0, 1))
	assert_eq(shot.damage, 12)
	assert_eq(shot.projectile, WeaponData.Projectile.ENEMY_BOLT)


func test_enemy_shooter_ids_are_fair_dodged_and_never_a_bot() -> void:
	var id: int = Shot.enemy_shooter_id(7)
	assert_lt(id, 0, "negative: TimelineHits tests it on the target's timeline")
	assert_true(Shot.is_enemy_shooter(id))
	assert_false(Shot.is_enemy_shooter(-8), "bot ids are small negatives")
	assert_ne(Shot.enemy_shooter_id(1), Shot.enemy_shooter_id(2))


func test_only_ranged_needs_a_line_of_sight_ray() -> void:
	assert_false(_melee(10, 0.5, 350.0).needs_line_of_sight())
	assert_true(_ranged(0.5).needs_line_of_sight())


func test_keep_distance_walks_in_backs_off_and_holds() -> void:
	var keep := KeepDistanceMovement.new()
	keep.min_distance = 250.0
	keep.max_distance = 450.0
	keep.retreat_margin = 50.0
	var target := Vector2.ZERO
	assert_eq(keep.goal(Vector2(800, 0), target), target, "too far: walk in")
	assert_eq(keep.goal(Vector2(100, 0), target), Vector2(300, 0), "too close: back off")
	assert_eq(keep.goal(Vector2(350, 0), target), Vector2(350, 0), "in range: hold")


func test_heal_pulse_amount_and_range() -> void:
	var pulse := HealPulseAttack.new()
	pulse.radius = 200.0
	pulse.heal_share = 0.12
	assert_eq(pulse.heal_amount(100), 12)
	assert_eq(pulse.heal_amount(650), 78)
	assert_eq(pulse.heal_amount(3), 1, "always at least 1")
	assert_true(pulse.reaches(Vector2.ZERO, Vector2(200, 0)))
	assert_false(pulse.reaches(Vector2.ZERO, Vector2(150, 150)), "212 px is out of range")
	assert_true(pulse.wants_to_attack(0.0, INF, false), "pulses with no player in sight")
	assert_false(pulse.wants_to_attack(0.5, 10.0, true))
