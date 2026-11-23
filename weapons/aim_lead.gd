class_name AimLead
extends RefCounted
## Leading a moving target: where to aim so a bullet meets it. Pure; used by bots
## (BotController) and ranged enemies (RangedAttack).


## Where to aim so a bullet of `speed` from `from` meets a target at `target` moving at
## `velocity`: the earliest meeting within `max_time` seconds, else the target itself (too
## fast to catch, or out of reach).
static func intercept(
	from: Vector2, target: Vector2, velocity: Vector2, speed: float, max_time: float
) -> Vector2:
	var offset: Vector2 = target - from
	var a: float = velocity.length_squared() - speed * speed
	var b: float = 2.0 * offset.dot(velocity)
	var c: float = offset.length_squared()
	var time: float = -1.0
	if absf(a) < 0.0001:
		time = -c / b if absf(b) > 0.0001 else -1.0
	else:
		var discriminant: float = b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root: float = sqrt(discriminant)
			var first: float = (-b - root) / (2.0 * a)
			var second: float = (-b + root) / (2.0 * a)
			time = minf(first, second) if minf(first, second) > 0.0 else maxf(first, second)
	if time <= 0.0 or time > max_time:
		return target
	return target + velocity * time
