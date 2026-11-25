extends SceneTree
## Prints the wave report (WaveReport) for a schedule and match seed, then quits.
## Run it through tools/wave_report.ps1, or:
##   godot --headless --path . -s tools/wave_report.gd -- [--schedule res://...] [--seed N]
##   [--players N]

const DEFAULT_SCHEDULE: String = "res://modes/waves/data/default_waves.tres"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = _value(args, "--schedule", DEFAULT_SCHEDULE)
	var seed_text: String = _value(args, "--seed", "1")
	var players_text: String = _value(args, "--players", "2")
	var schedule := load(path) as WaveSchedule if ResourceLoader.exists(path) else null
	if schedule == null or not seed_text.is_valid_int() or not players_text.is_valid_int():
		printerr("wave report: need a WaveSchedule (--schedule), whole-number --seed and --players")
		quit(1)
		return
	var model: DifficultyModel = DifficultyModel.load_default()
	var rows: Array[WaveReport.Row] = WaveReport.build(
		schedule, ModifierCatalog.load_default(), model, seed_text.to_int(), players_text.to_int()
	)
	var about: Array = [path, seed_text, players_text, schedule.max_alive]
	print("Wave report: %s, seed %s, %s players, max_alive %d" % about)
	print(WaveReport.format(schedule, model, rows))
	quit(0)


## The value after `flag` in the arguments, or `fallback`.
func _value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var at: int = args.find(flag)
	if at < 0 or at + 1 >= args.size():
		return fallback
	return args[at + 1]
