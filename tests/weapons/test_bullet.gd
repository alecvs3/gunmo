extends GutTest
## Bullet damage driven by WeaponData, through the real host-side hit path
## (LagCompensator sweep -> HitboxComponent -> HealthComponent / KnockbackComponent).

const BULLET_SCENE: PackedScene = preload("res://weapons/bullet.tscn")

var data: WeaponData


func before_each() -> void:
	data = WeaponData.new()
	data.damage = 35
	data.bullet_speed = 600.0
	data.bullet_lifetime = 1.0
	data.bullet_radius = 2.0
	data.knockback = 100.0


func test_hit_deals_weapon_damage_with_shooter_credit_and_push() -> void:
	var target: Dictionary = _make_target(Vector2(30, 0), 100)
	watch_signals(target["health"])
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT)
	_tick(bullet, 10)
	assert_eq((target["health"] as HealthComponent).current_health, 65)
	assert_signal_emitted_with_parameters(target["health"], "damaged", [35, 4])
	assert_almost_eq((target["knockback"] as KnockbackComponent).velocity.x, 100.0, 0.001)


func test_bullet_hits_only_the_first_target() -> void:
	var near: Dictionary = _make_target(Vector2(30, 0), 100)
	var far: Dictionary = _make_target(Vector2(60, 0), 100)
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT)
	_tick(bullet, 20)
	assert_eq((near["health"] as HealthComponent).current_health, 65)
	assert_eq((far["health"] as HealthComponent).current_health, 100)


func test_fast_bullet_does_not_tunnel_through_thin_target() -> void:
	data.bullet_speed = 6000.0
	var target: Dictionary = _make_target(Vector2(150, 0), 100, 4.0)
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT)
	_tick(bullet, 3)
	assert_eq((target["health"] as HealthComponent).current_health, 65, "100 px per tick")


func test_a_hit_deals_the_shots_damage_type() -> void:
	var target: Dictionary = _make_target(Vector2(30, 0), 100)
	var swarm: EnemyTrait = load("res://enemies/data/traits/swarm.tres")
	var traits: Array[EnemyTrait] = [swarm]
	(target["health"] as HealthComponent).type_multipliers = EnemyTrait.profile(traits)
	data.damage_type = DamageType.Type.BLAST
	_tick(_fire(Vector2.ZERO, Vector2.RIGHT), 10)
	assert_eq((target["health"] as HealthComponent).current_health, 47, "35 x 1.5, rounded")


func test_same_team_is_not_hit() -> void:
	var friend: Dictionary = _make_target(Vector2(30, 0), 100)
	(friend["hitbox"] as HitboxComponent).team = &"players"
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT, &"players")
	_tick(bullet, 10)
	assert_eq((friend["health"] as HealthComponent).current_health, 100)


func test_pistol_kills_a_grunt_in_expected_shots() -> void:
	var pistol: WeaponData = load("res://weapons/data/pistol.tres")
	var enemy_data: EnemyData = load("res://enemies/data/grunt.tres")
	var shots_needed: int = ceili(float(enemy_data.max_health) / pistol.damage)
	var target: Dictionary = _make_target(Vector2(40, 0), enemy_data.max_health)
	var health: HealthComponent = target["health"]
	data = pistol
	for i in shots_needed - 1:
		_tick(_fire(Vector2.ZERO, Vector2.RIGHT), 10)
	assert_false(health.is_dead(), "still alive one shot before the expected count")
	_tick(_fire(Vector2.ZERO, Vector2.RIGHT), 10)
	assert_true(health.is_dead())


func test_bullet_ends_after_lifetime() -> void:
	data.bullet_lifetime = 0.1
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT)
	watch_signals(bullet)
	_tick(bullet, 6)
	assert_signal_emitted(bullet, "finished")


## An enemy standing inside the shooter, between their body and the muzzle (#124).
func test_target_between_body_and_muzzle_is_hit() -> void:
	var target: Dictionary = _make_target(Vector2(12, 0), 100)
	var bullet: Bullet = _fire(Vector2(38, 0), Vector2.RIGHT)
	bullet.shot.hit_origin = Vector2.ZERO
	_tick(bullet, 10)
	assert_eq((target["health"] as HealthComponent).current_health, 65)


