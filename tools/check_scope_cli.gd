extends SceneTree
## Prints which smoke scenarios the changed files listed in a text file (one per line) need,
## then quits. .\tools\check.ps1 -Changed runs it and reads the lines:
##   SCOPE all | SCOPE none | SCOPE C,D     the scenarios to run
##   WHY <reason>                           one line per reason
## Usage: godot --headless --path . -s tools/check_scope_cli.gd -- <file list>

## Preloaded rather than named, so it works before an import has cached the class names.
const Scope := preload("res://tools/check_scope.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rules: Dictionary = Scope.load_rules()
	if args.size() != 1 or not FileAccess.file_exists(args[0]) or rules.is_empty():
		printerr("check scope: need a file list, and tools/check_scope.json must be valid JSON")
		quit(1)
		return
	var files := PackedStringArray()
	for line in FileAccess.get_file_as_string(args[0]).split("\n", false):
		if line.strip_edges() != "":
			files.append(line.strip_edges())
	var decision: Scope.Decision = Scope.decide(files, rules)
	var scope: String = "none" if decision.scenarios.is_empty() else ",".join(decision.scenarios)
	print("SCOPE %s" % ("all" if decision.full else scope))
	for reason in decision.reasons:
		print("WHY %s" % reason)
	quit(0)
