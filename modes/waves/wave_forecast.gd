class_name WaveForecast
extends RefCounted
## What the next wave will be, shown during the break before it. A wave depends only on the
## match seed and its number (WaveComposer.plan_wave), so the host builds it ahead and the
## forecast is exact: the wave that spawns is the one forecast. Pure.

## Axis scores travel as a byte each (score × SCORE_STEPS, at most 25.5).
const SCORE_STEPS: float = 10.0
## Shares at or above this get two arrows in the HUD ("Toughness ▲▲").
const STRONG_SHARE: float = 0.35

var wave: int = 0
var modifier_mask: int = 0
## One score per DifficultyModel axis, in the model's order.
var scores := PackedFloat32Array()
var boss: bool = false


static func of(
	schedule: WaveSchedule,
	model: DifficultyModel,
	catalog: ModifierCatalog,
	match_seed: int,
	wave: int
) -> WaveForecast:
	var forecast := WaveForecast.new()
	forecast.wave = wave
	forecast.modifier_mask = catalog.pick_for_wave(schedule, match_seed, wave)
	var enemies: Array[EnemyData] = WaveComposer.plan_wave(
		schedule, model, catalog, match_seed, wave
	)
	var merged: WaveModifier = catalog.combined(forecast.modifier_mask)
	forecast.scores = model.scores(model.sheet_for(enemies), merged)
	forecast.boss = schedule.boss_for(wave) != null
	return forecast


## A score as it travels (0..255).
static func to_byte(score: float) -> int:
	return clampi(roundi(score * SCORE_STEPS), 0, 255)


static func from_byte(value: int) -> float:
	return value / SCORE_STEPS


## Indices of the `count` axes with the biggest share of the wave (biggest first), leaving out
## axes the wave has none of.
static func top_axes(
	model: DifficultyModel, axis_scores: PackedFloat32Array, count: int = 2
) -> Array[int]:
	var shares: PackedFloat32Array = model.shares(axis_scores)
	var order: Array[int] = []
	for i in shares.size():
		if shares[i] > 0.0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return shares[a] > shares[b])
	return order.slice(0, count)
