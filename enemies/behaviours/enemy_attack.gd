class_name EnemyAttack
extends Resource
## How an enemy attacks. The host's enemy asks `wants_to_attack()` (pure) each tick and, when
## it says yes, calls `perform()`; a true result restarts the cooldown. Stateless: the cooldown
## lives on the enemy. Subclasses: MeleeAttack. Set on EnemyData.attack.

## Seconds between attacks.
@export_range(0.05, 10.0) var interval: float = 1.0


## Whether `wants_to_attack` needs real line of sight (the enemy casts a ray only then, and
## only once the cooldown is over; otherwise `can_see` is just "has a target").
func needs_line_of_sight() -> bool:
	return false


## Pure: does it want to attack now? `distance` is to its target, `can_see` = line of sight.
func wants_to_attack(cooldown_left: float, _distance: float, _can_see: bool) -> bool:
	return cooldown_left <= 0.0


## Host: attack. `touching` = player hitboxes in its contact area. True = it attacked.
func perform(_enemy: Node2D, _target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	return false
