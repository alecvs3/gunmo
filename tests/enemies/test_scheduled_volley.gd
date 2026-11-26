extends GutTest
## Wind-up volleys that lock their aim early (LatencyPolicy.schedule_windup_shots): when the
## aim locks, which attacks may, and the shots built ahead are the ones that will leave.

const VOLLEY_DATA: String = "res://tests/net/data/test_volley.tres"


func test_the_aim_locks_aim_lock_seconds_before_firing() -> void:
	assert_almost_eq(EnemyAttack.lock_left(0.4, 0.25), 0.15, 0.0001, "still aiming")
	assert_almost_eq(EnemyAttack.lock_left(0.25, 0.25), 0.0, 0.0001, "locks now")
	assert_lt(EnemyAttack.lock_left(0.1, 0.25), 0.0, "already locked")


func test_only_volleys_with_a_long_enough_windup_schedule_shots() -> void:
	var volley: VolleyAttack = (load(VOLLEY_DATA) as EnemyData).attack
	assert_true(volley.schedules_shots(0.25), "0.4 s windup")
	assert_false(volley.schedules_shots(0.5), "too short to lock that early")
	var no_gun := VolleyAttack.new()
	no_gun.windup = 1.0
	assert_false(no_gun.schedules_shots(0.25))
	var melee := MeleeAttack.new()
	melee.windup = 1.0
	assert_false(melee.schedules_shots(0.25), "only attacks that fire shots")


func test_shots_built_ahead_leave_on_their_tick_along_the_volley() -> void:
	var enemy: ChaserEnemy = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
	enemy.enemy_data = load(VOLLEY_DATA)
	add_child_autofree(enemy)
	var target := Node2D.new()
	target.position = enemy.global_position + Vector2(200, 0)
	add_child_autofree(target)
	var volley: VolleyAttack = enemy.enemy_data.attack
	var shots: Array[Shot] = volley.build_shots(enemy, target, 500.0)
	assert_eq(shots.size(), volley.shots)
	var expected: Array[Vector2] = volley.directions(Vector2.RIGHT)
	for i in shots.size():
		assert_eq(shots[i].fire_tick, 500.0, "leaves on the locked tick")
		assert_almost_eq(shots[i].direction.angle_to(expected[i]), 0.0, 0.0001)
		assert_eq(shots[i].shooter_id, enemy.shooter_id())
	var again: Array[Shot] = volley.build_shots(enemy, target, 600.0)
	assert_ne(again[0].shot_id, shots[0].shot_id, "a new volley never reuses ids")
