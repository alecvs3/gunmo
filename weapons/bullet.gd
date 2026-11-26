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
##                  that hits us visibly reaches us when the damage lands. A bot's or enemy's
##                  bullet (judged on our own timeline) catches up before it can reach us, or is
##                  drawn at the present at once when it is that close, and tells us when it
##                  touches our player (with the mode's LatencyPolicy switches on).

## `end_tick` is the host tick the bullet ended on (on the target's timeline for a fair
## dodging hit).
signal finished(bullet: Bullet, end_point: Vector2, hit_something: bool, end_tick: float)
## AUTHORITATIVE: the bullet hit `hitbox` (it may fly on if it pierces).
signal hit_landed(bullet: Bullet, at: Vector2, hitbox: HitboxComponent)
## PREDICTED: our own bullet landed on `hitbox` on our screen (the host's verdict follows).
signal hit_predicted(bullet: Bullet, at: Vector2, hitbox: HitboxComponent)
## REMOTE: a bot's or enemy's bullet, drawn at the present, touched our own player on our screen
## (the host's verdict, EVENT_HURT, follows). Once per bullet.
signal reached_us(bullet: Bullet)

enum Mode { AUTHORITATIVE, PREDICTED, REMOTE }

const WORLD_MASK: int = 1
## REMOTE: a bullet whose path comes this close to our own player catches up (pixels).
const THREAT_DISTANCE: float = 150.0
## REMOTE: seconds a threatening bullet takes to catch up from the past to the present.
const CATCH_UP_SECONDS: float = 0.2
## REMOTE: a catch-up shorter than this (ticks, 100 ms) is skipped: the bullet is drawn at the
## present at once (shorter ones were still easing in when they hit, in smoke scenario I).
const SNAP_TICKS: float = 6.0

var shot: Shot
var mode: Mode = Mode.AUTHORITATIVE
## REMOTE: sent ahead of time by a locked wind-up volley (EVENT_SCHEDULED): hidden until its
## fire_tick, then drawn on the present at once (it needs no catch-up). Set before it's added.
var scheduled: bool = false

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
## REMOTE, when it catches up: ticks of its flight that takes (0 = drawn at the present at once).
var _catch_up_ticks: float = 0.0
## REMOTE bot or enemy shot: our own hitbox, while it may still tell us it reached us.
var _own_hitbox: HitboxComponent = null
var _drawn_before: bool = false
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


## REMOTE: ticks of flight until a shot comes closest to `point` (where it would hit).
static func reach_ticks(fired_shot: Shot, point: Vector2) -> float:
	var path_end: Vector2 = fired_shot.point_at(fired_shot.lifetime_ticks())
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
		point, fired_shot.origin, path_end
	)
	var per_tick: float = maxf(fired_shot.speed * NetClock.tick_delta(), 0.001)
	return fired_shot.origin.distance_to(closest) / per_tick


## REMOTE: how many ticks of its (render-timeline) flight a bullet should take to catch up, so it
## is on the present before it reaches us. It only appears once the render tick passes its fire
## tick, `delay_ticks` (present - render) after it really left, so it must be done within
## (reach - delay) ticks; half of that leaves the rest of the flight on the present. At most
## `longest`; under SNAP_TICKS it is 0: draw it at the present right away.
static func catch_up_ticks(reach: float, delay_ticks: float, longest: float) -> float:
	var ticks: float = clampf((reach - delay_ticks) * 0.5, 0.0, longest)
	return 0.0 if ticks < SNAP_TICKS else ticks


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
		var near: bool = own != null and passes_near(shot, own.global_position, THREAT_DISTANCE)
		_catches_up = near or scheduled
		if near:
			_plan_catch_up(own)
		if scheduled:
			_catch_up_ticks = 0.0
		return
	set_process(false)
	if mode == Mode.AUTHORITATIVE:
		add_to_group(Groups.BULLETS)
		var hits: TimelineHits = TimelineHits.for_shot(shot, get_tree())
		_timeline = null if hits.is_empty() else hits


