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
