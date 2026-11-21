class_name Bullet
extends Node2D
## One projectile, in one of three modes:
##   AUTHORITATIVE  host: moves every tick and decides hits, testing targets where the shooter
##                  saw them (LagCompensator); applies damage and knockback
##   PREDICTED      the shooter's own copy, shown the moment they fire; stops on what the
##                  shooter sees but deals nothing (the host's verdict follows)
##   REMOTE         everyone else's copy, placed on the same past timeline as the other
##                  players they see, and ended where and when the host says

signal finished(bullet: Bullet, end_point: Vector2, hit_something: bool)

enum Mode { AUTHORITATIVE, PREDICTED, REMOTE }

const WORLD_MASK: int = 1

var shot: Shot
var mode: Mode = Mode.AUTHORITATIVE

var _age_ticks: float = 0.0
var _done: bool = false
## REMOTE: where and when the host ended this bullet (end tick < 0 = not known yet).
var _end_tick: float = -1.0
var _end_point: Vector2 = Vector2.ZERO
var _end_hit: bool = false


func setup(fired_shot: Shot, bullet_mode: Mode) -> void:
	shot = fired_shot
	mode = bullet_mode
	position = shot.origin
	rotation = shot.direction.angle()


func _ready() -> void:
	process_physics_priority = 10
	if mode == Mode.REMOTE:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		set_physics_process(false)
		hide()
	else:
		set_process(false)


## AUTHORITATIVE and PREDICTED: one tick of flight along the swept path.
func _physics_process(_delta: float) -> void:
	if _done:
		return
	var from: Vector2 = position
	_age_ticks += 1.0
	var to: Vector2 = shot.point_at(_age_ticks)
	var wall: float = _wall_fraction(from, to)
	var target: LagCompensator.Hit = _find_target(from, to)
	if target != null and (wall < 0.0 or target.fraction <= wall):
		_hit(target)
	elif wall >= 0.0:
		_finish(from.lerp(to, wall), false)
	elif _age_ticks >= shot.lifetime_ticks():
		_finish(to, false)
	else:
		position = to


## REMOTE: placed by the render timeline every frame.
func _process(_delta: float) -> void:
	var render_tick: float = NetworkManager.clock.render_tick()
	if _end_tick >= 0.0 and render_tick >= _end_tick:
		_finish(_end_point, _end_hit)
		return
	var age: float = render_tick - shot.fire_tick
	if age < 0.0:
		return
	if age >= shot.lifetime_ticks():
		_finish(shot.point_at(shot.lifetime_ticks()), false)
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
		_finish(point, hit_something)


func _find_target(from: Vector2, to: Vector2) -> LagCompensator.Hit:
	var lag: LagCompensator = NetworkManager.lag_compensator
	var at_tick: float = LagCompensator.PRESENT
	if mode == Mode.AUTHORITATIVE:
		at_tick = lag.clamped_tick(shot.view_tick + _age_ticks)
	return lag.sweep(from, to, shot.radius, at_tick, shot.team)


func _hit(target: LagCompensator.Hit) -> void:
	if mode == Mode.AUTHORITATIVE:
		target.hitbox.hit(shot.damage, shot.shooter_id, shot.direction * shot.knockback)
	_finish(target.point, true)


func _wall_fraction(from: Vector2, to: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	query.collide_with_areas = false
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty() or from.is_equal_approx(to):
		return -1.0
	return from.distance_to(result["position"]) / from.distance_to(to)


func _finish(end_point: Vector2, hit_something: bool) -> void:
	_done = true
	position = end_point
	finished.emit(self, end_point, hit_something)
	queue_free()
