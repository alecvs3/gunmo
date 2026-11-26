class_name EnemyAttack
extends Resource
## How an enemy attacks. The host's enemy asks `wants_to_attack()` (pure) each tick and, when
## it says yes, calls `perform()`; a true result restarts the cooldown. Stateless: the cooldown
## lives on the enemy. Subclasses: MeleeAttack, ChargeAttack... Set on EnemyData.attack.

## Seconds between attacks.
@export_range(0.05, 10.0) var interval: float = 1.0
## Telegraph: seconds it warns (every peer sees the enemy charge up) before `perform`.
## 0 = attacks at once.
@export_range(0.0, 5.0) var windup: float = 0.0


## Whether `wants_to_attack` needs real line of sight (the enemy casts a ray only then, and
## only once the cooldown is over; otherwise `can_see` is just "has a target").
func needs_line_of_sight() -> bool:
	return false


## Whether it stops walking (and keeps facing where it aimed) while it winds up.
func stands_still_while_winding_up() -> bool:
	return false


## Pure: does it want to attack now? `distance` is to its target, `can_see` = line of sight.
func wants_to_attack(cooldown_left: float, _distance: float, _can_see: bool) -> bool:
	return cooldown_left <= 0.0


## Host: attack. `touching` = player hitboxes in its contact area. True = it attacked.
func perform(_enemy: Node2D, _target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	return false


## Whether this attack, with a windup, can lock its aim `aim_lock` seconds before it fires and
## send its shots ahead (LatencyPolicy.schedule_windup_shots). Only attacks that fire shots.
func schedules_shots(_aim_lock: float) -> bool:
	return false


## Host: the shots this attack would fire, stamped to leave at `fire_tick` (attacks that
## schedule shots override it).
func build_shots(_enemy: Node2D, _target: Node2D, _fire_tick: float) -> Array[Shot]:
	return []


## Pure: seconds of a windup left until its aim locks (0 or less = locked).
static func lock_left(windup_left: float, aim_lock: float) -> float:
	return windup_left - aim_lock


## Pure: seconds from one attack to the next (the windup, then the cooldown).
func cycle_seconds() -> float:
	return maxf(interval + windup, 0.05)


## Pure: adds what this attack does per second to `stats` (EnemyStats: damage, healing,
## summons), times `weight` (a boss phase's share). Every attack type overrides it, or the wave
## difficulty score can't see it.
func add_stats(_stats: EnemyStats, _weight: float) -> void:
	pass
