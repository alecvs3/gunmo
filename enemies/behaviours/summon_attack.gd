class_name SummonAttack
extends EnemyAttack
## Calls `count` enemies of type `into` to where it stands (EventBus enemy_split, like a
## Splitter's death), at most while fewer than `max_alive` enemies are in the level.

@export var into: EnemyData
@export_range(1, 12) var count: int = 3
@export_range(1, 500) var max_alive: int = 30


## Pure: whether there is room to summon with `alive` enemies in the level.
func has_room(alive: int) -> bool:
	return alive + count <= max_alive


func add_stats(stats: EnemyStats, weight: float) -> void:
	var called: EnemyStats = EnemyStats.of(into, stats.aim_cone_degrees, stats.depth + 1)
	var health: float = called.value(EnemyStats.HEALTH) * count
	stats.add(EnemyStats.SUMMONED_HEALTH, weight * health / cycle_seconds())


func perform(enemy: Node2D, _target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	if into == null or not has_room(enemy.get_tree().get_nodes_in_group(Groups.ENEMIES).size()):
		return false
	EventBus.enemy_split.emit(enemy, into, count)
	return true
