class_name SpawnProtection
extends RefCounted
## Gun Game spawn protection, as pure rules: a short moment after respawning when you can't be
## hurt, which ends early the moment you fire (no shooting from safety).


## The host tick protection ends on, for a respawn on `now` lasting `seconds`.
static func until_after_spawn(now: int, seconds: float) -> int:
	return now + roundi(seconds * NetClock.tick_rate())


## Firing ends it at once.
static func until_after_shot(until: int, now: int) -> int:
	return mini(until, now)


static func is_on(now: int, until: int) -> bool:
	return now < until
