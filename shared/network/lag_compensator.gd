class_name LagCompensator
extends Node
## Lets a shot hit what the shooter actually saw.
## Clients draw others slightly in the past (interpolation) and their shots reach the host
## later still, so testing shots against where targets are *now* would miss things the shooter
## clearly hit. The host records every hitbox's position each tick, and sweep() can test
## against the world at any recent tick, at most max_rewind back.
## Clients use sweep() at the present to stop their own predicted bullets on what they see.


class Hit:
	var hitbox: HitboxComponent
	var point: Vector2
	var fraction: float

	func _init(target: HitboxComponent, at: Vector2, along: float) -> void:
		hitbox = target
		point = at
		fraction = along


const PRESENT: float = -1.0

var config: NetworkConfig

var _clock: NetClock
var _histories: Dictionary = {}


func setup(clock: NetClock) -> void:
	_clock = clock


## Runs after movement and before bullets, so this tick's positions are on record.
func _ready() -> void:
	process_physics_priority = 5


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for hitbox: HitboxComponent in _histories:
		(_histories[hitbox] as PositionHistory).record(
			_clock.tick, hitbox.center(), hitbox.is_hittable()
		)


func register(hitbox: HitboxComponent) -> void:
	var history := PositionHistory.new()
	history.capacity = max_rewind_ticks() + 4
	_histories[hitbox] = history


func unregister(hitbox: HitboxComponent) -> void:
	_histories.erase(hitbox)


func max_rewind_ticks() -> int:
	return ceili(config.max_rewind * NetClock.tick_rate())


## The tick a shot fired while seeing `view_tick` is tested at: never in the future, never
## further back than max_rewind.
func clamped_tick(view_tick: float) -> float:
	return clampf(view_tick, _clock.tick - max_rewind_ticks(), _clock.tick)


## The first hitbox a bullet of `bullet_radius` moving from->to touches, with every target
## placed where it was at `at_tick` (PRESENT = where it is now). Ignores `ignore_team`.
func sweep(
	from: Vector2, to: Vector2, bullet_radius: float, at_tick: float, ignore_team: StringName
) -> Hit:
	var best: Hit = null
	for hitbox: HitboxComponent in _histories:
		if hitbox.team == ignore_team:
			continue
		var place: Dictionary = _place(hitbox, at_tick)
		if not place["hittable"]:
			continue
		var fraction: float = hitbox.sweep_fraction(from, to, place["position"], bullet_radius)
		if fraction >= 0.0 and (best == null or fraction < best.fraction):
			best = Hit.new(hitbox, from.lerp(to, fraction), fraction)
	return best


func _place(hitbox: HitboxComponent, at_tick: float) -> Dictionary:
	var history: PositionHistory = _histories[hitbox]
	if at_tick == PRESENT or history.is_empty():
		return {"position": hitbox.center(), "hittable": hitbox.is_hittable()}
	return history.sample(at_tick)
