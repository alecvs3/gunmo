class_name TimelineHits
extends RefCounted
## Host, fair dodging: a bullet fired by a bot is tested against each remote human player on
## that player's own timeline (Player.timeline: where their own inputs put them, stamped with
## their view of the host's clock), not where the host happens to have them right now (that
## is their latency plus input buffer behind what they see on their own screen). A tick can
## only be checked once that player's input for it has arrived, so the verdict comes a little
## later, but a dodge the player made on their own screen counts.
## Human shooters keep the usual shooter-favoured lag compensation; this is only for bots.
## When two targets could both be hit, the first one found wins (rare, and it ends the bullet).


class Target:
	var hitbox: HitboxComponent
	## Where the target's own inputs put it, by tick.
	var timeline: PositionHistory
	## Returns the newest tick on that timeline (its inputs so far).
	var newest_tick: Callable
	var checked_tick: int = 0


var _targets: Array[Target] = []


## The targets for a bot's `shot`: every remote human player on another team. Empty (and
## unused) for anyone else's shots.
static func for_shot(shot: Shot, tree: SceneTree) -> TimelineHits:
	var hits := TimelineHits.new()
	if shot.shooter_id >= 0:
		return hits
	for node in tree.get_nodes_in_group(Groups.PLAYERS):
		var player := node as Player
		if player == null or player.timeline == null or player.peer_id == shot.shooter_id:
			continue
		if player.get_hitbox().team == shot.team:
			continue
		hits.add_target(player.get_hitbox(), player.timeline, player.timeline_tick, shot)
	return hits


func add_target(
	hitbox: HitboxComponent, timeline: PositionHistory, newest_tick: Callable, shot: Shot
) -> void:
	var target := Target.new()
	target.hitbox = hitbox
	target.timeline = timeline
	target.newest_tick = newest_tick
	target.checked_tick = floori(shot.fire_tick)
	_targets.append(target)


func is_empty() -> bool:
	return _targets.is_empty()


## The hitboxes checked here, which the normal (host-time) test must skip.
func hitboxes() -> Array[HitboxComponent]:
	var found: Array[HitboxComponent] = []
	for target in _targets:
		if is_instance_valid(target.hitbox):
			found.append(target.hitbox)
	return found


## Checks every target for the ticks its inputs now cover, never past `end_tick` (the last
## tick the bullet flies; at that tick it reaches `end_point`). Returns the hit as
## {"hitbox": HitboxComponent, "point": Vector2, "tick": int}, or {}.
func check(shot: Shot, end_tick: int, end_point: Vector2) -> Dictionary:
	for target in _targets:
		if not _alive(target):
			continue
		var upto: int = mini(int(target.newest_tick.call()), end_tick)
		for tick in range(target.checked_tick + 1, upto + 1):
			var hit: Dictionary = _test(shot, target, tick, end_tick, end_point)
			if not hit.is_empty():
				return hit
		target.checked_tick = maxi(target.checked_tick, upto)
	return {}


## True once every target has been checked up to `end_tick`.
func settled(end_tick: int) -> bool:
	for target in _targets:
		if _alive(target) and target.checked_tick < end_tick:
			return false
	return true


## False once the target's player (and with it its hitbox) has left.
static func _alive(target: Target) -> bool:
	return is_instance_valid(target.hitbox) and target.newest_tick.is_valid()


func _test(shot: Shot, target: Target, tick: int, end_tick: int, end_point: Vector2) -> Dictionary:
	var age: float = tick - shot.fire_tick
	var from: Vector2 = shot.point_at(age - 1.0)
	var to: Vector2 = end_point if tick == end_tick else shot.point_at(age)
	var place: Dictionary = target.timeline.sample(tick)
	if place.is_empty() or not place["hittable"]:
		return {}
	var fraction: float = target.hitbox.sweep_fraction(from, to, place["position"], shot.radius)
	if fraction < 0.0:
		return {}
	return {"hitbox": target.hitbox, "point": from.lerp(to, fraction), "tick": tick}
