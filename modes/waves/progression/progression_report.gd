class_name ProgressionReport
extends RefCounted
## Difficulty, progression and strain side by side, for tools/balance_graphs.ps1: a markdown
## table for one team (paste it in balance PRs) and a dictionary of every team for the graph
## page. Everything here is in display units (×10: both scores on 0–100).

const SHOWN: float = ProgressionModel.DISPLAY_SCALE


## Every team the graphs show: each archetype at sizes 1 to `max_size` (pets from the model),
## then the model's reference team and `extra` named teams.
static func teams(
	archetypes: Array[PlayerArchetype],
	max_size: int,
	model: ProgressionModel,
	extra: Array[TeamSetup] = []
) -> Array[TeamSetup]:
	var found: Array[TeamSetup] = []
	for archetype in archetypes:
		for size in range(1, max_size + 1):
			found.append(TeamSetup.uniform(archetype, size, model.team_pets))
	if model.reference_team != null:
		found.append(model.reference_team)
	found.append_array(extra)
	return found


## One team's run as a markdown table.
static func format(
	team: TeamSetup, rows: Array[ProgressionRun.Row], difficulty: DifficultyModel
) -> String:
	var header := PackedStringArray(["Wave", "Difficulty", "Progression", "Strain", "Target"])
	for axis in difficulty.axes:
		header.append(axis.short_name)
	header.append_array(
		["Bounty", "Clear", "Interest", "Early", "Held", "Spent", "Loadout (first)"]
	)
	var lines := PackedStringArray(["Team: %s" % team.display_name, WaveReport.table_line(header)])
	lines.append(WaveReport.table_line(WaveReport.table_rule(header.size())))
	for row in rows:
		var cells := PackedStringArray(["%d" % row.wave])
		for value in [
			row.difficulty * SHOWN, row.progression * SHOWN, row.strain, row.target_strain
		]:
			cells.append("%.1f" % value)
		for score in row.axis_scores:
			cells.append("%.0f" % (score * SHOWN))
		for source in SimPlayer.SOURCES:
			cells.append("%.0f" % row.income.get(source, 0.0))
		cells.append_array(["%.0f" % row.held, "%.0f" % row.spent, row.loadouts[0]])
		lines.append(WaveReport.table_line(cells))
	return "\n".join(lines)


## The waves' side of the graphs.
static func waves_data(waves: Array[WaveReport.Row], difficulty: DifficultyModel) -> Dictionary:
	var axes: Array = []
	for axis in difficulty.axes:
		axes.append({"name": axis.display_name, "short": axis.short_name})
	var rows: Array = []
	for each in waves:
		(
			rows
			. append(
				{
					"wave": each.wave,
					"target": each.target * SHOWN,
					"difficulty": each.difficulty * SHOWN,
					"axes": _shown(each.axis_scores),
					"bounty": each.bounty,
					"modifiers": each.modifiers,
				}
			)
		)
	return {"axes": axes, "waves": rows}


## One team's side of the graphs.
static func team_data(
	team: TeamSetup, rows: Array[ProgressionRun.Row], model: ProgressionModel, total: int
) -> Dictionary:
	var data: Array = []
	for row in rows:
		var miss: float = model.strain.miss(row.strain, row.wave, total) if model.strain else 0.0
		(
			data
			. append(
				{
					"progression": row.progression * SHOWN,
					"axes": _shown(row.axis_scores),
					"strain": row.strain,
					"miss": miss,
					"income": row.income,
					"held": row.held,
					"spent": row.spent,
					"loadouts": Array(row.loadouts),
				}
			)
		)
	var group: String = "Mixed"
	if not team.members.is_empty() and team.members.count(team.members[0]) == team.members.size():
		group = team.members[0].display_name
	return {"name": team.display_name, "size": team.members.size(), "group": group, "rows": data}


static func _shown(scores: PackedFloat32Array) -> Array:
	var found: Array = []
	for score in scores:
		found.append(snappedf(score * SHOWN, 0.1))
	return found
