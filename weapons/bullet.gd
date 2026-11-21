class_name Bullet
extends Node2D
## One projectile, in one of three modes:
##   AUTHORITATIVE  host: moves every tick and decides hits, testing targets where the shooter
##                  saw them (LagCompensator); applies damage and knockback. A bot's bullet
##                  tests remote human players on their own timeline instead (TimelineHits,
##                  fair dodging) and may wait a moment after it stops for their inputs.
##   PREDICTED      the shooter's own copy, shown the moment they fire; stops on what the
##                  shooter sees but deals nothing (the host's verdict follows)
##   REMOTE         everyone else's copy, placed on the same past timeline as the other
##                  players they see, and ended where and when the host says. One that passes
##                  near our own player catches up to the present on its way, so a bullet
##                  that hits us visibly reaches us when the damage lands.

## `end_tick` is the host tick the bullet ended on (on the target's timeline for a fair
## dodging hit).
signal finished(bullet: Bullet, end_point: Vector2, hit_something: bool, end_tick: float)
## AUTHORITATIVE: the bullet hit `hitbox` (it may fly on if it pierces).
signal hit_landed(bullet: Bullet, at: Vector2, hitbox: HitboxComponent)

enum Mode { AUTHORITATIVE, PREDICTED, REMOTE }

const WORLD_MASK: int = 1
## REMOTE: a bullet whose path comes this close to our own player catches up (pixels).
const THREAT_DISTANCE: float = 150.0
## REMOTE: seconds a threatening bullet takes to catch up from the past to the present.
const CATCH_UP_SECONDS: float = 0.2

var shot: Shot
var mode: Mode = Mode.AUTHORITATIVE

var _age_ticks: float = 0.0
var _done: bool = false
var _pierce_left: int = 0
var _already_hit: Array[HitboxComponent] = []
## REMOTE: where and when the host ended this bullet (end tick < 0 = not known yet).
var _end_tick: float = -1.0
var _end_point: Vector2 = Vector2.ZERO
var _end_hit: bool = false
## REMOTE: shown on the present timeline once it has caught up.
var _catches_up: bool = false
## AUTHORITATIVE bot shot: remote human players tested on their own timeline.
var _timeline: TimelineHits = null
## AUTHORITATIVE: flight is over; waiting for the timeline checks (tick < 0 = still flying).
var _stop_tick: int = -1
var _stop_point: Vector2 = Vector2.ZERO
var _stop_hit: bool = false


func setup(fired_shot: Shot, bullet_mode: Mode) -> void:
	shot = fired_shot
	mode = bullet_mode
	_pierce_left = shot.pierce
	position = shot.origin
	rotation = shot.direction.angle()


## Whether a bullet along `fired_shot`'s whole path passes within `distance` of `point`.
static func passes_near(fired_shot: Shot, point: Vector2, distance: float) -> bool:
	var path_end: Vector2 = fired_shot.point_at(fired_shot.lifetime_ticks())
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
		point, fired_shot.origin, path_end
	)
	return closest.distance_to(point) <= distance


## REMOTE: the tick to draw a bullet at. One that catches up moves from the render tick at
## the muzzle to the present over `catch_up_ticks` of its flight.
static func display_tick(
	render_tick: float, present_tick: float, fire_tick: float, catch_up_ticks: float
) -> float:
	var age: float = render_tick - fire_tick
	var progress: float = clampf(age / maxf(catch_up_ticks, 1.0), 0.0, 1.0)
	return render_tick + (present_tick - render_tick) * progress


func _ready() -> void:
	process_physics_priority = 10
	if mode == Mode.REMOTE:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		set_physics_process(false)
		hide()
		var own: Player = Player.find_local(get_tree())
		_catches_up = own != null and passes_near(shot, own.global_position, THREAT_DISTANCE)
		return
	set_process(false)
	if mode == Mode.AUTHORITATIVE:
		var hits: TimelineHits = TimelineHits.for_shot(shot, get_tree())
		_timeline = null if hits.is_empty() else hits


## AUTHORITATIVE and PREDICTED: one tick of flight along the swept path.
func _physics_process(_delta: float) -> void:
	if _done:
		return
	if _stop_tick >= 0:
		_settle()
		return
	var from: Vector2 = position
	_age_ticks += 1.0
	var to: Vector2 = shot.point_at(_age_ticks)
	var wall: float = _wall_fraction(from, to)
	var target: LagCompensator.Hit = _find_target(from, to)
	if target != null and (wall < 0.0 or target.fraction <= wall):
		_hit(target)
	elif wall >= 0.0:
		_stop(from.lerp(to, wall), false)
	elif _age_ticks >= shot.lifetime_ticks():
		_stop(to, false)
	else:
		position = to
		_check_timeline(_tick_now(), to)


