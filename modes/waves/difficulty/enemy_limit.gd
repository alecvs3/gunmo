class_name EnemyLimit
extends WaveRule
## At least `min_count` and at most `max_count` of `enemy` in each wave of the range.

@export var enemy: EnemyData
@export_range(0, 255) var min_count: int = 0
## -1 = no maximum.
@export_range(-1, 255) var max_count: int = -1


func allows(draft: WaveDraft, type: EnemyData) -> bool:
	return type != enemy or max_count < 0 or draft.count_of(type) < max_count


func required(_draft: WaveDraft, types: Array[EnemyData]) -> Array[EnemyData]:
	var found: Array[EnemyData] = []
	if types.has(enemy):
		for i in min_count:
			found.append(enemy)
	return found
