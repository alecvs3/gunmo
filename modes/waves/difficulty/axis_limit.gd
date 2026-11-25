class_name AxisLimit
extends WaveRule
## Keeps one difficulty axis (index into DifficultyModel.axes) within a share of the wave's
## difficulty (its part of the squared length, DifficultyModel.shares). Below `min_share`, types
## that add to it are `push` times likelier (a themed wave); a pick that takes it past
## `max_share` is refused.

@export_range(0, 15) var axis: int = 0
@export_range(0.0, 1.0) var min_share: float = 0.0
@export_range(0.0, 1.0) var max_share: float = 1.0
@export_range(1.0, 100.0) var push: float = 4.0


func allows(draft: WaveDraft, type: EnemyData) -> bool:
	return max_share >= 1.0 or _share(draft.shares_with(type)) <= max_share


func pull(draft: WaveDraft, type: EnemyData) -> float:
	if min_share <= 0.0 or axis >= draft.model.axes.size():
		return 1.0
	var now: PackedFloat32Array = draft.model.shares(draft.model.scores(draft.sheet, draft.modifier))
	if _share(now) >= min_share:
		return 1.0
	return push if _share(draft.shares_with(type)) > _share(now) else 1.0


func _share(shares: PackedFloat32Array) -> float:
	return shares[axis] if axis < shares.size() else 0.0
