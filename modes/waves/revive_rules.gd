class_name ReviveRules
extends RefCounted
## Co-op downed and revive, as pure rules. A player at 0 health goes down: a bleed-out timer
## runs, and a living teammate within `revive_range` holding the revive key fills a revive bar.
## Letting go or walking away interrupts it (the bar empties); while someone is reviving, the
## bleed-out timer waits. A full bar revives; an empty timer means out until the break.
## WaveMode keeps one Downed per downed player and steps it every tick on the host.

enum Result { DOWN, REVIVED, BLED_OUT }


## One downed player's timers (seconds).
class Downed:
	var bleed_left: float = 0.0
	var progress: float = 0.0

	func _init(bleed_seconds: float) -> void:
		bleed_left = bleed_seconds


## One tick of a downed player: `reviving` = someone is holding revive next to them.
static func step(downed: Downed, delta: float, reviving: bool, revive_seconds: float) -> Result:
	if reviving:
		downed.progress += delta
		if downed.progress >= revive_seconds:
			return Result.REVIVED
		return Result.DOWN
	downed.progress = 0.0
	downed.bleed_left -= delta
	return Result.BLED_OUT if downed.bleed_left <= 0.0 else Result.DOWN


## Whether a teammate at `reviver` is close enough to revive a player down at `downed_at`.
static func in_range(reviver: Vector2, downed_at: Vector2, revive_range: float) -> bool:
	return reviver.distance_squared_to(downed_at) <= revive_range * revive_range


## A 0..1 share as one byte for the snapshot (0 = none).
static func to_byte(share: float) -> int:
	if share <= 0.0:
		return 0
	return clampi(ceili(share * 255.0), 1, 255)
