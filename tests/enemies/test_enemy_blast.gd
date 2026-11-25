extends GutTest
## A Bomber's blast (BlastAttack): when the fuse lights, who it hurts and how much, and how its
## look's spark blinks (BombLook).


func _bomb() -> BlastAttack:
	var bomb := BlastAttack.new()
	bomb.interval = 1.0
	bomb.windup = 0.7
	bomb.trigger_range = 70.0
	bomb.radius = 110.0
	bomb.player_damage = 30
	bomb.enemy_damage = 80
	return bomb


func test_lights_its_fuse_only_up_close() -> void:
	var bomb: BlastAttack = _bomb()
	assert_true(bomb.wants_to_attack(0.0, 60.0, true))
	assert_false(bomb.wants_to_attack(0.0, 90.0, true), "too far")
	assert_true(bomb.wants_to_attack(0.0, 60.0, false), "a wall doesn't stop a fuse")
	assert_true(bomb.stands_still_while_winding_up(), "it stops while the fuse burns")


func test_a_burnt_out_fuse_hurts_everyone_but_a_pop_only_enemies() -> void:
	assert_true(BlastAttack.hurts(ChaserEnemy.TEAM, true))
	assert_true(BlastAttack.hurts(&"players", true), "the fuse burned out")
	assert_true(BlastAttack.hurts(ChaserEnemy.TEAM, false), "a pop still hurts enemies")
	assert_false(BlastAttack.hurts(&"players", false), "a pop never hurts players")


func test_damage_and_reach() -> void:
	var bomb: BlastAttack = _bomb()
	assert_eq(bomb.damage_to(ChaserEnemy.TEAM), 80)
	assert_eq(bomb.damage_to(&"players"), 30)
	assert_true(bomb.reaches(Vector2.ZERO, Vector2(110, 0)), "the edge counts")
	assert_false(bomb.reaches(Vector2.ZERO, Vector2(80, 80)), "113 px is outside")


func test_counts_in_the_difficulty_score() -> void:
	var stats := EnemyStats.new()
	_bomb().add_stats(stats, 1.0)
	assert_almost_eq(stats.value(EnemyStats.MELEE_DPS), 30.0 / 1.7, 0.001)


func test_spark_blinks_faster_as_the_fuse_burns() -> void:
	var look := BombLook.new()
	look.idle_blinks = 1.0
	look.fuse_blinks = 10.0
	assert_true(look.is_lit(0.2, 0.0), "first half of a slow blink")
	assert_false(look.is_lit(0.7, 0.0), "second half")
	assert_false(look.is_lit(0.07, 1.0), "at 10 blinks/s, 0.07 s is in the dark half")
	assert_true(look.is_lit(0.12, 1.0))
