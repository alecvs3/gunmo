class_name WaveDraft
extends RefCounted
## One try at building a wave (WaveComposer): the enemies picked so far, their WaveSheet, and
## what the schedule's rules (WaveRule) allow next. Pure.

var model: DifficultyModel
var modifier: WaveModifier
var wave: int = 0
var sheet := WaveSheet.new()

var _schedule: WaveSchedule
var _types: Array[EnemyData] = []
var _rules: Array[WaveRule] = []
var _shares := PackedFloat32Array()
var _boss: EnemyData
var _picks: Array[Array] = []
var _counts: Dictionary = {}
var _role_weight := PackedFloat32Array()


func _init(
	schedule: WaveSchedule, difficulty_model: DifficultyModel, number: int, merged: WaveModifier
) -> void:
	_schedule = schedule
	model = difficulty_model
	wave = number
	modifier = merged
	_types = WaveComposer.available(schedule, number)
	_shares = role_shares(schedule, number, _types)
	_role_weight.resize(WaveComposer.ROLE_COUNT)
	for rule in schedule.rules:
		if rule != null and rule.applies(number):
			_rules.append(rule)
	_boss = schedule.boss_for(number)
	if _boss != null:
		sheet.add(model.stats_for(_boss))


func difficulty() -> float:
	return model.difficulty(sheet, modifier)


func gap(target: float) -> float:
	return absf(difficulty() - target)


func count_of(type: EnemyData) -> int:
	return _counts.get(type, 0)


## The minimums first, then random picks until the target is reached (never past
## target + tolerance).
func fill(target: float, rng: RandomNumberGenerator) -> void:
	for rule in _rules:
		for type in rule.required(self, _types):
			_add_group(type, INF, 1)
	var ceiling: float = target + WaveComposer.tolerance_for(_schedule)
	while sheet.enemies < _schedule.max_enemies and difficulty() < target:
		var options: Array[EnemyData] = _options(ceiling)
		if options.is_empty():
			return
		var pick: EnemyData = _weighted_pick(options, rng)
		_add_group(pick, ceiling, pick.group_size)


## The difficulty with `type` added (nothing changes).
func difficulty_with(type: EnemyData) -> float:
	sheet.add(model.stats_for(type))
	var found: float = difficulty()
	sheet.add(model.stats_for(type), -1)
	return found


## Each axis's share of the wave's squared length (DifficultyModel.shares) with `type` added.
func shares_with(type: EnemyData) -> PackedFloat32Array:
	sheet.add(model.stats_for(type))
	var found: PackedFloat32Array = model.shares(model.scores(sheet, modifier))
	sheet.add(model.stats_for(type), -1)
	return found


## The enemies picked, shuffled with groups kept together, the boss first.
func enemies(rng: RandomNumberGenerator) -> Array[EnemyData]:
	var picks: Array[Array] = _picks.duplicate()
	for i in range(picks.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Array = picks[i]
		picks[i] = picks[j]
		picks[j] = held
	var flat: Array[EnemyData] = []
	if _boss != null:
		flat.append(_boss)
	for group in picks:
		flat.append_array(group)
	return flat


func _options(ceiling: float) -> Array[EnemyData]:
	return _types.filter(
		func(type: EnemyData) -> bool: return _allowed(type) and difficulty_with(type) <= ceiling
	)


func _allowed(type: EnemyData) -> bool:
	for rule in _rules:
		if not rule.allows(self, type):
			return false
	return true


## Adds up to `size` of `type` together, stopping early when one more would break a rule or
## pass `ceiling` (the first always goes in).
func _add_group(type: EnemyData, ceiling: float, size: int) -> void:
	var group: Array[EnemyData] = []
	for i in size:
		if i > 0 and (not _allowed(type) or difficulty_with(type) > ceiling):
			break
		sheet.add(model.stats_for(type))
		_counts[type] = count_of(type) + 1
		_role_weight[type.role] += model.solo(type)
		group.append(type)
	_picks.append(group)


## spawn_weight, pulled toward roles below their share (by solo difficulty), times the rules' pulls.
func _weight(type: EnemyData) -> float:
	var total: float = 0.0
	for weight in _role_weight:
		total += weight
	var have: float = _role_weight[type.role] / total if total > 0.0 else 0.0
	var pull: float = maxf(_shares[type.role] - have, 0.0) + WaveComposer.MIN_PULL
	for rule in _rules:
		pull *= rule.pull(self, type)
	return type.spawn_weight * pull


func _weighted_pick(types: Array[EnemyData], rng: RandomNumberGenerator) -> EnemyData:
	var weights := PackedFloat32Array()
	var total: float = 0.0
	for type in types:
		weights.append(_weight(type))
		total += weights[-1]
	var roll: float = rng.randf() * total
	for i in types.size():
		roll -= weights[i]
		if roll <= 0.0:
			return types[i]
	return types.back()


## Each role's share of the wave, counting only roles with a type available (they add up to 1).
static func role_shares(
	schedule: WaveSchedule, number: int, types: Array[EnemyData]
) -> PackedFloat32Array:
	var shares := PackedFloat32Array()
	shares.resize(WaveComposer.ROLE_COUNT)
	var sum: float = 0.0
	for type in types:
		if shares[type.role] == 0.0:
			shares[type.role] = maxf(schedule.share(type.role, number), 0.0)
			sum += shares[type.role]
	for role in WaveComposer.ROLE_COUNT:
		shares[role] = shares[role] / sum if sum > 0.0 else 1.0 / WaveComposer.ROLE_COUNT
	return shares