func test_target_behind_the_shooter_is_not_hit() -> void:
	var target: Dictionary = _make_target(Vector2(-30, 0), 100)
	var bullet: Bullet = _fire(Vector2(38, 0), Vector2.RIGHT)
	bullet.shot.hit_origin = Vector2.ZERO
	_tick(bullet, 10)
	assert_eq((target["health"] as HealthComponent).current_health, 100)


func test_hit_origin_defaults_to_the_muzzle() -> void:
	var shot: Shot = Shot.from_weapon(data, Vector2(38, 5), Vector2.RIGHT)
	assert_eq(shot.hit_origin, Vector2(38, 5), "enemies' shots keep testing from where they start")


func test_our_own_bullet_tells_when_it_lands_on_our_screen() -> void:
	var target: Dictionary = _make_target(Vector2(30, 0), 100)
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT, &"tests", Bullet.Mode.PREDICTED)
	watch_signals(bullet)
	_tick(bullet, 10)
	assert_signal_emit_count(bullet, "hit_predicted", 1)
	var landed: Array = get_signal_parameters(bullet, "hit_predicted")
	assert_eq(landed[2], target["hitbox"], "on the target it stopped on")
	assert_eq((target["health"] as HealthComponent).current_health, 100, "it deals nothing")


func test_the_hosts_bullet_never_predicts() -> void:
	_make_target(Vector2(30, 0), 100)
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT)
	watch_signals(bullet)
	_tick(bullet, 10)
	assert_signal_emit_count(bullet, "hit_landed", 1)
	assert_signal_not_emitted(bullet, "hit_predicted")


func _fire(
	origin: Vector2,
	direction: Vector2,
	team: StringName = &"tests",
	mode: Bullet.Mode = Bullet.Mode.AUTHORITATIVE
) -> Bullet:
	var shot: Shot = Shot.from_weapon(data, origin, direction)
	shot.shooter_id = 4
	shot.team = team
	shot.view_tick = NetworkManager.clock.tick
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.setup(shot, mode)
	add_child_autofree(bullet)
	bullet.set_physics_process(false)
	return bullet


func _tick(bullet: Bullet, ticks: int) -> void:
	for i in ticks:
		if is_instance_valid(bullet) and not bullet.is_queued_for_deletion():
			bullet._physics_process(NetClock.tick_delta())


func _make_target(at: Vector2, max_health: int, radius: float = 16.0) -> Dictionary:
	var health := HealthComponent.new()
	health.max_health = max_health
	var knockback := KnockbackComponent.new()
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	hitbox.knockback = knockback
	hitbox.team = &"targets"
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = radius
	hitbox.add_child(shape)
	hitbox.position = at
	add_child_autofree(health)
	add_child_autofree(knockback)
	add_child_autofree(hitbox)
	return {"health": health, "knockback": knockback, "hitbox": hitbox}


func test_pierce_passes_through_targets_then_stops() -> void:
	data.pierce = 1
	var first: Dictionary = _make_target(Vector2(30, 0), 100)
	var second: Dictionary = _make_target(Vector2(80, 0), 100)
	var third: Dictionary = _make_target(Vector2(130, 0), 100)
	var bullet: Bullet = _fire(Vector2.ZERO, Vector2.RIGHT)
	watch_signals(bullet)
	_tick(bullet, 30)
	assert_eq((first["health"] as HealthComponent).current_health, 65)
	assert_eq((second["health"] as HealthComponent).current_health, 65, "pierced into the second")
	assert_eq((third["health"] as HealthComponent).current_health, 100, "pierce 1 = two targets")
	assert_signal_emit_count(bullet, "hit_landed", 2)


func test_pierced_target_is_not_hit_twice() -> void:
	data.pierce = 3
	var only: Dictionary = _make_target(Vector2(30, 0), 100)
	_tick(_fire(Vector2.ZERO, Vector2.RIGHT), 30)
	assert_eq((only["health"] as HealthComponent).current_health, 65)
