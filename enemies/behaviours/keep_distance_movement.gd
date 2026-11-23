class_name KeepDistanceMovement
extends EnemyMovement
## Stays between `min_distance` and `max_distance` from its target: walks in when too far,
## backs away when too close, holds its ground in between (a shooter's spacing).

@export_range(0.0, 3000.0) var min_distance: float = 250.0
@export_range(0.0, 3000.0) var max_distance: float = 450.0
## How far past min_distance it backs off, so it doesn't stop right at the edge (px).
@export_range(0.0, 500.0) var retreat_margin: float = 60.0


func goal(own: Vector2, target: Vector2) -> Vector2:
	var distance: float = own.distance_to(target)
	if distance > max_distance:
		return target
	if distance < min_distance:
		var away: Vector2 = target.direction_to(own)
		if away.is_zero_approx():
			away = Vector2.RIGHT
		return target + away * (min_distance + retreat_margin)
	return own
