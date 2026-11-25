class_name DifficultyCurve
extends Resource
## The difficulty each wave aims for (DifficultyModel's 0–10 scale). A trend from `first` in
## wave 1 to `last` in the last wave; a boss wave sits `boss_bonus` above it (the last wave
## `last_wave_bonus`), and the waves just after a boss dip by `after_boss` (first, second...),
## so a boss wave is a little harder than the waves that follow. `overrides` pins a wave.

@export_range(0.0, 20.0) var first: float = 1.0
@export_range(0.0, 20.0) var last: float = 10.0
## 1 = straight line; above 1 = the climb is steeper late.
@export_range(0.2, 5.0) var power: float = 1.0
@export_range(0.0, 5.0) var boss_bonus: float = 0.0
@export_range(0.0, 5.0) var last_wave_bonus: float = 0.0
## How much the 1st, 2nd... wave after a boss wave dips below the trend.
@export var after_boss: PackedFloat32Array = []
## A wave counts as on target within this much either way.
@export_range(0.0, 5.0) var tolerance: float = 0.3
## Pinned targets: overrides[w - 1] for wave w (0 = use the curve).
@export var overrides: PackedFloat32Array = []


## The trend alone, without the boss rhythm.
func trend(wave: int, total_waves: int) -> float:
	var share: float = 0.0
	if total_waves > 1:
		share = clampf(float(wave - 1) / (total_waves - 1), 0.0, 1.0)
	return first + (last - first) * pow(share, power)


## The difficulty wave `wave` of `schedule` aims for.
func target(wave: int, schedule: WaveSchedule) -> float:
	if wave - 1 < overrides.size() and overrides[wave - 1] > 0.0:
		return overrides[wave - 1]
	var value: float = trend(wave, schedule.total_waves)
	if wave == schedule.total_waves:
		return value + last_wave_bonus
	if schedule.boss_for(wave) != null:
		return value + boss_bonus
	for i in after_boss.size():
		if schedule.boss_for(wave - 1 - i) != null:
			return value - after_boss[i]
	return value
