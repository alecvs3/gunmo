class_name PredictionHistory
extends RefCounted
## The owner's input commands the host has not confirmed yet, oldest first.
## Confirmed ones are dropped; the rest are replayed after every correction.

## About two seconds at 60 Hz; older unconfirmed commands are given up on.
var capacity: int = 120

var _commands: Array[InputCommand] = []


func record(command: InputCommand) -> void:
	_commands.append(command)
	while _commands.size() > capacity:
		_commands.pop_front()


## The host has simulated everything up to and including `sequence`.
func acknowledge(sequence: int) -> void:
	while not _commands.is_empty() and _commands[0].sequence <= sequence:
		_commands.pop_front()


func pending() -> Array[InputCommand]:
	return _commands


## The newest `count` commands, oldest first (what each packet sends).
func recent(count: int) -> Array[InputCommand]:
	return _commands.slice(maxi(_commands.size() - count, 0))


func size() -> int:
	return _commands.size()
