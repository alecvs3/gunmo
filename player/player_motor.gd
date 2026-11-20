class_name PlayerMotor
extends RefCounted
## The player's movement rule: current velocity + input -> next velocity.
## Pure and deterministic, so the host and (with client prediction) the owning client run
## exactly the same math and agree on where the player is.

## Guards against a zero time in the data (treated as instant).
const MIN_TIME: float = 0.0001


## Speeds up toward full speed over acceleration_time and slows to a stop over
## deceleration_time. Pushing against the current motion (turning around) uses the faster
## of the two, so direction changes stay snappy.
static func step(velocity: Vector2, input: Vector2, delta: float, data: PlayerData) -> Vector2:
	var direction: Vector2 = input.limit_length(1.0)
	var target: Vector2 = direction * data.move_speed
	var accel_rate: float = data.move_speed / maxf(data.acceleration_time, MIN_TIME)
	var decel_rate: float = data.move_speed / maxf(data.deceleration_time, MIN_TIME)
	var rate: float = accel_rate
	if direction.is_zero_approx():
		rate = decel_rate
	elif velocity.dot(target) < 0.0:
		rate = maxf(accel_rate, decel_rate)
	return velocity.move_toward(target, rate * delta)
