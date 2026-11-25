class_name WaveRule
extends Resource
## A limit on what the waves from `from_wave` to `to_wave` may contain (WaveSchedule.rules),
## checked by WaveComposer while it builds a wave. Subclasses: EnemyLimit, AxisLimit.

@export_range(1, 255) var from_wave: int = 1
## 0 = to the last wave.
@export_range(0, 255) var to_wave: int = 0


func applies(wave: int) -> bool:
	return wave >= from_wave and (to_wave == 0 or wave <= to_wave)


## Pure: whether one more `type` may join the wave being built.
func allows(_draft: WaveDraft, _type: EnemyData) -> bool:
	return true


## Pure: enemies the wave must start with (from `types`, the ones available this wave).
func required(_draft: WaveDraft, _types: Array[EnemyData]) -> Array[EnemyData]:
	return []


## Pure: a multiplier on how likely `type` is to be picked next (1 = no change).
func pull(_draft: WaveDraft, _type: EnemyData) -> float:
	return 1.0
