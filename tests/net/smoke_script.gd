extends SceneTree
## Base of every headless multiplayer scenario in tests/net (run_smoke.ps1 starts them).
## A scenario extends this file by path, calls _boot() from _initialize() and overrides _run().
## It prints "SMOKE PASS <role>" or "SMOKE FAIL <role>: ..." and exits (0 = pass).
## These scripts run before the autoloads exist, so they never name project classes directly
## (that would compile them too early); _begin() loads what they need once the game runs.

const LEVEL_PATH: String = "Main/LevelContainer/TestArena"

## From the command line: -- <role> <port> [more]
var _role: String = ""
var _port: int = 0
var _args := PackedStringArray()
var _failures := PackedStringArray()
var _finished: bool = false
## Printed in front of _metric lines ("LATENCY", "STRESS").
var _metric_label: String = "SMOKE"
var _input_command_script: GDScript
var _fire_button: int = 0
## GameMode.Phase, by name.
var _phase: Dictionary = {}
## Measurements by name (_add, _average, _percentile).
var _samples: Dictionary = {}


## Reads the role and port, starts the game and a watchdog, then runs the scenario.
func _boot(default_role: String, default_port: int, watchdog_seconds: float) -> void:
	_args = OS.get_cmdline_user_args()
	_role = _args[0] if _args.size() > 0 else default_role
	_port = _args[1].to_int() if _args.size() > 1 else default_port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(watchdog_seconds).timeout.connect(_finish.bind("watchdog timeout"))
	_begin.call_deferred()


## The scenario itself. Call _finish() at the end.
func _run() -> void:
	pass


## Called once just before the result is printed (extra SMOKE INFO lines).
func _before_finish() -> void:
	pass


func _begin() -> void:
	_input_command_script = load("res://shared/network/input_command.gd")
	_fire_button = _input_command_script.get_script_constant_map()["FIRE"]
	_phase = load("res://modes/game_mode.gd").get_script_constant_map()["Phase"]
	_run()


func _own_player() -> Node2D:
	var path: String = "%s/Players/%d" % [LEVEL_PATH, root.multiplayer.get_unique_id()]
	return root.get_node_or_null(path) as Node2D


## Drives `player` with a fixed aim, buttons and movement (PlayerInputSource.scripted) until
## changed.
func _script(player: Node2D, aim: float, buttons: int, move := Vector2.ZERO) -> void:
	if player == null:
		return
	var command: RefCounted = _input_command_script.new()
	command.move = move
	command.aim = aim
	command.buttons = buttons
	player.get_node("PlayerInputSource").scripted = command


func _wait_until(condition: Callable, timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not condition.call():
		await create_timer(0.1).timeout
		time_left -= 0.1


## Packed arrays are copied when read from a Dictionary, so the array is stored back.
func _add(name: String, value: float) -> void:
	var values: PackedFloat64Array = _samples.get(name, PackedFloat64Array())
	values.append(value)
	_samples[name] = values


func _average(name: String) -> float:
	var values: PackedFloat64Array = _samples.get(name, PackedFloat64Array())
	var total: float = 0.0
	for value in values:
		total += value
	return total / values.size() if values.size() > 0 else 0.0


func _percentile(name: String, fraction: float) -> float:
	var values: PackedFloat64Array = (_samples.get(name, PackedFloat64Array())).duplicate()
	if values.is_empty():
		return 0.0
	values.sort()
	return values[mini(floori(fraction * values.size()), values.size() - 1)]


func _metric(name: String, value: float) -> void:
	print("%s METRIC %s %.2f" % [_metric_label, name, value])


func _info(text: String) -> void:
	print("SMOKE INFO %s: %s" % [_role, text])


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _finish(extra_failure: String) -> void:
	if _finished:
		return
	_finished = true
	_before_finish()
	if not extra_failure.is_empty():
		_failures.append(extra_failure)
	if _failures.is_empty():
		print("SMOKE PASS %s" % _role)
	else:
		print("SMOKE FAIL %s: %s" % [_role, "; ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)
