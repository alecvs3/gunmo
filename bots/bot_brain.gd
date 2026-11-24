class_name BotBrain
extends RefCounted
## The decisions a bot makes each tick, as pure functions so they are unit-tested:
## which target to pick, where to aim (leading a moving target), how far to turn its aim,
## whether it may fire, and where to move.
## BotController gathers the facts (positions, line of sight) and turns the answers into
## an InputCommand, exactly like a human player's.

## A target being fought stays chosen this much farther than a new one would be noticed.
const KEEP_TARGET_RANGE: float = 1.25

## Closer than this counts as this close when weighing danger (no division blow-ups).
const MIN_WEIGH_DISTANCE: float = 60.0


## Something a bot could fight.
class Candidate:
	var id: int
	var position: Vector2
	## In the bot's line of sight.
	var visible: bool
	## How much it matters to kill it (an enemy's cost; 1 for a player).
	var danger: float

	func _init(candidate_id: int, at: Vector2, can_see: bool, how_dangerous: float = 1.0) -> void:
		id = candidate_id
		position = at
		visible = can_see
		danger = how_dangerous


## The id of the target to fight, or 0 for none. Only visible candidates count. The current
## target is kept while it stays visible and within reach; otherwise the most dangerous for
## its distance wins (danger / distance; with equal danger, the nearest).
static func choose_target(
	from: Vector2, candidates: Array[Candidate], awareness_range: float, current_id: int
) -> int:
	var best_id: int = 0
	var best_score: float = -1.0
	var best_distance: float = INF
	for candidate in candidates:
		if not candidate.visible:
			continue
		var distance: float = from.distance_to(candidate.position)
		var reach: float = awareness_range
		if candidate.id == current_id:
			reach *= KEEP_TARGET_RANGE
			if distance <= reach:
				return current_id
		var score: float = candidate.danger / maxf(distance, MIN_WEIGH_DISTANCE)
		var better: bool = score > best_score
		if is_equal_approx(score, best_score):
			better = distance < best_distance
		if distance <= reach and better:
			best_id = candidate.id
			best_score = score
			best_distance = distance
	return best_id


## Co-op: where to walk to stay with the team (their centre), or Vector2.INF when already
## within `spread` of it or there is no team.
static func regroup_goal(from: Vector2, teammates: Array[Vector2], spread: float) -> Vector2:
	if teammates.is_empty():
		return Vector2.INF
	var centre := Vector2.ZERO
	for teammate in teammates:
		centre += teammate
	centre /= teammates.size()
	return Vector2.INF if from.distance_to(centre) <= spread else centre


## Co-op: the index of the downed teammate to go and revive (the nearest within
## `max_distance`), or -1.
static func revive_target(from: Vector2, downed: Array[Vector2], max_distance: float) -> int:
	var best: int = -1
	var best_distance: float = max_distance
	for i in downed.size():
		var distance: float = from.distance_to(downed[i])
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


## Co-op: close enough to hold revive (and stop walking).
static func can_revive(from: Vector2, downed_at: Vector2, reach: float) -> bool:
	return from.distance_to(downed_at) <= reach


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
