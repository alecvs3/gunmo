class_name WaveReport
extends RefCounted
## The difficulty curve on paper: for every wave of a schedule, what the host spawns with a
## given match seed. Uses the same functions as WaveMode and WaveSpawner (wave seed, budget
## plan, modifier pick, scaled health), so the numbers are the game's. Printed by
## tools/wave_report.ps1; later balance PRs paste it before and after.


## One wave's numbers.
class Row:
	var wave: int = 0
	var budget: float = 0.0
	var enemies: int = 0
	## Enemy display name -> how many of that type this wave buys.
	var counts: Dictionary = {}
	## Sum of the enemies' max health after the wave's modifiers, splits included (a Splitter's
	## children are health the players must also chew through).
	var total_health: int = 0
	## Each enemy's health divided by its damage-taken multipliers (its own armor and the
	## wave's): the damage it takes to kill them all (regeneration doesn't count).
	var effective_health: int = 0
	var modifier_mask: int = 0
	var modifiers: String = ""
	## Most enemies alive at once if nobody kills anything: the schedule's cap, not a prediction.
	var peak_alive: int = 0
	## Seconds from the first spawn to the last when max_alive never holds one back.
	var spawn_seconds: float = 0.0


static func build(schedule: WaveSchedule, catalog: ModifierCatalog, match_seed: int) -> Array[Row]:
	var rows: Array[Row] = []
	for wave in range(1, schedule.total_waves + 1):
		rows.append(row(schedule, catalog, match_seed, wave))
	return rows


static func row(
	schedule: WaveSchedule, catalog: ModifierCatalog, match_seed: int, wave: int
) -> Row:
	var result := Row.new()
	result.wave = wave
	result.budget = WaveBudget.budget(schedule, wave)
	var rng := RandomNumberGenerator.new()
	rng.seed = WaveBudget.wave_seed(match_seed, wave)
	var planned: Array[EnemyData] = WaveBudget.plan(schedule, wave, rng)
	result.modifier_mask = catalog.pick_for_wave(schedule, match_seed, wave)
	result.modifiers = catalog.names(result.modifier_mask)
	var combined: WaveModifier = catalog.combined(result.modifier_mask)
	var effective: float = 0.0
	for type in planned:
		result.counts[type.display_name] = result.counts.get(type.display_name, 0) + 1
		for each in with_splits(type):
			var health: int = combined.scaled_health(each.max_health)
			result.total_health += health
			effective += health / (combined.damage_taken_multiplier * each.damage_taken)
	result.effective_health = roundi(effective)
	result.enemies = planned.size()
	result.peak_alive = mini(planned.size(), schedule.max_alive)
	result.spawn_seconds = maxi(planned.size() - 1, 0) * schedule.spawn_interval(wave)
	return result


## `type` and every enemy it splits into when it dies (and they into theirs, a few levels deep).
static func with_splits(type: EnemyData, depth: int = 0) -> Array[EnemyData]:
	var found: Array[EnemyData] = [type]
	if depth < 3 and type.split_into != null:
		for i in type.split_count:
			found.append_array(with_splits(type.split_into, depth + 1))
	return found


## The rows as a markdown table, one column per enemy type of the schedule.
static func format(schedule: WaveSchedule, rows: Array[Row]) -> String:
	var names := PackedStringArray()
	for type in schedule.enemy_types:
		if type != null and not names.has(type.display_name):
			names.append(type.display_name)
	var header := PackedStringArray(["Wave", "Budget", "Enemies"])
	header.append_array(names)
	header.append_array(["Health", "Effective", "Peak alive", "Spawn s", "Modifiers"])
	var lines := PackedStringArray([_line(header), _line(_rule(header.size()))])
	for each in rows:
		lines.append(_line(_cells(each, names)))
	return "\n".join(lines)


static func _cells(each: Row, names: PackedStringArray) -> PackedStringArray:
	var cells := PackedStringArray(["%d" % each.wave, "%.1f" % each.budget, "%d" % each.enemies])
	for name in names:
		cells.append("%d" % each.counts.get(name, 0))
	(
		cells
		. append_array(
			[
				"%d" % each.total_health,
				"%d" % each.effective_health,
				"%d" % each.peak_alive,
				"%.1f" % each.spawn_seconds,
				each.modifiers if not each.modifiers.is_empty() else "-",
			]
		)
	)
	return cells


static func _rule(count: int) -> PackedStringArray:
	var cells := PackedStringArray()
	for i in count:
		cells.append("---")
	return cells


static func _line(cells: PackedStringArray) -> String:
	return "| " + " | ".join(cells) + " |"
