class_name EnemyFacing
extends RefCounted
## Host: which way an enemy faces. It looks where it walks (not where a push slides it). A hit
## twists it briefly towards the way it was pushed (a flinch), and it turns back over
## flinch_recovery seconds. A push from straight in front or behind has no clear side, so it
## picks one at random instead of always the same.

## A push closer to straight on than this (sine of its angle to the facing) has no clear side.
const STRAIGHT_ON: float = 0.2

var flinch_degrees: float = 25.0
var flinch_recovery: float = 0.25
## Picks the side for straight-on pushes (randomly seeded; tests may seed it).
var rng := RandomNumberGenerator.new()

var _walk: float = 0.0
var _flinch: float = 0.0


func configure(degrees: float, recovery: float) -> void:
	flinch_degrees = degrees
	flinch_recovery = recovery


## Faces `direction`, the way it is walking this tick. A zero direction keeps the last one.
func walk_towards(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_walk = direction.angle()


## A hit pushed it by `impulse`: twist towards that side.
func flinch_from(impulse: Vector2) -> void:
	if flinch_degrees <= 0.0 or impulse == Vector2.ZERO:
		return
	var side: float = Vector2.from_angle(_walk).cross(impulse.normalized())
	if absf(side) < STRAIGHT_ON:
		side = 1.0 if rng.randi() % 2 == 0 else -1.0
	_flinch = signf(side) * deg_to_rad(flinch_degrees)


## Lets a flinch wear off.
func step(delta: float) -> void:
	var recover_speed: float = deg_to_rad(flinch_degrees) / flinch_recovery
	_flinch = move_toward(_flinch, 0.0, recover_speed * delta)


## Where it faces now (radians).
func angle() -> float:
	return _walk + _flinch
