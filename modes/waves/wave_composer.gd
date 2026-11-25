class_name WaveComposer
extends RefCounted
## Builds a wave to hit the difficulty its schedule aims for (DifficultyCurve, scored by
## DifficultyModel). Pure, with a caller-supplied random generator: a seed gives the same wave.
## The boss comes first, then every minimum the schedule's rules ask for, then random types
## (weighted by spawn_weight and pulled toward the schedule's role shares) are added while the
## wave stays within tolerance of its target, until it reaches it. A group type is added as a
## group. A few tries keep the closest wave (just one when a try hits max_enemies). The picks
## are shuffled, groups kept together, so the roles arrive mixed.

const MAX_TRIES: int = 4
const ROLE_COUNT: int = 4
## Every type keeps this much of its weight even when its role has more than its share.
const MIN_PULL: float = 0.05


## The seed for a wave's enemies: the match seed and the wave number, so a match replays exactly.
static func wave_seed(match_seed: int, wave: int) -> int:
	return hash([match_seed, wave])


## Enemy types allowed in this wave (first_wave reached, a chance to be picked).
static func available(schedule: WaveSchedule, wave: int) -> Array[EnemyData]:
	var types: Array[EnemyData] = []
	for type in schedule.enemy_types:
		if type != null and type.first_wave <= wave and type.spawn_weight > 0.0:
			types.append(type)
	return types


## The wave's enemies, the boss first. `modifier` is all the wave's modifiers merged
## (ModifierCatalog.combined): a tougher wave needs fewer enemies to reach its target.
## `players`: how many players it is for (DifficultyCurve.player_scale; 0 = unscaled).
static func plan(
	schedule: WaveSchedule,
	model: DifficultyModel,
	wave: int,
	rng: RandomNumberGenerator,
	modifier: WaveModifier,
	players: int = 0
) -> Array[EnemyData]:
	var target: float = target_for(schedule, wave, players)
	var best: WaveDraft = null
	for attempt in MAX_TRIES:
		var draft := WaveDraft.new(schedule, model, wave, modifier)
		draft.fill(target, rng)
		if best == null or draft.gap(target) < best.gap(target):
			best = draft
		if (
			best.gap(target) <= tolerance_for(schedule)
			or draft.sheet.enemies >= schedule.max_enemies
		):
			break
	return best.enemies(rng)


## Wave `wave` of the match with `match_seed`, as the host will spawn it: its modifiers from
## their own seed (ModifierCatalog.pick_for_wave), merged, then the enemies from the wave seed.
## WaveReport and WaveForecast use it, so they always show the wave that really comes.
static func plan_wave(
	schedule: WaveSchedule,
	model: DifficultyModel,
	catalog: ModifierCatalog,
	match_seed: int,
	wave: int,
	players: int = 0
) -> Array[EnemyData]:
	var merged: WaveModifier = catalog.combined(catalog.pick_for_wave(schedule, match_seed, wave))
	var rng := RandomNumberGenerator.new()
	rng.seed = wave_seed(match_seed, wave)
	return plan(schedule, model, wave, rng, merged, players)


static func target_for(schedule: WaveSchedule, wave: int, players: int = 0) -> float:
	if schedule.difficulty == null:
		return 0.0
	return schedule.difficulty.target(wave, schedule, players)


static func tolerance_for(schedule: WaveSchedule) -> float:
	return schedule.difficulty.tolerance if schedule.difficulty != null else 0.0
