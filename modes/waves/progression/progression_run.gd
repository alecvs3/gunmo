class_name ProgressionRun
extends RefCounted
## A Waves run on paper for one team: before each wave, how strong the team is (progression,
## on the difficulty's own axes and scale), then what it earns for the wave (EconomyModel) and
## what it buys in the break (Buyer). Uses the wave report's rows, so the waves are the ones
## the host spawns for that match seed. Shown by tools/balance_graphs.ps1.


## One wave of the run. Scores are on the model's 0–10 scale; strain is in display units.
class Row:
	var wave: int = 0
	## The team's score on each difficulty axis, and their weighted length.
	var axis_scores := PackedFloat32Array()
	var progression: float = 0.0
	## The wave's difficulty (from the wave report).
	var difficulty: float = 0.0
	## How far the wave is above the team, in display units: on each axis the wave's score
	## minus the team's, weighted by that axis's share of the wave (DifficultyModel.shares), so
	## an axis the wave doesn't push on doesn't count. And what the StrainCurve wants.
	var strain: float = 0.0
	var target_strain: float = 0.0
	## Source -> credits one player earned this wave, on average over the team.
	var income: Dictionary = {}
	## Per player, on average: credits spent so far and held after the break.
	var spent: float = 0.0
	var held: float = 0.0
	## What each player carries into this wave ("Rifle 3/2/0/1/0/1/0, Soldier 2, Path 1").
	var loadouts := PackedStringArray()


static func run(
	team: TeamSetup,
	waves: Array[WaveReport.Row],
	schedule: WaveSchedule,
	settings: MatchSettings,
	difficulty: DifficultyModel,
	model: ProgressionModel
) -> Array[Row]:
	var players: Array[SimPlayer] = []
	for i in team.members.size():
		var player := SimPlayer.make(team.members[i], team.pet_for(i))
		player.credits = settings.starting_credits
		players.append(player)
	var rows: Array[Row] = []
	for i in waves.size():
		var next: WaveReport.Row = waves[i + 1] if i + 1 < waves.size() else null
		rows.append(_wave(players, team, waves[i], next, schedule, settings, difficulty, model))
	return rows


static func _wave(
	players: Array[SimPlayer],
	team: TeamSetup,
	wave: WaveReport.Row,
	next: WaveReport.Row,
	schedule: WaveSchedule,
	settings: MatchSettings,
	difficulty: DifficultyModel,
	model: ProgressionModel
) -> Row:
	var row := _measure(players, wave, schedule.total_waves, difficulty, model)
	var before: Dictionary = _earned(players)
	var early: bool = EconomyModel.calls_early(team, wave.wave, schedule.total_waves, settings)
	var power: TeamPower = _team_power(players, wave, model)
	EconomyModel.pay_wave(players, power, wave.bounty, wave.wave, early, settings, model)
	EconomyModel.pay_cores(players, wave.wave, schedule.boss_for(wave.wave) != null, settings)
	if next != null and not early:
		for player in players:
			Buyer.take_break(player, next, difficulty, model, settings)
	_close(row, players, before)
	return row


## The team's scores against `wave`, before it starts.
static func _measure(
	players: Array[SimPlayer],
	wave: WaveReport.Row,
	total: int,
	difficulty: DifficultyModel,
	model: ProgressionModel
) -> Row:
	var row := Row.new()
	row.wave = wave.wave
	row.axis_scores = difficulty.handled_scores(_team_power(players, wave, model), model)
	row.progression = difficulty.length(row.axis_scores)
	row.difficulty = wave.difficulty
	row.strain = strain(wave.axis_scores, row.axis_scores, difficulty)
	if model.strain != null:
		row.target_strain = model.strain.target(wave.wave, total)
	for player in players:
		row.loadouts.append(describe(player))
	return row


## Σ share × (wave − team) over the axes, × DISPLAY_SCALE.
static func strain(
	wave_scores: PackedFloat32Array, team_scores: PackedFloat32Array, difficulty: DifficultyModel
) -> float:
	var shares: PackedFloat32Array = difficulty.shares(wave_scores)
	var total: float = 0.0
	for i in mini(shares.size(), team_scores.size()):
		total += shares[i] * (wave_scores[i] - team_scores[i])
	return total * ProgressionModel.DISPLAY_SCALE


static func _team_power(
	players: Array[SimPlayer], wave: WaveReport.Row, model: ProgressionModel
) -> TeamPower:
	var powers: Array[PlayerPower] = []
	for player in players:
		powers.append(PlayerPower.of(player, wave, model))
	return TeamPower.of(powers)


static func _earned(players: Array[SimPlayer]) -> Dictionary:
	var total: Dictionary = {}
	for source in SimPlayer.SOURCES:
		total[source] = 0.0
		for player in players:
			total[source] += player.earned.get(source, 0.0)
	return total


## This wave's income, and what the players hold and have spent, per player on average.
static func _close(row: Row, players: Array[SimPlayer], before: Dictionary) -> void:
	var after: Dictionary = _earned(players)
	var count: float = maxf(players.size(), 1)
	for source in SimPlayer.SOURCES:
		row.income[source] = (after[source] - before[source]) / count
	for player in players:
		row.spent += player.spent / count
		row.held += player.credits / count


## A short line for what `player` carries: gun, upgrade levels, pet tier, Path nodes.
static func describe(player: SimPlayer) -> String:
	var levels := PackedStringArray()
	for level in player.levels:
		levels.append(str(level))
	var text: String = (
		"%s %s" % [player.catalog.weapon(player.weapon_index).display_name, "/".join(levels)]
	)
	var pet: PetData = player.pets.pet(player.pet_index)
	if pet != null:
		text += ", %s %d" % [pet.display_name, player.pet_tier]
	var nodes: int = 0
	for i in player.path_tree.nodes.size():
		nodes += 1 if player.path.owns(i) else 0
	return text + ", Path %d" % nodes