## AUTHORITATIVE and PREDICTED: one tick of flight along the swept path. The first tick sweeps
## from the shot's hit_origin (the shooter's body), so point-blank enemies and walls count.
func _physics_process(_delta: float) -> void:
	if _done:
		return
	if _stop_tick >= 0:
		_settle()
		return
	var from: Vector2 = shot.hit_origin if _age_ticks == 0.0 else position
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


## REMOTE, a bullet that may reach us: how fast it catches up, and whether it may tell us it
## touched us. Human shooters' bullets (lag-compensated: we can't judge them) keep the plain
## catch-up.
func _plan_catch_up(own: Player) -> void:
	var longest: float = CATCH_UP_SECONDS * NetClock.tick_rate()
	_catch_up_ticks = longest
	if shot.shooter_id >= 0:
		return
	var policy: LatencyPolicy = NetworkManager.latency_policy
	if policy.snap_close_threats:
		var clock: NetClock = NetworkManager.clock
		var delay: float = clock.server_tick_now() - clock.render_tick()
		_catch_up_ticks = catch_up_ticks(reach_ticks(shot, own.global_position), delay, longest)
	if policy.predict_own_hurt:
		_own_hitbox = own.get_node("HitboxComponent") as HitboxComponent


## REMOTE: placed by the render timeline every frame.
func _process(_delta: float) -> void:
	var clock: NetClock = NetworkManager.clock
	var tick: float = clock.render_tick()
	var present: float = clock.server_tick_now()
	if _catches_up and _catch_up_ticks <= 0.0:
		tick = present
	elif _catches_up:
		tick = display_tick(tick, present, shot.fire_tick, _catch_up_ticks)
	if _end_tick >= 0.0 and tick >= _end_tick:
		_finish(_end_point, _end_hit, _end_tick)
		return
	var age: float = tick - shot.fire_tick
	if age < 0.0:
		return
	if age >= shot.lifetime_ticks():
		_finish(shot.point_at(shot.lifetime_ticks()), false, tick)
		return
	var before: Vector2 = position if _drawn_before else shot.origin
	position = shot.point_at(age)
	show()
	_drawn_before = true
	if _own_hitbox != null and present - tick < 0.5:
		_check_reached_us(before)


## REMOTE: drawn at the present, did it sweep into our own player since last frame?
func _check_reached_us(from: Vector2) -> void:
	if not is_instance_valid(_own_hitbox) or not _own_hitbox.is_hittable():
		_own_hitbox = null
		return
	var center: Vector2 = _own_hitbox.center()
	if _own_hitbox.sweep_fraction(from, position, center, shot.radius) >= 0.0:
		_own_hitbox = null
		reached_us.emit(self)


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
	var landed: bool = true
	if mode == Mode.AUTHORITATIVE:
		landed = _damage(target.hitbox, target.point)
	elif mode == Mode.PREDICTED:
		hit_predicted.emit(self, target.point, target.hitbox)
	if _pierce_left <= 0 or not landed:
		_stop(target.point, true)
		return
	_pierce_left -= 1
	_already_hit.append(target.hitbox)
	position = target.point


## False = a shield blocked it (the bullet stops there even with pierce left; a rocket still
## explodes on it).
func _damage(hitbox: HitboxComponent, at: Vector2) -> bool:
	var push: Vector2 = shot.direction * shot.knockback
	var landed: bool = hitbox.hit(
		shot.damage, shot.shooter_id, push, shot.damage_type, shot.direction
	)
	hit_landed.emit(self, at, hitbox)
	return landed


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
	var hit: TimelineHits.Hit = _timeline.check(shot, end_tick, end_point)
	if hit == null:
		return false
	_damage(hit.hitbox, hit.point)
	_finish(hit.point, true, hit.tick)
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
