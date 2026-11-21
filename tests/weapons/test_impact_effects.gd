extends GutTest
## ImpactEffects: what shock arcs and blasts reach, and what they do to it.

var candidates: Array[HitboxComponent] = []


func before_each() -> void:
	candidates = []


func _target(at: Vector2, team: StringName = &"enemies", owner: int = 0) -> HitboxComponent:
	var health := HealthComponent.new()
	health.max_health = 100
	add_child_autofree(health)
	var status := StatusEffectsComponent.new()
	status.health = health
	add_child_autofree(status)
	status.set_physics_process(false)
	var hitbox := HitboxComponent.new()
	hitbox.health = health
	hitbox.status = status
	hitbox.team = team
	hitbox.owner_id = owner
	hitbox.position = at
	add_child_autofree(hitbox)
	candidates.append(hitbox)
	return hitbox


func _shot(effects: HitEffects) -> Shot:
	var shot := Shot.new()
	shot.shooter_id = 1
	shot.team = &"players"
	shot.damage = 40
	shot.effects = effects
	return shot


func _shock(chains: int, jump_range: float) -> HitEffects:
	var effects := HitEffects.new()
	effects.shock_chains = chains
	effects.shock_share = 0.5
	effects.shock_range = jump_range
	return effects


func _blast(radius: float) -> HitEffects:
	var effects := HitEffects.new()
	effects.blast_share = 0.25
	effects.blast_radius = radius
	return effects


func _health(hitbox: HitboxComponent) -> int:
	return hitbox.health.current_health


func test_arc_jumps_to_the_nearest_foe_each_time() -> void:
	var first: HitboxComponent = _target(Vector2.ZERO)
	var far: HitboxComponent = _target(Vector2(90, 0))
	var near: HitboxComponent = _target(Vector2(50, 0))
	_target(Vector2(400, 0))
	var chain: Array[HitboxComponent] = ImpactEffects.chain_targets(
		_shot(_shock(3, 60.0)), first, candidates
	)
	assert_eq(chain, [near, far] as Array[HitboxComponent], "the third is out of range")


func test_arc_skips_teammates_and_the_shooter() -> void:
	var first: HitboxComponent = _target(Vector2.ZERO)
	_target(Vector2(20, 0), &"players")
	_target(Vector2(25, 0), &"team_9", 1)
	var foe: HitboxComponent = _target(Vector2(30, 0))
	var chain: Array[HitboxComponent] = ImpactEffects.chain_targets(
		_shot(_shock(3, 100.0)), first, candidates
	)
	assert_eq(chain, [foe] as Array[HitboxComponent])


func test_hit_with_arcs_damages_the_chain_and_passes_on_burn() -> void:
	var first: HitboxComponent = _target(Vector2.ZERO)
	var second: HitboxComponent = _target(Vector2(50, 0))
	var effects: HitEffects = _shock(2, 100.0)
	effects.burn_dps = 4.0
	effects.burn_seconds = 2.0
	var flashes: Array[ImpactEffects.Flash] = ImpactEffects.on_hit(
		_shot(effects), first, Vector2.ZERO, candidates
	)
	assert_eq(flashes.size(), 1)
	assert_eq(flashes[0].kind, HitEffects.SHOCK)
	assert_eq(_health(first), 100, "the bullet's own damage is the Bullet's job")
	assert_eq(_health(second), 80, "half of 40")
	assert_true(first.status.is_burning())
	assert_true(second.status.is_burning(), "the arc passed the burn on")


func test_blast_hits_foes_in_radius_but_not_the_target_twice() -> void:
	var target: HitboxComponent = _target(Vector2.ZERO)
	var close: HitboxComponent = _target(Vector2(60, 0))
	var outside: HitboxComponent = _target(Vector2(200, 0))
	var friend: HitboxComponent = _target(Vector2(10, 0), &"players")
	var flashes: Array[ImpactEffects.Flash] = ImpactEffects.on_hit(
		_shot(_blast(80.0)), target, Vector2.ZERO, candidates
	)
	assert_eq(flashes.size(), 1)
	assert_eq(flashes[0].to.x, 80.0, "the flash carries the radius")
	assert_eq(_health(target), 100)
	assert_eq(_health(close), 90, "a quarter of 40")
	assert_eq(_health(outside), 100)
	assert_eq(_health(friend), 100)


func test_blast_goes_off_where_a_bullet_stops() -> void:
	var close: HitboxComponent = _target(Vector2(30, 0))
	var flashes: Array[ImpactEffects.Flash] = ImpactEffects.on_stop(
		_shot(_blast(50.0)), Vector2.ZERO, candidates
	)
	assert_eq(flashes.size(), 1)
	assert_eq(_health(close), 90)


func test_plain_bullets_do_nothing_extra() -> void:
	var target: HitboxComponent = _target(Vector2.ZERO)
	_target(Vector2(10, 0))
	assert_true(ImpactEffects.on_hit(_shot(null), target, Vector2.ZERO, candidates).is_empty())
	assert_true(ImpactEffects.on_stop(_shot(null), Vector2.ZERO, candidates).is_empty())


func test_secondary_damage_is_at_least_one() -> void:
	var shot: Shot = _shot(null)
	shot.damage = 1
	assert_eq(ImpactEffects.secondary_damage(shot, 0.1), 1)
