class_name DifficultyCurve
extends Resource
## The difficulty each wave aims for (DifficultyModel's 0–10 scale). A trend from `first` in
## wave 1 to `last` in the last wave; a boss wave sits `boss_bonus` above it (the last wave
## `last_wave_bonus`), and the waves just after a boss dip by `after_boss` (first, second...),
## so a boss wave is a little harder than the waves that follow. `overrides` pins a wave.
## `player_scale` multiplies every target by how many players there are (bots count), so a
## bigger team gets a bigger wave (and more bounty to share).

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
## Target multiplier for n players: player_scale[n - 1] (more players than listed: the last
## entry; empty = 1 for everyone). n equal players have n / 2 times the raw strength of two,
## which scores (n / 2)^0.7 as much (DifficultyModel.exponent): that's the default shape.
@export var player_scale: PackedFloat32Array = []


## The trend alone, without the boss rhythm.
func trend(wave: int, total_waves: int) -> float:
	var share: float = 0.0
	if total_waves > 1:
		share = clampf(float(wave - 1) / (total_waves - 1), 0.0, 1.0)
	return first + (last - first) * pow(share, power)


## The difficulty wave `wave` of `schedule` aims for with `players` players (0 = unscaled).
func target(wave: int, schedule: WaveSchedule, players: int = 0) -> float:
	return _unscaled(wave, schedule) * scale_for(players)


## The multiplier for `players` players (1 when 0 or when the curve has no player_scale).
func scale_for(players: int) -> float:
	if players <= 0 or player_scale.is_empty():
		return 1.0
	return player_scale[mini(players, player_scale.size()) - 1]


func _unscaled(wave: int, schedule: WaveSchedule) -> float:
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
