class_name HealPulseAttack
extends EnemyAttack
## A support enemy's "attack": every `interval` it heals the wounded enemies within `radius`
## (itself included) by `heal_share` of their max health, times their heal_received (bosses
## take little). It never hurts players, so killing it first is the counter.

@export_range(0.0, 2000.0) var radius: float = 220.0
## Share of each enemy's max health healed per pulse (0.15 = 15%).
@export_range(0.0, 1.0) var heal_share: float = 0.15


## Pure: the points one pulse gives an enemy with `max_health` (at least 1).
func heal_amount(max_health: int) -> int:
	return maxi(roundi(max_health * heal_share), 1)


## Pure: whether an enemy at `other` is close enough to `own` to be healed.
func reaches(own: Vector2, other: Vector2) -> bool:
	return own.distance_squared_to(other) <= radius * radius


func wants_to_attack(cooldown_left: float, _distance: float, _can_see: bool) -> bool:
	return cooldown_left <= 0.0


func add_stats(stats: EnemyStats, weight: float) -> void:
	stats.add(EnemyStats.HEAL_SHARE, weight * heal_share / cycle_seconds())


func perform(enemy: Node2D, _target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	for node in enemy.get_tree().get_nodes_in_group(Groups.ENEMIES):
		var other := node as ChaserEnemy
		if (
			other != null
			and other.is_wounded()
			and reaches(enemy.global_position, other.global_position)
		):
			other.heal(heal_amount(other.max_health()))
	return true
