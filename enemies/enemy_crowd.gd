class_name EnemyCrowd
extends Resource
## How enemies make room for each other. They don't block each other (only walls stop them);
## instead, each overlapping neighbour pushes an enemy away, harder the deeper they overlap.
## Bigger enemies weigh more, so a boss shoves small ones aside and barely moves itself.
## Pure: the host's enemy passes its neighbours and adds the result to its velocity.
## Real values live in enemies/behaviours/data/crowd.tres.

## Push speed per pixel of overlap (px/s per px), between two enemies of the same size. Keep it
## under 30: at 60 ticks a pair then closes less than its whole overlap in one tick (no jitter).
@export_range(0.0, 50.0) var strength: float = 25.0
## The push never goes faster than this (px/s), however crowded it gets. Above the fastest
## enemy (a Swarmer in a Fast wave: 486), or small enemies walk through big ones.
@export_range(0.0, 2000.0) var max_speed: float = 600.0


## Pure: the push (px/s) on an enemy at `own` with body_scale `own_scale` from its
## `neighbours` (positions) and their `neighbour_scales`. `tiebreak` picks the way out when a
## neighbour stands exactly on it (give each enemy a different one, e.g. its instance id).
func push(
	own: Vector2,
	own_scale: float,
	neighbours: Array[Vector2],
	neighbour_scales: Array[float],
	tiebreak: int
) -> Vector2:
	var total := Vector2.ZERO
	for index in neighbours.size():
		var other_scale: float = neighbour_scales[index]
		var overlap: float = (
			reach(own_scale) + reach(other_scale) - own.distance_to(neighbours[index])
		)
		if overlap <= 0.0:
			continue
		var away: Vector2 = neighbours[index].direction_to(own)
		if away.is_zero_approx():
			away = Vector2.RIGHT.rotated(float(tiebreak % 360) * TAU / 360.0)
		total += away * overlap * strength * 2.0 * share(own_scale, other_scale)
	return total.limit_length(max_speed)


## Pure: the radius an enemy keeps clear around its centre (its body's half size).
static func reach(body_scale: float) -> float:
	return ChaserEnemy.BODY_HALF_SIZE * body_scale


## Pure: how much of the pushing apart this enemy does (0..1): the other's weight over both,
## weight growing with area. Two enemies of one size share it 0.5 / 0.5.
static func share(own_scale: float, other_scale: float) -> float:
	var own_weight: float = own_scale * own_scale
	var other_weight: float = other_scale * other_scale
	return other_weight / maxf(own_weight + other_weight, 0.0001)
