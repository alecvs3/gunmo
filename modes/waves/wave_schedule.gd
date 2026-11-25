class_name WaveSchedule
extends Resource
## How the waves grow. Real values live in modes/waves/data/*.tres.
## Each wave is built to hit the difficulty its curve aims for (`difficulty`, WaveComposer),
## from the enemy types reached by then (EnemyData.first_wave), within the `rules`. Enemies
## arrive one at a time, faster in later waves, never more than max_alive at once.

@export_range(1, 255) var total_waves: int = 1
## Every enemy type the waves may use.
@export var enemy_types: Array[EnemyData] = []
## Boss waves: bosses[i] comes first in wave boss_waves[i] and counts toward its difficulty.
@export var boss_waves: PackedInt32Array = []
@export var bosses: Array[EnemyData] = []
## Share of the wave (by each enemy's own difficulty, DifficultyModel.solo) the composer pulls
## each EnemyData.Role (frontline, ranged, swarm, support) toward, in wave 1 and in the last
## wave, blended in between. A role with no type available yet passes its share on to the
## others. Empty = everything frontline.
@export var shares_first: PackedFloat32Array = []
@export var shares_last: PackedFloat32Array = []
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
## The difficulty each wave aims for (DifficultyCurve, on DifficultyModel's 0–10 scale).
@export var difficulty: DifficultyCurve
## Minimums and maximums per enemy type or difficulty axis (EnemyLimit, AxisLimit).
@export var rules: Array[WaveRule] = []
## Most enemies one wave may have, the boss included (a safety stop; split children not counted).
@export_range(1, 10000) var max_enemies: int = 400


func spawn_interval(wave: int) -> float:
	return lerpf(first_spawn_interval, last_spawn_interval, progress(wave))


## This wave's boss, or null.
func boss_for(wave: int) -> EnemyData:
	var at: int = boss_waves.find(wave)
	return bosses[at] if at >= 0 and at < bosses.size() else null


## 0 in wave 1, 1 in the last wave.
func progress(wave: int) -> float:
	if total_waves <= 1:
		return 0.0
	return clampf(float(wave - 1) / (total_waves - 1), 0.0, 1.0)


## This wave's share for `role` before roles without types are taken out.
func share(role: int, wave: int) -> float:
	if shares_first.size() <= role and shares_last.size() <= role:
		return 1.0 if role == EnemyData.Role.FRONTLINE else 0.0
	var first: float = shares_first[role] if role < shares_first.size() else 0.0
	var last: float = shares_last[role] if role < shares_last.size() else first
	return lerpf(first, last, progress(wave))
