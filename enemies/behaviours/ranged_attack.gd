class_name RangedAttack
extends EnemyAttack
## Fires `weapon`'s bullets at its target when it can see it within `attack_range`, leading a
## moving target by `lead` (0 = at it, 1 = full intercept). The shot goes through
## EventBus.shot_fired like a player's, on the enemies' team; its shooter id is negative, so
## remote players get fair dodging (TimelineHits) against it.

## The bullet: speed, damage, radius, lifetime, knockback, projectile look.
@export var weapon: WeaponData
## Fires only at targets this close (px).
@export_range(0.0, 3000.0) var attack_range: float = 600.0
## Share of the intercept lead to aim with (0..1).
@export_range(0.0, 1.0) var lead: float = 0.5
## Bullets start this far from the enemy's center, toward the aim (px).
@export_range(0.0, 100.0) var muzzle_distance: float = 20.0


func needs_line_of_sight() -> bool:
	return true


func wants_to_attack(cooldown_left: float, distance: float, can_see: bool) -> bool:
	return cooldown_left <= 0.0 and can_see and distance <= attack_range


## Pure: where to aim at a target at `target` moving at `velocity`.
func aim_point(own: Vector2, target: Vector2, velocity: Vector2) -> Vector2:
	var full: Vector2 = AimLead.intercept(
		own, target, velocity, weapon.bullet_speed, weapon.bullet_lifetime
	)
	return target.lerp(full, lead)


## Pure: the shot this enemy fires (ids and ticks are filled in by `perform`).
func make_shot(own: Vector2, target: Vector2, velocity: Vector2) -> Shot:
	var direction: Vector2 = own.direction_to(aim_point(own, target, velocity))
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var shot: Shot = Shot.from_weapon(weapon, own + direction * muzzle_distance, direction)
	shot.team = ChaserEnemy.TEAM
	return shot


func add_stats(stats: EnemyStats, weight: float) -> void:
	if weapon != null:
		var damage: float = weapon.damage * weapon.pellets
		stats.add(EnemyStats.RANGED_DPS, weight * damage / cycle_seconds())


func perform(enemy: Node2D, target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	var shooter := enemy as ChaserEnemy
	if shooter == null or target == null:
		return false
	var velocity: Vector2 = Vector2.ZERO
	if target is CharacterBody2D:
		velocity = (target as CharacterBody2D).velocity
	var shot: Shot = make_shot(enemy.global_position, _aim_at(target), velocity)
	shot.shooter_id = shooter.shooter_id()
	shot.shot_id = shooter.next_shot_id()
	shot.fire_tick = NetworkManager.clock.server_tick_now()
	shot.view_tick = shot.fire_tick
	EventBus.shot_fired.emit(shot)
	return true


func _aim_at(target: Node2D) -> Vector2:
	var hitbox := target.get_node_or_null("HitboxComponent") as HitboxComponent
	return hitbox.center() if hitbox != null else target.global_position