## REMOTE: placed by the render timeline every frame.
func _process(_delta: float) -> void:
	var clock: NetClock = NetworkManager.clock
	var tick: float = clock.render_tick()
	if _catches_up:
		tick = display_tick(
			tick, clock.server_tick_now(), shot.fire_tick, CATCH_UP_SECONDS * NetClock.tick_rate()
		)
	if _end_tick >= 0.0 and tick >= _end_tick:
		_finish(_end_point, _end_hit, _end_tick)
		return
	var age: float = tick - shot.fire_tick
	if age < 0.0:
		return
	if age >= shot.lifetime_ticks():
		_finish(shot.point_at(shot.lifetime_ticks()), false, tick)
		return
	position = shot.point_at(age)
	show()


## The host says this bullet ended at `point` on `end_tick`.
func end_at(point: Vector2, end_tick: float, hit_something: bool) -> void:
	if _done:
		return
	if mode == Mode.REMOTE:
		_end_tick = end_tick
		_end_point = point
		_end_hit = hit_something
	else:
		_finish(point, hit_something, end_tick)


func _find_target(from: Vector2, to: Vector2) -> LagCompensator.Hit:
	var lag: LagCompensator = NetworkManager.lag_compensator
	var at_tick: float = LagCompensator.PRESENT
	if mode == Mode.AUTHORITATIVE:
		at_tick = lag.clamped_tick(shot.view_tick + _age_ticks)
	var skip: Array[HitboxComponent] = _already_hit
	if _timeline != null:
		skip = _already_hit + _timeline.hitboxes()
	return lag.sweep(from, to, shot.radius, at_tick, shot.team, skip, shot.shooter_id)


## Damages (host only) and either stops or, with pierce left, flies on past this target.
func _hit(target: LagCompensator.Hit) -> void:
	if mode == Mode.AUTHORITATIVE:
		_damage(target.hitbox, target.point)
	if _pierce_left <= 0:
		_stop(target.point, true)
		return
	_pierce_left -= 1
	_already_hit.append(target.hitbox)
	position = target.point


func _damage(hitbox: HitboxComponent, at: Vector2) -> void:
	hitbox.hit(shot.damage, shot.shooter_id, shot.direction * shot.knockback)
	hit_landed.emit(self, at, hitbox)


## Flight is over at `point`. A bot's bullet first lets the timeline checks catch up (the
## remote players' inputs for these ticks may not have arrived yet).
func _stop(point: Vector2, hit_something: bool) -> void:
	position = point
	if mode != Mode.AUTHORITATIVE or _timeline == null:
		_finish(point, hit_something, _tick_now())
		return
	_stop_tick = _tick_now()
	_stop_point = point
	_stop_hit = hit_something
	hide()
	_settle()


## Waiting after the flight: finish once every remote player is checked up to the stop tick,
## or after max_rewind (inputs that stopped coming can't hold the bullet forever).
func _settle() -> void:
	if _check_timeline(_stop_tick, _stop_point):
		return
	var waited: float = _tick_now() - _stop_tick
	var max_wait: float = NetworkManager.lag_compensator.max_rewind_ticks()
	if _timeline.settled(_stop_tick) or waited >= max_wait:
		_finish(_stop_point, _stop_hit, _stop_tick)


## Runs the fair-dodging checks up to `end_tick`; true if one hit (the bullet is then done).
func _check_timeline(end_tick: int, end_point: Vector2) -> bool:
	if _timeline == null:
		return false
	var hit: Dictionary = _timeline.check(shot, end_tick, end_point)
	if hit.is_empty():
		return false
	_damage(hit["hitbox"], hit["point"])
	_finish(hit["point"], true, hit["tick"])
	return true


func _tick_now() -> int:
	return roundi(shot.fire_tick + _age_ticks)


func _wall_fraction(from: Vector2, to: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	query.collide_with_areas = false
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty() or from.is_equal_approx(to):
		return -1.0
	return from.distance_to(result["position"]) / from.distance_to(to)


func _finish(end_point: Vector2, hit_something: bool, end_tick: float) -> void:
	_done = true
	position = end_point
	finished.emit(self, end_point, hit_something, end_tick)
	queue_free()
