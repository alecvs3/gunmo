class_name ImpactEffects
extends RefCounted
## Host: what a bullet's HitEffects do when it lands. The target gets the timed effects
## (burn, chill, shred); a shock arcs on to nearby foes one after another; a blast damages
## every foe around the impact, and also goes off where a bullet stops without hitting
## anything (wall or end of range). Arcs and blasts pass the timed effects on, so an arc of
## a burning shot sets its targets on fire too, but they never start more arcs or blasts.
## Returns what happened as Flash records, so the ProjectileSystem can show everyone.
## Secondary hits use where foes are now (not lag-compensated): they are area effects.


## One thing to draw: an arc from `from` to `to`, or a blast at `from` with radius `to.x`.
class Flash:
	var kind: int = 0
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO

	func _init(flash_kind: int, from_point: Vector2, to_point: Vector2) -> void:
		kind = flash_kind
		from = from_point
		to = to_point


## The bullet hit `target` at `at`. `candidates` are every hitbox there is.
static func on_hit(
	shot: Shot, target: HitboxComponent, at: Vector2, candidates: Array[HitboxComponent]
) -> Array[Flash]:
	var flashes: Array[Flash] = []
	if shot.effects == null or shot.effects.is_empty():
		return flashes
	target.apply_effects(shot.effects, shot.shooter_id)
	flashes.append_array(_shock(shot, target, candidates))
	flashes.append_array(_blast(shot, at, [target], candidates))
	return flashes


## The bullet stopped at `at` without hitting anything.
static func on_stop(shot: Shot, at: Vector2, candidates: Array[HitboxComponent]) -> Array[Flash]:
	var none: Array[Flash] = []
	if shot.effects == null or shot.effects.is_empty():
		return none
	var skip: Array[HitboxComponent] = []
	return _blast(shot, at, skip, candidates)


## Whether `hitbox` is someone this shot may hurt.
static func is_foe(shot: Shot, hitbox: HitboxComponent) -> bool:
	return hitbox.is_hittable() and hitbox.team != shot.team and hitbox.owner_id != shot.shooter_id


## The foes an arc jumps to from `first`: each time the nearest one not reached yet, within
## `jump_range` of the last.
static func chain_targets(
	shot: Shot, first: HitboxComponent, candidates: Array[HitboxComponent]
) -> Array[HitboxComponent]:
	var chain: Array[HitboxComponent] = []
	var reached: Array[HitboxComponent] = [first]
	var from: Vector2 = first.center()
	for jump in shot.effects.shock_chains:
		var next: HitboxComponent = _nearest(shot, from, candidates, reached)
		if next == null:
			break
		chain.append(next)
		reached.append(next)
		from = next.center()
	return chain


## Every foe within the blast radius of `at`, except `skip`.
static func blast_targets(
	shot: Shot, at: Vector2, skip: Array[HitboxComponent], candidates: Array[HitboxComponent]
) -> Array[HitboxComponent]:
	var inside: Array[HitboxComponent] = []
	var radius: float = shot.effects.blast_radius
	for hitbox in candidates:
		if hitbox in skip or not is_foe(shot, hitbox):
			continue
		if hitbox.center().distance_to(at) <= radius:
			inside.append(hitbox)
	return inside


static func secondary_damage(shot: Shot, share: float) -> int:
	return maxi(roundi(shot.damage * share), 1)


static func _shock(
	shot: Shot, target: HitboxComponent, candidates: Array[HitboxComponent]
) -> Array[Flash]:
	var flashes: Array[Flash] = []
	if shot.effects.mask() & HitEffects.SHOCK == 0:
		return flashes
	var from: Vector2 = target.center()
	for next in chain_targets(shot, target, candidates):
		flashes.append(Flash.new(HitEffects.SHOCK, from, next.center()))
		from = next.center()
		_hit_secondary(shot, next, shot.effects.shock_share)
	return flashes


static func _blast(
	shot: Shot, at: Vector2, skip: Array[HitboxComponent], candidates: Array[HitboxComponent]
) -> Array[Flash]:
	var flashes: Array[Flash] = []
	if shot.effects.mask() & HitEffects.BLAST == 0:
		return flashes
	flashes.append(Flash.new(HitEffects.BLAST, at, Vector2(shot.effects.blast_radius, 0.0)))
	for hitbox in blast_targets(shot, at, skip, candidates):
		_hit_secondary(shot, hitbox, shot.effects.blast_share)
	return flashes


static func _hit_secondary(shot: Shot, hitbox: HitboxComponent, share: float) -> void:
	hitbox.hit(secondary_damage(shot, share), shot.shooter_id)
	hitbox.apply_effects(shot.effects.carried(), shot.shooter_id)


static func _nearest(
	shot: Shot,
	from: Vector2,
	candidates: Array[HitboxComponent],
	reached: Array[HitboxComponent],
) -> HitboxComponent:
	var best: HitboxComponent = null
	var best_distance: float = shot.effects.shock_range
	for hitbox in candidates:
		if hitbox in reached or not is_foe(shot, hitbox):
			continue
		var distance: float = hitbox.center().distance_to(from)
		if distance <= best_distance:
			best = hitbox
			best_distance = distance
	return best
