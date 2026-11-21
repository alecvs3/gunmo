extends GutTest
## Explosion: who a rocket's blast reaches and what it does to them.

var candidates: Array[HitboxComponent] = []


func before_each() -> void:
	candidates = []


func _target(at: Vector2, team: StringName = &"enemies", owner: int = 0) -> HitboxComponent:
	var health := HealthComponent.new()
	health.max_health = 100
	add_child_autofree(health)
	var knockback := KnockbackComponent.new()
	add_child_autofree(knockback)
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	hitbox.knockback = knockback
	hitbox.team = team
	hitbox.owner_id = owner
	hitbox.position = at
	add_child_autofree(hitbox)
	candidates.append(hitbox)
	return hitbox


func _rocket() -> Shot:
	var weapon := WeaponData.new()
	weapon.damage = 60
	weapon.knockback = 300.0
	weapon.blast_radius = 90.0
	weapon.blast_damage = 40
	weapon.projectile = WeaponData.Projectile.ROCKET
	var shot: Shot = Shot.from_weapon(weapon, Vector2.ZERO, Vector2.RIGHT)
	shot.shooter_id = 1
	shot.team = &"players"
	return shot


func _health(hitbox: HitboxComponent) -> int:
	return hitbox.health.current_health


func test_shot_takes_the_blast_from_its_weapon() -> void:
	var shot: Shot = _rocket()
	assert_eq(shot.blast_radius, 90.0)
	assert_eq(shot.blast_damage, 40)
	assert_eq(shot.projectile, WeaponData.Projectile.ROCKET)
	var plain := WeaponData.new()
	plain.blast_radius = 90.0
	assert_eq(Shot.from_weapon(plain, Vector2.ZERO, Vector2.RIGHT).blast_radius, 0.0, "no damage")


func test_blast_hurts_foes_in_radius_but_not_the_direct_hit_twice() -> void:
	var direct: HitboxComponent = _target(Vector2.ZERO)
	var near: HitboxComponent = _target(Vector2(60, 0))
	var far: HitboxComponent = _target(Vector2(200, 0))
	assert_true(Explosion.detonate(_rocket(), Vector2.ZERO, direct, candidates))
	assert_eq(_health(direct), 100, "its own damage came from the rocket itself")
	assert_eq(_health(near), 60)
	assert_eq(_health(far), 100)


func test_blast_pushes_away_from_the_center() -> void:
	var near: HitboxComponent = _target(Vector2(0, 50))
	Explosion.detonate(_rocket(), Vector2.ZERO, null, candidates)
	assert_eq(near.knockback.velocity, Vector2(0, 300))


func test_blast_spares_the_shooter_and_teammates() -> void:
	var teammate: HitboxComponent = _target(Vector2(10, 0), &"players", 2)
	var shooter: HitboxComponent = _target(Vector2(20, 0), &"team_1", 1)
	var other_player: HitboxComponent = _target(Vector2(30, 0), &"team_3", 3)
	Explosion.detonate(_rocket(), Vector2.ZERO, null, candidates)
	assert_eq(_health(teammate), 100)
	assert_eq(_health(shooter), 100, "never your own rocket, even with no teams")
	assert_eq(_health(other_player), 60, "Gun Game: other players are foes")


func test_plain_shots_dont_explode() -> void:
	var near: HitboxComponent = _target(Vector2(10, 0))
	var shot: Shot = _rocket()
	shot.blast_radius = 0.0
	assert_false(Explosion.detonate(shot, Vector2.ZERO, null, candidates))
	assert_eq(_health(near), 100)
