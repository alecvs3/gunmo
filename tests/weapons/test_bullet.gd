extends GutTest

const BULLET_SCENE: PackedScene = preload("res://weapons/bullet.tscn")

var data: WeaponData


func before_each() -> void:
	data = WeaponData.new()
	data.damage = 35
	data.bullet_speed = 500.0
	data.bullet_lifetime = 0.5


func test_spawn_data_comes_from_weapon_data() -> void:
	var spawn_data: Dictionary = Bullet.make_spawn_data(data, Vector2(10, 20), Vector2(0, 5), 4)
	assert_eq(spawn_data["damage"], 35)
	assert_eq(spawn_data["speed"], 500.0)
	assert_eq(spawn_data["lifetime"], 0.5)
	assert_eq(spawn_data["shooter_id"], 4)
	assert_eq(spawn_data["position"], Vector2(10, 20))
	assert_eq(spawn_data["direction"], Vector2.DOWN, "direction is normalized")


func test_hit_deals_weapon_damage_with_shooter_credit() -> void:
	var health: HealthComponent = _make_target(100)
	var bullet: Bullet = _make_bullet()
	watch_signals(health)

	bullet.apply_hit(_hitbox_for(health))

	assert_eq(health.current_health, 65)
	assert_signal_emitted_with_parameters(health, "damaged", [35, 4])


func test_bullet_hits_only_once() -> void:
	var first: HealthComponent = _make_target(100)
	var second: HealthComponent = _make_target(100)
	var bullet: Bullet = _make_bullet()

	bullet.apply_hit(_hitbox_for(first))
	bullet.apply_hit(_hitbox_for(second))

	assert_eq(first.current_health, 65)
	assert_eq(second.current_health, 100)


func test_pistol_kills_test_enemy_in_expected_shots() -> void:
	var pistol: WeaponData = load("res://weapons/data/pistol.tres")
	var enemy_data: EnemyData = load("res://enemies/data/test_enemy.tres")
	var expected_shots: int = ceili(float(enemy_data.max_health) / pistol.damage)
	var health: HealthComponent = _make_target(enemy_data.max_health)
	var hitbox: HitboxComponent = _hitbox_for(health)
	for i in expected_shots - 1:
		_make_bullet(pistol).apply_hit(hitbox)
	assert_false(health.is_dead(), "still alive one shot before the expected count")
	_make_bullet(pistol).apply_hit(hitbox)
	assert_true(health.is_dead())


func test_bullet_moves_along_direction_at_speed() -> void:
	var bullet: Bullet = _make_bullet()
	bullet.set_physics_process(false)
	bullet._physics_process(0.1)
	assert_almost_eq(bullet.position.x, 50.0, 0.001)
	assert_almost_eq(bullet.position.y, 0.0, 0.001)


func _make_bullet(weapon: WeaponData = data) -> Bullet:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.setup(Bullet.make_spawn_data(weapon, Vector2.ZERO, Vector2.RIGHT, 4))
	add_child_autofree(bullet)
	return bullet


func _make_target(max_health: int) -> HealthComponent:
	var health := HealthComponent.new()
	health.max_health = max_health
	add_child_autofree(health)
	return health


func _hitbox_for(health: HealthComponent) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	add_child_autofree(hitbox)
	return hitbox
