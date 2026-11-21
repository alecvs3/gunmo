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
## Reused by every sweep (see PositionHistory.sample_into).
var _place := PositionHistory.Place.new(Vector2.ZERO, false)


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


## Every hitbox in the world right now (players and enemies). Bots pick targets from these.
func hitboxes() -> Array[HitboxComponent]:
	var found: Array[HitboxComponent] = []
	found.assign(_histories.keys())
	return found


func max_rewind_ticks() -> int:
	return ceili(config.max_rewind * NetClock.tick_rate())


## The tick a shot fired while seeing `view_tick` is tested at: never in the future, never
## further back than max_rewind.
func clamped_tick(view_tick: float) -> float:
	return clampf(view_tick, _clock.tick - max_rewind_ticks(), _clock.tick)


## The first hitbox a bullet of `bullet_radius` moving from->to touches, with every target
## placed where it was at `at_tick` (PRESENT = where it is now). Ignores `ignore_team` and
## the hitboxes in `exclude` (ones a piercing bullet already went through).
func sweep(
	from: Vector2,
	to: Vector2,
	bullet_radius: float,
	at_tick: float,
	ignore_team: StringName,
	exclude: Array[HitboxComponent] = [],
	ignore_owner_id: int = 0
) -> Hit:
	var best: Hit = null
	for hitbox: HitboxComponent in _histories:
		if hitbox.team == ignore_team or hitbox in exclude:
			continue
		if ignore_owner_id != 0 and hitbox.owner_id == ignore_owner_id:
			continue
		var place: PositionHistory.Place = _place_at(hitbox, at_tick)
		if not place.hittable:
			continue
		var fraction: float = hitbox.sweep_fraction(from, to, place.position, bullet_radius)
		if fraction >= 0.0 and (best == null or fraction < best.fraction):
			best = Hit.new(hitbox, from.lerp(to, fraction), fraction)
	return best


## Where `hitbox` was at `at_tick`, in the reused _place (valid until the next call).
func _place_at(hitbox: HitboxComponent, at_tick: float) -> PositionHistory.Place:
	var history: PositionHistory = _histories[hitbox]
	if at_tick == PRESENT or not history.sample_into(at_tick, _place):
		_place.position = hitbox.center()
		_place.hittable = hitbox.is_hittable()
	return _place
