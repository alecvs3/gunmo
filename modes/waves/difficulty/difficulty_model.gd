class_name DifficultyModel
extends Resource
## How hard a wave is, on a 0–10 scale, from its enemies' own numbers (never the players').
## Each axis scores 10 × (raw / reference) ^ exponent; the difficulty is the weighted length
## of that vector: √(Σ weight × score² / Σ weight). Every axis at its reference = 10, an
## empty wave = 0. Real values live in modes/waves/data/difficulty_model.tres.

const DEFAULT_PATH: String = "res://modes/waves/data/difficulty_model.tres"

@export var axes: Array[DifficultyAxis] = []
## Below 1, doubling an axis counts less than double (0.7: ×1.62).
@export_range(0.1, 2.0) var exponent: float = 0.7
## What a wave with every axis at its reference scores.
@export_range(1.0, 100.0) var scale: float = 10.0
## Shots of a fan or ring count as landing within this cone (degrees) around the aim.
@export_range(1.0, 360.0) var aim_cone_degrees: float = 30.0

var _stats: Dictionary = {}
var _solo: Dictionary = {}


static func load_default() -> DifficultyModel:
	return load(DEFAULT_PATH)


## One type's stats, worked out once.
func stats_for(data: EnemyData) -> EnemyStats:
	if not _stats.has(data):
		_stats[data] = EnemyStats.of(data, aim_cone_degrees)
	return _stats[data]


## The difficulty of a wave of just one `data`, without modifiers: how much it adds on its own
## (role balance in WaveComposer, target danger for bots).
func solo(data: EnemyData) -> float:
	if not _solo.has(data):
		var sheet := WaveSheet.new()
		sheet.add(stats_for(data))
		_solo[data] = difficulty(sheet, WaveModifier.new())
	return _solo[data]


func sheet_for(enemies: Array[EnemyData]) -> WaveSheet:
	var sheet := WaveSheet.new()
	for data in enemies:
		sheet.add(stats_for(data))
	return sheet


## Each axis's score (0 = none, 10 = at its reference; it can go higher).
func scores(sheet: WaveSheet, modifier: WaveModifier) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for axis in axes:
		var amount: float = maxf(axis.raw(sheet, modifier), 0.0)
		found.append(scale * pow(amount / axis.reference, exponent))
	return found


## The wave's difficulty: the weighted length of its scores.
func difficulty(sheet: WaveSheet, modifier: WaveModifier) -> float:
	return length(scores(sheet, modifier))


## Each axis's part of the squared length (they add up to 1; all 0 for an empty wave).
func shares(axis_scores: PackedFloat32Array) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	var sum: float = 0.0
	for i in mini(axes.size(), axis_scores.size()):
		found.append(axes[i].weight * axis_scores[i] * axis_scores[i])
		sum += found[i]
	for i in found.size():
		found[i] = found[i] / sum if sum > 0.0 else 0.0
	return found


func length(axis_scores: PackedFloat32Array) -> float:
	var weighted: float = 0.0
	var weights: float = 0.0
	for i in mini(axes.size(), axis_scores.size()):
		weighted += axes[i].weight * axis_scores[i] * axis_scores[i]
		weights += axes[i].weight
	return sqrt(weighted / weights) if weights > 0.0 else 0.0
