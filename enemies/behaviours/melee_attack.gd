class_name MeleeAttack
extends EnemyAttack
## Hurts and pushes away every player it touches, then waits `interval`.

## Damage per touch.
@export_range(0, 1000) var damage: int = 1
## Push given to a player it touches (px/s, away from the enemy).
@export_range(0.0, 3000.0) var knockback: float = 0.0


## Pure: the push for a player whose hitbox center is at `victim`.
func push(own: Vector2, victim: Vector2) -> Vector2:
	return own.direction_to(victim) * knockback


func add_stats(stats: EnemyStats, weight: float) -> void:
	stats.add(EnemyStats.MELEE_DPS, weight * damage / cycle_seconds())


func perform(enemy: Node2D, _target: Node2D, touching: Array[HitboxComponent]) -> bool:
	for hitbox in touching:
		hitbox.hit(damage, 0, push(enemy.global_position, hitbox.center()))
	return not touching.is_empty()
