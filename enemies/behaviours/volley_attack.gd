class_name VolleyAttack
extends EnemyAttack
## Fires `shots` bullets of `weapon` at once: a fan of `spread_degrees` centred on its target
## (aimed), or a full ring (spread 360, fired whether or not it sees anyone). Bosses give it a
## windup (EnemyAttack.windup) so players see it coming.

@export var weapon: WeaponData
@export_range(1, 64) var shots: int = 5
## 360 = a ring all around; less = a fan towards the target.
@export_range(0.0, 360.0) var spread_degrees: float = 40.0
@export_range(0.0, 3000.0) var attack_range: float = 700.0
@export_range(0.0, 200.0) var muzzle_distance: float = 30.0


func is_ring() -> bool:
	return spread_degrees >= 360.0


func needs_line_of_sight() -> bool:
	return not is_ring()


func wants_to_attack(cooldown_left: float, distance: float, can_see: bool) -> bool:
	if cooldown_left > 0.0:
		return false
	return is_ring() or (can_see and distance <= attack_range)


## Pure: the directions of one volley around `aim` (a unit vector). A ring is spread evenly,
## starting at `aim`; a fan is centred on it.
func directions(aim: Vector2) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var spread: float = deg_to_rad(spread_degrees)
	for i in shots:
		var angle: float = 0.0
		if is_ring():
			angle = TAU * i / shots
		elif shots > 1:
			angle = -spread / 2.0 + spread * i / (shots - 1)
		found.append(aim.rotated(angle))
	return found


## Pure: how many of a volley's shots can hit one player: those within `cone_degrees`.
func shots_that_hit(cone_degrees: float) -> float:
	return shots * minf(1.0, cone_degrees / maxf(spread_degrees, 1.0))


func add_stats(stats: EnemyStats, weight: float) -> void:
	if weapon != null:
		var damage: float = weapon.damage * weapon.pellets * shots_that_hit(stats.aim_cone_degrees)
		stats.add(EnemyStats.RANGED_DPS, weight * damage / cycle_seconds())


func perform(enemy: Node2D, target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	var shots: Array[Shot] = build_shots(enemy, target, NetworkManager.clock.server_tick_now())
	for shot in shots:
		EventBus.shot_fired.emit(shot)
	return not shots.is_empty()


func schedules_shots(aim_lock: float) -> bool:
	return weapon != null and windup >= aim_lock


## Host: one volley's shots, leaving at `fire_tick` from where the enemy stands now.
func build_shots(enemy: Node2D, target: Node2D, fire_tick: float) -> Array[Shot]:
	var shots: Array[Shot] = []
	var shooter := enemy as ChaserEnemy
	if shooter == null or (target == null and not is_ring()):
		return shots
	var aim: Vector2 = Vector2.RIGHT.rotated(shooter.next_shot_id() * 0.37)
	if target != null:
		aim = enemy.global_position.direction_to(target.global_position)
	for direction in directions(aim):
		var origin: Vector2 = enemy.global_position + direction * muzzle_distance
		var shot: Shot = Shot.from_weapon(weapon, origin, direction)
		shot.team = ChaserEnemy.TEAM
		shot.shooter_id = shooter.shooter_id()
		shot.shot_id = shooter.next_shot_id()
		shot.fire_tick = fire_tick
		shot.view_tick = fire_tick
		shots.append(shot)
	return shots
