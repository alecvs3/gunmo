extends SceneTree
## Runs the progression paper run (ProgressionRun) for every team against the wave report's
## waves, prints one team's table, and writes the graph page's data (tools/balance/data.js).
## Run it through tools/balance_graphs.ps1, or:
##   godot --headless --path . -s tools/balance_graphs.gd -- [--seed N] [--team res://...]
##   [--out path]

const MATCH: String = "res://modes/data/default_match.tres"
const ARCHETYPES: Array[String] = [
	"res://modes/waves/data/progression/novice.tres",
	"res://modes/waves/data/progression/average.tres",
	"res://modes/waves/data/progression/expert.tres",
]
const EXTRA_TEAMS: Array[String] = ["res://modes/waves/data/progression/mixed_squad.tres"]
## Generated teams go from 1 player up to this many.
const MAX_TEAM: int = 4


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_text: String = _value(args, "--seed", "1")
	var settings := load(MATCH) as MatchSettings
	var model: ProgressionModel = ProgressionModel.load_default()
	var team_path: String = _value(args, "--team", "")
	var shown := load(team_path) as TeamSetup if not team_path.is_empty() else model.reference_team
	if settings == null or shown == null or not seed_text.is_valid_int():
		printerr("balance graphs: need a whole-number --seed and a TeamSetup (--team)")
		quit(1)
		return
	var data: Dictionary = _build(settings, model, shown, seed_text.to_int())
	var out: String = _value(args, "--out", "")
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string("window.BALANCE = %s;\n" % JSON.stringify(data))
		file.close()
	quit(0)


func _build(
	settings: MatchSettings, model: ProgressionModel, shown: TeamSetup, match_seed: int
) -> Dictionary:
	var schedule: WaveSchedule = settings.wave_schedule
	var difficulty: DifficultyModel = DifficultyModel.load_default()
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	## Team size -> its waves (they grow with the team: DifficultyCurve.player_scale).
	var by_size: Dictionary = {}
	var data: Dictionary = {"seed": match_seed, "waves_by_size": {}, "strain_target": []}
	for size in range(1, MAX_TEAM + 1):
		by_size[size] = WaveReport.build(schedule, catalog, difficulty, match_seed, size)
		data["waves_by_size"][str(size)] = ProgressionReport.waves_data(by_size[size], difficulty)
	data["axes"] = data["waves_by_size"]["1"]["axes"]
	for wave in range(1, schedule.total_waves + 1):
		data["strain_target"].append(model.strain.target(wave, schedule.total_waves))
	data["strain_band"] = model.strain.band
	data["reference"] = model.reference_team.display_name
	var teams: Array = []
	for team in ProgressionReport.teams(_archetypes(), MAX_TEAM, model, _extra()):
		var size: int = team.members.size()
		if not by_size.has(size):
			by_size[size] = WaveReport.build(schedule, catalog, difficulty, match_seed, size)
		var waves: Array[WaveReport.Row] = by_size[size]
		var rows := ProgressionRun.run(team, waves, schedule, settings, difficulty, model)
		teams.append(ProgressionReport.team_data(team, rows, model, schedule.total_waves))
		if team == shown:
			print("Balance report: seed %d, %d players" % [match_seed, size])
			print(ProgressionReport.format(team, rows, difficulty))
	data["teams"] = teams
	return data


func _archetypes() -> Array[PlayerArchetype]:
	var found: Array[PlayerArchetype] = []
	for path in ARCHETYPES:
		found.append(load(path) as PlayerArchetype)
	return found


func _extra() -> Array[TeamSetup]:
	var found: Array[TeamSetup] = []
	for path in EXTRA_TEAMS:
		found.append(load(path) as TeamSetup)
	return found


## The value after `flag` in the arguments, or `fallback`.
func _value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var at: int = args.find(flag)
	if at < 0 or at + 1 >= args.size():
		return fallback
	return args[at + 1]
