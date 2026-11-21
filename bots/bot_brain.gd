class_name BotBrain
extends RefCounted
## The decisions a bot makes each tick, as pure functions so they are unit-tested:
## which target to pick, how far to turn its aim, whether it may fire, and where to move.
## BotController gathers the facts (positions, line of sight) and turns the answers into
## an InputCommand, exactly like a human player's.

## A target being fought stays chosen this much farther than a new one would be noticed.
const KEEP_TARGET_RANGE: float = 1.25


## The id of the target to fight, or 0 for none. `candidates` are
## {"id": int, "position": Vector2, "visible": bool}; only visible ones count. The current
## target is kept while it stays visible and within reach; otherwise the nearest wins.
static func choose_target(
	from: Vector2, candidates: Array[Dictionary], awareness_range: float, current_id: int
) -> int:
	var best_id: int = 0
	var best_distance: float = INF
	for candidate in candidates:
		if not candidate["visible"]:
			continue
		var distance: float = from.distance_to(candidate["position"])
		var reach: float = awareness_range
		if candidate["id"] == current_id:
			reach *= KEEP_TARGET_RANGE
			if distance <= reach:
				return current_id
		if distance <= reach and distance < best_distance:
			best_id = candidate["id"]
			best_distance = distance
	return best_id


## The aim after one tick of turning from `current` toward `desired` (radians), at most
## `max_step` radians.
static func turn_towards(current: float, desired: float, max_step: float) -> float:
	var difference: float = angle_difference(current, desired)
	if absf(difference) <= max_step:
		return wrapf(desired, -PI, PI)
	return wrapf(current + signf(difference) * max_step, -PI, PI)


## True when `aim` is within `cone` radians of `desired`.
static func aim_ready(aim: float, desired: float, cone: float) -> bool:
	return absf(angle_difference(aim, desired)) <= cone


## Which way to walk while fighting: closer when too far, away when too close, and sideways
## (`strafe_sign` picks the side) by the `strafe` share. Length at most 1.
static func move_direction(
	from: Vector2, target: Vector2, preferred_distance: float, strafe: float, strafe_sign: float
) -> Vector2:
	var offset: Vector2 = target - from
	if offset.is_zero_approx():
		return Vector2.ZERO
	var toward: Vector2 = offset.normalized()
	var range_error: float = clampf((offset.length() - preferred_distance) / 100.0, -1.0, 1.0)
	var sideways: Vector2 = toward.orthogonal() * signf(strafe_sign)
	var direction: Vector2 = toward * range_error * (1.0 - strafe) + sideways * strafe
	return direction.limit_length(1.0)


## Walking along a path: toward the first point not yet reached (within `reached`), or
## Vector2.ZERO at the end. Returns [direction, index of the point being walked to].
static func follow_path(
	from: Vector2, path: PackedVector2Array, index: int, reached: float
) -> Array:
	while index < path.size() and from.distance_to(path[index]) <= reached:
		index += 1
	if index >= path.size():
		return [Vector2.ZERO, index]
	return [(path[index] - from).normalized(), index]
