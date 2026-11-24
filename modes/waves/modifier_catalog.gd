class_name ModifierCatalog
extends Resource
## Every wave modifier, in a fixed order. Active modifiers travel as a bitmask (bit i = the
## modifier at index i) in the MatchState and each enemy's spawn data, so every peer uses the
## same catalog: the default one at DEFAULT_PATH.

const DEFAULT_PATH: String = "res://modes/waves/data/modifier_catalog.tres"
## The mask is one byte.
const MAX_MODIFIERS: int = 8

@export var modifiers: Array[WaveModifier] = []

@export_group("Caps")
## However many modifiers stack, the merged numbers stay within these.
@export_range(1.0, 10.0) var max_health_multiplier: float = 2.5
@export_range(1.0, 10.0) var max_speed_multiplier: float = 1.8
@export_range(0.05, 1.0) var min_damage_taken_multiplier: float = 0.4
@export_range(0.0, 1.0) var max_regen_per_second: float = 0.08

@export_group("Threat")
## How much tougher a wave's modifiers make each enemy (see threat()): speed and regeneration
## count this much per unit.
@export_range(0.0, 5.0) var speed_threat: float = 0.8
@export_range(0.0, 50.0) var regen_threat: float = 6.0


static func load_default() -> ModifierCatalog:
	return load(DEFAULT_PATH)


## How many modifiers a wave gets: none before first_wave, one until double_wave, two until
## triple_wave, then three.
static func count_for_wave(
	wave: int, first_wave: int, double_wave: int, triple_wave: int = 256
) -> int:
	if wave < first_wave:
		return 0
	if wave < double_wave:
		return 1
	return 2 if wave < triple_wave else 3


## A wave's modifiers in a match: how many the schedule gives this wave, picked from their own
## seed so they don't change which enemies spawn.
func pick_for_wave(schedule: WaveSchedule, match_seed: int, wave: int) -> int:
	var count: int = count_for_wave(
		wave,
		schedule.first_modifier_wave,
		schedule.double_modifier_wave,
		schedule.triple_modifier_wave
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([match_seed, wave, "modifiers"])
	return pick(count, rng)


func usable_count() -> int:
	return mini(modifiers.size(), MAX_MODIFIERS)


## A mask of `count` different modifiers that don't conflict, picked with `rng` (a seed gives
## the same pick). Fewer when the conflicts leave nothing else to add.
func pick(count: int, rng: RandomNumberGenerator) -> int:
	var indices: Array[int] = []
	for i in usable_count():
		indices.append(i)
	var mask: int = 0
	for n in count:
		var allowed: Array[int] = indices.filter(func(i: int) -> bool: return _fits(i, mask))
		if allowed.is_empty():
			break
		var chosen: int = allowed[rng.randi_range(0, allowed.size() - 1)]
		indices.erase(chosen)
		mask |= 1 << chosen
	return mask


## Whether the modifier at `index` conflicts with none already in `mask`.
func _fits(index: int, mask: int) -> bool:
	for i in usable_count():
		if mask & (1 << i) != 0 and modifiers[i].conflicts(modifiers[index]):
			return false
	return true


## All modifiers in `mask` merged into one: multipliers multiply, regeneration adds up (the
## order never matters), then the caps apply; the color is their average.
func combined(mask: int) -> WaveModifier:
	var result := WaveModifier.new()
	var colors: Array[Color] = []
	for i in usable_count():
		if mask & (1 << i) == 0:
			continue
		var modifier: WaveModifier = modifiers[i]
		result.health_multiplier *= modifier.health_multiplier
		result.speed_multiplier *= modifier.speed_multiplier
		result.damage_taken_multiplier *= modifier.damage_taken_multiplier
		result.regen_per_second += modifier.regen_per_second
		colors.append(modifier.color)
	result.health_multiplier = minf(result.health_multiplier, max_health_multiplier)
	result.speed_multiplier = minf(result.speed_multiplier, max_speed_multiplier)
	result.damage_taken_multiplier = maxf(
		result.damage_taken_multiplier, min_damage_taken_multiplier
	)
	result.regen_per_second = minf(result.regen_per_second, max_regen_per_second)
	if not colors.is_empty():
		var sum := Color(0, 0, 0, 0)
		for color in colors:
			sum += color
		result.color = sum / colors.size()
	return result


## How much tougher the modifiers in `mask` make each enemy (1 = not at all): health over
## damage taken, times (1 + speed_threat * extra speed) * (1 + regen_threat * regeneration).
## A wave buys budget / threat, so modifiers change a wave's shape more than its difficulty.
func threat(mask: int) -> float:
	var merged: WaveModifier = combined(mask)
	var toughness: float = merged.health_multiplier / merged.damage_taken_multiplier
	var speed: float = 1.0 + speed_threat * (merged.speed_multiplier - 1.0)
	return maxf(toughness * speed * (1.0 + regen_threat * merged.regen_per_second), 0.1)


## "Armored · Fast" for the HUD ("" when none).
func names(mask: int) -> String:
	var found := PackedStringArray()
	for i in usable_count():
		if mask & (1 << i) != 0:
			found.append(modifiers[i].display_name)
	return " · ".join(found)
