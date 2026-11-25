class_name ChargeAttack
extends EnemyAttack
## A Charger's dash. When a player it can see is close, it stops and warns (the windup: every
## peer sees a line along where it will go, and the direction is locked when the warning
## starts, so a sidestep always works). Then it dashes straight ahead. The first players it
## touches take `damage` and a big push and the dash ends; running head-on into a wall stuns
## it (it can't act and takes more damage). The enemy runs the dash itself (EnemyDash); this
## holds the numbers and decides when to start.

## Starts a dash only at a target this close (px) that it can see.
@export_range(0.0, 2000.0) var trigger_range: float = 340.0
## Dash speed (px/s).
@export_range(0.0, 3000.0) var dash_speed: float = 620.0
## How far one dash goes at most (px); the warning line is this long.
@export_range(0.0, 2000.0) var dash_distance: float = 420.0
## Damage to a player the dash hits.
@export_range(0, 1000) var damage: int = 1
## Push given to a player the dash hits (px/s, away from the enemy).
@export_range(0.0, 3000.0) var knockback: float = 0.0
## Seconds stunned after running into a wall.
@export_range(0.0, 10.0) var stun_seconds: float = 1.5
## Extra damage it takes while stunned (0.5 = +50%).
@export_range(0.0, 5.0) var stun_damage_bonus: float = 0.5
## Seconds it stands still after a dash that didn't hit a wall.
@export_range(0.0, 5.0) var recover_seconds: float = 0.4


func needs_line_of_sight() -> bool:
	return true


func stands_still_while_winding_up() -> bool:
	return true


func wants_to_attack(cooldown_left: float, distance: float, can_see: bool) -> bool:
	return cooldown_left <= 0.0 and can_see and distance <= trigger_range


## Host: the windup is over, so the dash begins (the way it aimed when the warning started).
func perform(enemy: Node2D, _target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	var chaser := enemy as ChaserEnemy
	if chaser == null:
		return false
	chaser.start_dash(self)
	return true


## Pure: seconds a full-length dash lasts.
func dash_seconds() -> float:
	return dash_distance / maxf(dash_speed, 1.0)


## A dash takes time too: windup, the dash, the pause after it, then the cooldown.
func cycle_seconds() -> float:
	return maxf(interval + windup + dash_seconds() + recover_seconds, 0.05)


func add_stats(stats: EnemyStats, weight: float) -> void:
	stats.add(EnemyStats.MELEE_DPS, weight * damage / cycle_seconds())
