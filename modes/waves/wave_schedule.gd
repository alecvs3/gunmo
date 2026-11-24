class_name WaveSchedule
extends Resource
## How the waves grow. Real values live in modes/waves/data/*.tres.
## Wave w may spend budget(w) = base_budget + budget_growth × (w − 1)^budget_curve points on
## enemies (each EnemyData has a cost and a first wave). Enemies arrive one at a time, faster
## in later waves, never more than max_alive at once.

@export_range(1, 255) var total_waves: int = 1
## Points to spend in wave 1.
@export_range(0.0, 1000.0) var base_budget: float = 1.0
## How many more points each later wave gets (before the curve).
@export_range(0.0, 100.0) var budget_growth: float = 0.0
## 1 = straight line; above 1 = later waves grow faster.
@export_range(0.5, 3.0) var budget_curve: float = 1.0
## Every enemy type the waves may buy.
@export var enemy_types: Array[EnemyData] = []
## Seconds between spawns in wave 1, and in the last wave (blended in between).
@export_range(0.05, 10.0) var first_spawn_interval: float = 1.0
@export_range(0.05, 10.0) var last_spawn_interval: float = 1.0
## Most enemies alive at once; the rest wait their turn.
@export_range(1, 500) var max_alive: int = 1
## Enemies spawn at least this far (px) from every living player when a point allows it.
@export_range(0.0, 5000.0) var min_spawn_distance: float = 0.0
## First wave with a modifier (armored, fast...), first with two at once, first with three.
## Above total_waves = never.
@export_range(1, 256) var first_modifier_wave: int = 256
@export_range(1, 256) var double_modifier_wave: int = 256
@export_range(1, 256) var triple_modifier_wave: int = 256


func spawn_interval(wave: int) -> float:
	var progress: float = 0.0
	if total_waves > 1:
		progress = clampf(float(wave - 1) / (total_waves - 1), 0.0, 1.0)
	return lerpf(first_spawn_interval, last_spawn_interval, progress)
